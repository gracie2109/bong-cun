-- Pet hotel, step 4 (2/2): create_invoice and cancel_invoice handle boarding charges.
-- Copies of the versions in 20261015040500_create_invoice_units.sql and
-- 20261013050100_pos_invoice_appointments.sql, plus the 'boarding_charge' line and the un-billing
-- on cancel. Runs after 20261020040000_boarding_billing.sql. Re-runnable.

-- Creates a paid invoice in one transaction and returns { id, code, total, change_amount }.
-- p: {
--   branch_id, discount_amount?, note?,
--   customer_id? | customer?: { id } | { user_id } | { full_name, phone, email? },
--   lines: [{ type: 'product' | 'service' | 'combo' | 'appointment_item' | 'boarding_charge', id, qty?, unit_id?, pet_id?, weight_kg? }],
--   payments: [{ method: 'cash' | 'transfer' | 'card', amount, bank_ref? }],
--   client_ref?: uuid, the same for every attempt at one sale
-- }
-- A product line may be sold in one of its conversion units (unit_id): qty counts that unit, the
-- price is the unit's price, and stock is taken in base units (qty x factor).
-- Prices come from the catalog: product price (the branch's, else the general one); combo fixed price; service general price, or
-- for a by-weight service the price for the pet's species and weight at this branch (the
-- line's weight_kg, else the pet's latest weight). A pet must belong to the invoice customer.
-- A 'boarding_charge' line is a charge of a checked-out pet hotel stay of the same customer: its name,
-- quantity and price are the ones on the charge, and the charge is marked as billed.
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
  v_ticket    public.appointment_items;
  v_ticket_appt uuid;
  v_line_id   uuid;
  v_unit_id   uuid;
  v_factor    numeric;
  v_unit_row  public.product_units;
  v_charge    public.boarding_charges;
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
    v_unit_id := null;
    v_factor := 1;
    v_ticket := null;
    v_charge := null;

    -- A finished spa ticket: its price, pet and name are the ones fixed at check-in.
    if v_kind = 'appointment_item' then
      select i.* into v_ticket
      from public.appointment_items i
      join public.appointments a on a.id = i.appointment_id
      where i.id = v_item and a.branch_id = v_branch and a.customer_id is not distinct from v_customer
      for update of i;
      if not found or v_ticket.status <> 'done' or v_ticket.invoice_line_id is not null or v_ticket.unit_price is null then
        raise exception 'line %: the spa ticket cannot be paid here', v_line_no using errcode = 'P0001', hint = 'ticket_not_billable';
      end if;
      v_ticket_appt := v_ticket.appointment_id;
      v_kind := v_ticket.item_type;
      v_item := coalesce(v_ticket.service_id, v_ticket.combo_id);
      v_qty := 1;
      v_pet := v_ticket.pet_id;
      v_name := v_ticket.name;
      v_price := v_ticket.unit_price;
      v_weight := v_ticket.weight_kg;
    end if;

    -- A charge of a checked-out boarding stay: its qty, price and name are fixed at check-out.
    if v_kind = 'boarding_charge' then
      select c.* into v_charge
      from public.boarding_charges c
      join public.boarding_stays s on s.id = c.stay_id
      where c.id = v_item and s.branch_id = v_branch and s.customer_id is not distinct from v_customer
        and s.status = 'checked_out'
      for update of c;
      if not found or v_charge.invoice_line_id is not null then
        raise exception 'line %: the boarding charge cannot be paid here', v_line_no using errcode = 'P0001', hint = 'charge_not_billable';
      end if;
      v_kind := 'boarding';
      v_item := null;
      v_qty := v_charge.qty;
      v_pet := null;
      v_name := coalesce(
        (select v_charge.name || ' · ' || p.name
         from public.boarding_stay_pets sp join public.pets p on p.id = sp.pet_id
         where sp.id = v_charge.stay_pet_id),
        v_charge.name
      );
      v_price := v_charge.unit_price;
    end if;

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

    if v_ticket.id is not null or v_charge.id is not null then
      null; -- priced above
    elsif v_kind = 'product' then
      select * into v_product from public.products where id = v_item and is_active;
      if not found then
        raise exception 'line %: product is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_product.name;
      v_unit := v_product.unit;
      v_unit_id := nullif(v_line ->> 'unit_id', '')::uuid;
      if v_unit_id is not null then
        select * into v_unit_row from public.product_units
        where id = v_unit_id and product_id = v_item and is_active and for_sale;
        if not found then
          raise exception 'line %: the unit is not available', v_line_no using errcode = 'P0002', hint = 'unit_not_available';
        end if;
        v_unit := v_unit_row.name;
        v_factor := v_unit_row.factor;
      end if;
      v_price := public.product_unit_price(v_item, v_branch, v_unit_id);
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
      name, unit, qty, unit_price, amount, weight_kg, unit_id, unit_factor
    ) values (
      v_id, v_line_no, v_kind,
      case when v_kind = 'product' then v_item end,
      case when v_kind = 'service' then v_item end,
      case when v_kind = 'combo' then v_item end,
      v_pet, (select name from public.pets where id = v_pet), v_name, v_unit, v_qty, v_price, round(v_qty * v_price, 2), v_weight,
      v_unit_id, v_factor
    )
    returning id into v_line_id;
    if v_charge.id is not null then
      update public.boarding_charges set invoice_line_id = v_line_id where id = v_charge.id;
      perform public.refresh_boarding_stay_status(v_charge.stay_id);
    end if;
    if v_ticket.id is not null then
      update public.appointment_items set invoice_line_id = v_line_id where id = v_ticket.id;
      perform public.refresh_appointment_status(v_ticket_appt);
    end if;
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
  v_freed   uuid;
  v_stay    uuid;
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

  -- Spa tickets on this invoice are unpaid again.
  for v_freed in
    with freed as (
      update public.appointment_items i
      set invoice_line_id = null
      from public.invoice_lines l
      where l.invoice_id = p_id and i.invoice_line_id = l.id
      returning i.appointment_id
    )
    select distinct appointment_id from freed
  loop
    perform public.refresh_appointment_status(v_freed);
  end loop;

  -- Boarding charges on this invoice are unpaid again.
  for v_stay in
    with freed as (
      update public.boarding_charges c
      set invoice_line_id = null
      from public.invoice_lines l
      where l.invoice_id = p_id and c.invoice_line_id = l.id
      returning c.stay_id
    )
    select distinct stay_id from freed
  loop
    perform public.refresh_boarding_stay_status(v_stay);
  end loop;
end;
$$;

revoke execute on function public.cancel_invoice(uuid, text) from public, anon;
grant execute on function public.cancel_invoice(uuid, text) to authenticated;

notify pgrst, 'reload schema';
