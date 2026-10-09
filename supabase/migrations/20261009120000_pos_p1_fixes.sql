-- POS fixes found while writing the test scenarios (docs/pos-luong-va-kich-ban-test.md, B-01, B-02, B-05).
--
--  1. A sale, a cancellation and a return lock their cash shift (FOR SHARE) and check it is
--     still open under that lock. Closing a shift locks it FOR UPDATE, so it waits for sales in
--     flight and they in turn see it closed: no invoice lands in a shift that was already closed
--     and counted.
--  2. A sale may carry a client_ref (a uuid the counter makes once per sale). Sending the same
--     sale again, e.g. after a network error that hid a sale that did go through, returns the
--     invoice made the first time instead of a second invoice taking stock twice.
--  3. Refunds are whole dong. Each return line refunds what the customer paid for the units
--     returned so far, rounded, minus what earlier returns of that line refunded, so partial
--     returns add up to what was paid and never more; a return never refunds more than what is
--     left of the invoice total.
--
-- Replaces create_invoice, cancel_invoice and create_sales_return. Runs after
-- 20261007130000_inventory_lots.sql. Safe to run more than once.

-- --------------------------------------------------------------- client_ref
alter table public.invoices add column if not exists client_ref uuid;
create unique index if not exists invoices_client_ref_key on public.invoices (client_ref) where client_ref is not null;

-- ---------------------------------------------------------------- the sale
-- Creates a paid invoice in one transaction and returns { id, code, total, change_amount }.
-- p: {
--   branch_id, discount_amount?, note?,
--   customer_id? | customer?: { id } | { user_id } | { full_name, phone, email? },
--   lines: [{ type: 'product' | 'service' | 'combo', id, qty?, pet_id?, weight_kg? }],
--   payments: [{ method: 'cash' | 'transfer' | 'card', amount, bank_ref? }],
--   client_ref?: uuid, the same for every attempt at one sale
-- }
-- Prices come from the catalog: product price; combo fixed price; service general price, or
-- for a by-weight service the price for the pet's species and weight at this branch (the
-- line's weight_kg, else the pet's latest weight). A pet must belong to the invoice customer.
-- A discount above 10% of the subtotal needs "pos: Sửa".
create or replace function public.create_invoice(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_discount_limit constant numeric := 0.10;
  v_uid       uuid := (select auth.uid());
  v_branch    uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer  uuid := nullif(p ->> 'customer_id', '')::uuid;
  v_discount  numeric := coalesce(nullif(p ->> 'discount_amount', '')::numeric, 0);
  v_ref       uuid := nullif(p ->> 'client_ref', '')::uuid;
  v_shift     uuid;
  v_id        uuid;
  v_code      text;
  v_line      jsonb;
  v_pay       jsonb;
  v_line_no   int := 0;
  v_kind      text;
  v_item      uuid;
  v_pet       uuid;
  v_species   uuid;
  v_weight    numeric;
  v_qty       numeric;
  v_name      text;
  v_unit      text;
  v_price     numeric;
  v_subtotal  numeric := 0;
  v_total     numeric;
  v_paid      numeric := 0;
  v_cash      numeric := 0;
  v_change    numeric;
  v_method    text;
  v_amount    numeric;
  v_product   public.products;
  v_service   public.pet_services;
  v_combo     public.pet_service_combos;
  v_existing  public.invoices;
begin
  if v_uid is null or v_branch is null or not public.can_pos('CREATE', v_branch) then
    raise exception 'not allowed to sell at this branch' using errcode = '42501';
  end if;

  -- The same sale sent again: one attempt at a time, and the invoice it already made.
  if v_ref is not null then
    perform pg_advisory_xact_lock(hashtextextended('create_invoice:' || v_ref::text, 0));
    select * into v_existing from public.invoices where client_ref = v_ref;
    if found then
      if v_existing.created_by <> v_uid then
        raise exception 'client_ref belongs to another sale' using errcode = '23505';
      end if;
      return jsonb_build_object(
        'id', v_existing.id, 'code', v_existing.code, 'total', v_existing.total,
        'change_amount', v_existing.change_amount, 'replayed', true
      );
    end if;
  end if;

  -- The lock keeps the shift open until this sale commits; close_cash_shift waits for it.
  select id into v_shift
  from public.cash_shifts
  where branch_id = v_branch and opened_by = v_uid and status = 'open'
  for share;
  if v_shift is null then
    raise exception 'open a cash shift before selling' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  -- The buyer: a customer, a web account that becomes one, or a new walk-in typed at the
  -- counter (matched by phone, as register_pet does). No customer = anonymous sale.
  v_customer := coalesce(v_customer, nullif(p #>> '{customer,id}', '')::uuid);
  if v_customer is null and nullif(p #>> '{customer,user_id}', '') is not null then
    select id into v_customer from public.customers where user_id = (p #>> '{customer,user_id}')::uuid;
    if v_customer is null then
      insert into public.customers (full_name, phone, email, user_id, created_by)
      select coalesce(nullif(btrim(u.full_name), ''), u.display_name, u.email), u.phone_number, u.email, u.id, v_uid
      from public.users u
      where u.id = (p #>> '{customer,user_id}')::uuid and u.phone_number is not null
      on conflict on constraint customers_phone_digits_key
        do update set user_id = coalesce(public.customers.user_id, excluded.user_id), updated_at = now()
      returning id into v_customer;
    end if;
    if v_customer is null then
      raise exception 'account has no phone number' using errcode = 'P0002';
    end if;
  elsif v_customer is null and nullif(btrim(p #>> '{customer,phone}'), '') is not null then
    insert into public.customers (full_name, phone, email, created_by)
    values (
      btrim(p #>> '{customer,full_name}'),
      btrim(p #>> '{customer,phone}'),
      nullif(btrim(p #>> '{customer,email}'), ''),
      v_uid
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  elsif v_customer is not null and not exists (select 1 from public.customers where id = v_customer) then
    raise exception 'customer % not found', v_customer using errcode = 'P0002';
  end if;

  if jsonb_array_length(coalesce(p -> 'lines', '[]'::jsonb)) = 0 then
    raise exception 'an invoice needs at least one line' using errcode = '22023';
  end if;

  v_code := public.next_doc_code(v_branch, 'HD');
  insert into public.invoices (
    code, branch_id, shift_id, customer_id, customer_name, customer_phone, cashier_name,
    subtotal, discount_amount, total, note, created_by, client_ref
  )
  select
    v_code, v_branch, v_shift, v_customer, c.full_name, c.phone, public.staff_display_name(v_uid),
    0, 0, 0, nullif(btrim(p ->> 'note'), ''), v_uid, v_ref
  from (select 1) as one
  left join public.customers c on c.id = v_customer
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p -> 'lines') loop
    v_line_no := v_line_no + 1;
    v_kind := v_line ->> 'type';
    v_item := nullif(v_line ->> 'id', '')::uuid;
    v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 1);
    v_pet := nullif(v_line ->> 'pet_id', '')::uuid;
    v_weight := null;
    v_unit := null;

    if v_qty <= 0 then
      raise exception 'line %: quantity must be more than zero', v_line_no using errcode = '22023';
    end if;

    if v_pet is not null then
      if v_customer is null or not exists (
        select 1 from public.pet_owners
        where pet_id = v_pet and customer_id = v_customer and to_date is null
      ) then
        raise exception 'line %: the pet does not belong to this customer', v_line_no using errcode = '22023';
      end if;
    end if;

    if v_kind = 'product' then
      select * into v_product from public.products where id = v_item and is_active;
      if not found then
        raise exception 'line %: product is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_product.name;
      v_unit := v_product.unit;
      v_price := v_product.price;
      -- Stock is taken FEFO by the take_stock trigger on invoice_lines (inventory migration).
    elsif v_kind = 'combo' then
      select * into v_combo from public.pet_service_combos
      where id = v_item and status = 1 and is_active;
      if not found or v_combo.price is null then
        raise exception 'line %: combo is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_combo.name;
      v_price := v_combo.price;
    elsif v_kind = 'service' then
      select * into v_service from public.pet_services where id = v_item and is_active;
      if not found then
        raise exception 'line %: service is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_service.name;
      if v_service.type = 'by_weight' then
        if v_pet is null then
          raise exception 'line %: pick the pet for a by-weight service', v_line_no using errcode = '22023';
        end if;
        select species_id into v_species from public.pets where id = v_pet;
        v_weight := coalesce(
          nullif(v_line ->> 'weight_kg', '')::numeric,
          (select weight_kg from public.pet_weight_logs where pet_id = v_pet order by measured_at desc limit 1)
        );
        if v_weight is null or v_weight <= 0 then
          raise exception 'line %: the pet has no weight yet', v_line_no using errcode = '22023';
        end if;
        v_price := public.get_service_price(v_species, v_service.id, v_weight, v_branch);
      else
        v_price := v_service.general_price;
      end if;
      if v_price is null then
        raise exception 'line %: service has no price for this pet', v_line_no using errcode = 'P0002';
      end if;
    else
      raise exception 'line %: unknown type %', v_line_no, v_kind using errcode = '22023';
    end if;

    insert into public.invoice_lines (
      invoice_id, line_no, item_type, product_id, service_id, combo_id, pet_id, pet_name,
      name, unit, qty, unit_price, amount, weight_kg
    ) values (
      v_id, v_line_no, v_kind,
      case when v_kind = 'product' then v_item end,
      case when v_kind = 'service' then v_item end,
      case when v_kind = 'combo' then v_item end,
      v_pet, (select name from public.pets where id = v_pet), v_name, v_unit, v_qty, v_price, round(v_qty * v_price, 2), v_weight
    );
    v_subtotal := v_subtotal + round(v_qty * v_price, 2);
  end loop;

  if v_discount < 0 or v_discount > v_subtotal then
    raise exception 'discount must be between 0 and the subtotal' using errcode = '22023';
  end if;
  if v_discount > v_subtotal * c_discount_limit and not public.can_pos('UPDATE', v_branch) then
    raise exception 'a discount above 10%% needs a manager' using errcode = '42501', hint = 'discount_limit';
  end if;
  v_total := v_subtotal - v_discount;

  for v_pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
    v_method := v_pay ->> 'method';
    v_amount := coalesce(nullif(v_pay ->> 'amount', '')::numeric, 0);
    if v_amount <= 0 then
      continue;
    end if;
    if v_method not in ('cash', 'transfer', 'card') then
      raise exception 'unknown payment method %', v_method using errcode = '22023';
    end if;
    insert into public.payments (invoice_id, method, amount, bank_ref)
    values (v_id, v_method, v_amount, nullif(btrim(v_pay ->> 'bank_ref'), ''));
    v_paid := v_paid + v_amount;
    if v_method = 'cash' then
      v_cash := v_cash + v_amount;
    end if;
  end loop;

  if v_paid < v_total then
    raise exception 'payments do not cover the total' using errcode = '22023', hint = 'underpaid';
  end if;
  v_change := v_paid - v_total;
  -- Only cash can be overpaid and handed back.
  if v_change > v_cash then
    raise exception 'transfer and card cannot exceed the total' using errcode = '22023', hint = 'overpaid';
  end if;

  update public.invoices
  set subtotal = v_subtotal,
      discount_amount = v_discount,
      total = v_total,
      paid_amount = v_paid,
      change_amount = v_change
  where id = v_id;

  return jsonb_build_object('id', v_id, 'code', v_code, 'total', v_total, 'change_amount', v_change, 'replayed', false);
end;
$$;

revoke execute on function public.create_invoice(jsonb) from public, anon;
grant execute on function public.create_invoice(jsonb) to authenticated;

-- Cancels a paid invoice while its shift is still open (the refund comes out of that drawer).
-- Returns after a shift is closed belong to the returns flow, which comes later.
create or replace function public.cancel_invoice(p_id uuid, p_reason text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices where id = p_id for update;
  if not found then
    raise exception 'invoice % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_pos('DELETE', v_invoice.branch_id) then
    raise exception 'not allowed to cancel invoices' using errcode = '42501';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'invoice is already cancelled' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'a reason is required' using errcode = '22023';
  end if;
  -- Locked like a sale, so the shift cannot be closed and counted while this cancel commits.
  perform 1 from public.cash_shifts where id = v_invoice.shift_id and status = 'open' for share;
  if not found then
    raise exception 'the shift of this invoice is closed' using errcode = '22023', hint = 'shift_closed';
  end if;

  update public.invoices
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = (select auth.uid()),
      cancel_reason = btrim(p_reason)
  where id = p_id;
end;
$$;

revoke execute on function public.cancel_invoice(uuid, text) from public, anon;
grant execute on function public.cancel_invoice(uuid, text) to authenticated;

-- ------------------------------------------------------------------- returns
-- Takes goods back on a paid invoice and refunds them from the caller's open shift.
-- p: { invoice_id, reason, refund_method: 'cash' | 'transfer', lines: [{ invoice_line_id, qty }] }
-- Only product lines are returned. Each line is refunded at what the customer paid for it,
-- the invoice discount spread over the lines, in whole dong. The goods go back into the lots they came from.
-- Needs "pos: DELETE", like cancelling an invoice. Returns { id, code, refund_amount }.
create or replace function public.create_sales_return(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_invoice  public.invoices;
  v_shift    uuid;
  v_method   text := coalesce(p ->> 'refund_method', 'cash');
  v_reason   text := btrim(coalesce(p ->> 'reason', ''));
  v_id       uuid;
  v_code     text;
  v_line     jsonb;
  v_inv_line public.invoice_lines;
  v_qty      numeric;
  v_returned numeric;
  v_amount   numeric;
  v_refund   numeric := 0;
  v_left     numeric;
  v_take     numeric;
  v_lot      record;
  v_line_refunded    numeric;
  v_invoice_refunded numeric;
begin
  select * into v_invoice from public.invoices where id = nullif(p ->> 'invoice_id', '')::uuid for update;
  if not found then
    raise exception 'invoice not found' using errcode = 'P0002';
  end if;
  if v_uid is null or not public.can_pos('DELETE', v_invoice.branch_id) then
    raise exception 'not allowed to take returns' using errcode = '42501';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'invoice is cancelled' using errcode = '22023';
  end if;
  if v_method not in ('cash', 'transfer') then
    raise exception 'unknown refund method %', v_method using errcode = '22023';
  end if;
  if length(v_reason) = 0 then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  if jsonb_array_length(coalesce(p -> 'lines', '[]'::jsonb)) = 0 then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  select id into v_shift
  from public.cash_shifts
  where branch_id = v_invoice.branch_id and opened_by = v_uid and status = 'open'
  for share;
  if v_shift is null then
    raise exception 'open a cash shift before refunding' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  v_code := public.next_doc_code(v_invoice.branch_id, 'TH');
  insert into public.sales_returns (
    code, branch_id, invoice_id, shift_id, refund_method, refund_amount, reason, created_by, created_by_name
  ) values (
    v_code, v_invoice.branch_id, v_invoice.id, v_shift, v_method, 0, v_reason, v_uid,
    public.staff_display_name(v_uid)
  )
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p -> 'lines') loop
    v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
    if v_qty <= 0 then
      continue;
    end if;

    select * into v_inv_line from public.invoice_lines
    where id = nullif(v_line ->> 'invoice_line_id', '')::uuid and invoice_id = v_invoice.id
    for update;
    if not found then
      raise exception 'the line is not on this invoice' using errcode = 'P0002';
    end if;
    if v_inv_line.item_type <> 'product' then
      raise exception '% is not a product', v_inv_line.name using errcode = '22023', hint = 'return_products_only';
    end if;

    select coalesce(sum(qty), 0) into v_returned
    from public.sales_return_lines where invoice_line_id = v_inv_line.id;
    if v_qty > v_inv_line.qty - v_returned then
      raise exception 'only % of % can still be returned', v_inv_line.qty - v_returned, v_inv_line.name
        using errcode = '22023', hint = 'return_too_much', detail = v_inv_line.name;
    end if;

    -- Whole dong: what the units returned so far (this one included) cost the customer, less
    -- what earlier returns of the line refunded, and never more than is left of the invoice.
    select coalesce(sum(amount), 0) into v_line_refunded
    from public.sales_return_lines where invoice_line_id = v_inv_line.id;
    v_amount := case when v_invoice.subtotal > 0
      then round(v_inv_line.amount * (v_returned + v_qty) / v_inv_line.qty * v_invoice.total / v_invoice.subtotal)
           - v_line_refunded
      else 0 end;
    select coalesce(sum(l.amount), 0) into v_invoice_refunded
    from public.sales_return_lines l
    join public.sales_returns r on r.id = l.return_id
    where r.invoice_id = v_invoice.id;
    v_amount := greatest(0, least(v_amount, v_invoice.total - v_invoice_refunded));
    insert into public.sales_return_lines (return_id, invoice_line_id, product_id, name, qty, amount)
    values (v_id, v_inv_line.id, v_inv_line.product_id, v_inv_line.name, v_qty, v_amount);
    v_refund := v_refund + v_amount;

    -- Back into the lots this line still has out, the latest taken first. A line sold before
    -- the product tracked stock has none and returns nothing to stock.
    v_left := v_qty;
    for v_lot in
      select lot_id, -sum(qty) as out_qty
      from public.stock_movements
      where invoice_line_id = v_inv_line.id
      group by lot_id
      having sum(qty) < 0
      order by max(created_at) desc, lot_id
    loop
      exit when v_left <= 0;
      v_take := least(v_left, v_lot.out_qty);
      perform public.move_stock(
        v_lot.lot_id, v_take, 'return', p_invoice => v_invoice.id, p_invoice_line => v_inv_line.id, p_return => v_id
      );
      v_left := v_left - v_take;
    end loop;
  end loop;

  if not exists (select 1 from public.sales_return_lines where return_id = v_id) then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  update public.sales_returns set refund_amount = v_refund where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'refund_amount', v_refund);
end;
$$;

revoke execute on function public.create_sales_return(jsonb) from public, anon;
grant execute on function public.create_sales_return(jsonb) to authenticated;

notify pgrst, 'reload schema';
