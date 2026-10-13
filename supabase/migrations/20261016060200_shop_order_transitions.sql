-- Shop checkout, step 6 (3/3): staff move an online order along (docs/checkout-shop.md, 3.7).
-- Safe to run more than once. Needs shop_orders: UPDATE at the order's branch.
--
-- Every change locks the order row and checks the status it starts from, so pressing a button
-- twice, or two staff pressing at once, changes the order once. Each returns the order the way
-- get_shop_order shows it. Failures carry a hint: order_not_found, bad_status, invalid_fee,
-- cod_limit, tracking_required, reason_required, out_of_stock (detail: the product).

-- Locks the order and checks the caller and the status it must be in.
create or replace function public.shop_order_for_update(p_id uuid, p_from text[]) returns public.shop_orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.shop_orders;
begin
  select * into o from public.shop_orders where id = p_id for update;
  if not found or not public.can_shop_orders('UPDATE', o.branch_id) then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  if not (o.status = any (p_from)) then
    raise exception 'the order is % now', o.status using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;
  return o;
end;
$$;

revoke execute on function public.shop_order_for_update(uuid, text[]) from public, anon, authenticated;

create or replace function public.shop_order_log(p_id uuid, p_status text, p_note text default null) returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.shop_order_events (order_id, status, note, actor_id, actor_name)
  values (p_id, p_status, nullif(btrim(p_note), ''), (select auth.uid()), public.staff_display_name((select auth.uid())));
$$;

revoke execute on function public.shop_order_log(uuid, text, text) from public, anon, authenticated;

-- The invoice of a packed order: online, unpaid, no shift. The take_stock trigger on its lines
-- takes the stock FEFO, so an order without stock fails here as a whole.
create or replace function public.issue_shop_order_invoice(p_order uuid) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  o         public.shop_orders;
  v_id      uuid;
  v_cust    public.customers;
begin
  select * into o from public.shop_orders where id = p_order;
  select * into v_cust from public.customers where id = o.customer_id;

  insert into public.invoices (
    code, branch_id, shift_id, channel, status, customer_id, customer_name, customer_phone, cashier_name,
    subtotal, discount_amount, total, note, created_by
  ) values (
    public.next_doc_code(o.branch_id, 'HD'), o.branch_id, null, 'online', 'unpaid', o.customer_id,
    v_cust.full_name, coalesce(nullif(o.receiver_phone, ''), v_cust.phone),
    public.staff_display_name((select auth.uid())),
    o.subtotal, 0, o.subtotal, o.code, (select auth.uid())
  )
  returning id into v_id;

  insert into public.invoice_lines (
    invoice_id, line_no, item_type, product_id, name, unit, qty, unit_price, amount, unit_id, unit_factor
  )
  select v_id, l.line_no, 'product', l.product_id, l.name, l.unit, l.qty, l.unit_price, l.amount, l.unit_id, l.unit_factor
  from public.shop_order_lines l where l.order_id = o.id order by l.line_no;

  update public.shop_orders set invoice_id = v_id where id = o.id;
  return v_id;
end;
$$;

revoke execute on function public.issue_shop_order_invoice(uuid) from public, anon, authenticated;

-- Cancels the order's invoice, if it has one; the trigger puts the stock back.
create or replace function public.shop_order_cancel_invoice(p_invoice uuid, p_reason text) returns void
language sql
security definer
set search_path = ''
as $$
  update public.invoices
  set status = 'cancelled', cancelled_at = now(), cancelled_by = (select auth.uid()), cancel_reason = p_reason
  where id = p_invoice and status <> 'cancelled';
$$;

revoke execute on function public.shop_order_cancel_invoice(uuid, text) from public, anon, authenticated;

-- ------------------------------------------------------------------ the steps
-- pending -> confirmed: the shipping fee is fixed (null keeps the estimate). Pickup has no fee.
create or replace function public.confirm_shop_order(p_id uuid, p_shipping_fee numeric default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o     public.shop_orders := public.shop_order_for_update(p_id, array['pending']);
  v_fee numeric;
  v_max numeric;
begin
  if o.delivery_method = 'pickup' then
    v_fee := 0;
  else
    v_fee := round(coalesce(p_shipping_fee, o.shipping_fee_quote));
    if v_fee < 0 or v_fee > 500000 then
      raise exception 'the shipping fee must be between 0 and 500000' using errcode = '22023', hint = 'invalid_fee';
    end if;
    select cod_max into v_max from public.shop_settings where id;
    if o.subtotal + v_fee > v_max then
      raise exception 'cash on delivery is limited to % VND', v_max using errcode = '22023', hint = 'cod_limit';
    end if;
  end if;

  update public.shop_orders
  set status = 'confirmed', shipping_fee = v_fee, total = subtotal + v_fee, confirmed_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'confirmed');
  return public.staff_shop_order_json(o);
end;
$$;

-- confirmed -> packed: invoice (unpaid) and stock.
create or replace function public.pack_shop_order(p_id uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.shop_orders := public.shop_order_for_update(p_id, array['confirmed']);
begin
  perform public.issue_shop_order_invoice(o.id);
  update public.shop_orders set status = 'packed', packed_at = now() where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'packed');
  return public.staff_shop_order_json(o);
end;
$$;

-- packed -> shipping (delivery only): the GHN waybill the parcel travels under.
create or replace function public.ship_shop_order(p_id uuid, p_tracking_code text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o      public.shop_orders := public.shop_order_for_update(p_id, array['packed']);
  v_code text := btrim(coalesce(p_tracking_code, ''));
begin
  if o.delivery_method <> 'delivery' then
    raise exception 'a pickup order is not shipped' using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;
  if v_code = '' or length(v_code) > 40 then
    raise exception 'enter the tracking code' using errcode = '22023', hint = 'tracking_required';
  end if;
  update public.shop_orders
  set status = 'shipping', carrier = 'ghn', tracking_code = v_code, shipped_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'shipping', v_code);
  return public.staff_shop_order_json(o);
end;
$$;

-- shipping -> completed: the courier collected the cash, so the invoice is paid by 'cod'.
create or replace function public.deliver_shop_order(p_id uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o public.shop_orders := public.shop_order_for_update(p_id, array['shipping']);
  i public.invoices;
begin
  select * into i from public.invoices where id = o.invoice_id for update;
  update public.invoices set status = 'paid', paid_amount = total, change_amount = 0 where id = i.id;
  if i.total > 0 then
    insert into public.payments (invoice_id, method, amount) values (i.id, 'cod', i.total);
  end if;
  update public.shop_orders set status = 'completed', completed_at = now() where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'completed');
  return public.staff_shop_order_json(o);
end;
$$;

-- shipping -> returned: the parcel came back; the invoice is cancelled and the stock returns.
create or replace function public.return_shop_order(p_id uuid, p_reason text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o        public.shop_orders := public.shop_order_for_update(p_id, array['shipping']);
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_reason = '' then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  perform public.shop_order_cancel_invoice(o.invoice_id, v_reason);
  update public.shop_orders set status = 'returned', cancel_reason = v_reason, cancelled_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'returned', v_reason);
  return public.staff_shop_order_json(o);
end;
$$;

-- pending / confirmed / packed -> cancelled, with a reason. A packed order has an invoice to cancel.
create or replace function public.cancel_shop_order(p_id uuid, p_reason text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o        public.shop_orders := public.shop_order_for_update(p_id, array['pending', 'confirmed', 'packed']);
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_reason = '' then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  if o.invoice_id is not null then
    perform public.shop_order_cancel_invoice(o.invoice_id, v_reason);
  end if;
  update public.shop_orders set status = 'cancelled', cancel_reason = v_reason, cancelled_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'cancelled', v_reason);
  return public.staff_shop_order_json(o);
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'confirm_shop_order(uuid, numeric)', 'pack_shop_order(uuid)', 'ship_shop_order(uuid, text)',
    'deliver_shop_order(uuid)', 'return_shop_order(uuid, text)', 'cancel_shop_order(uuid, text)'
  ] loop
    execute format('revoke execute on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end;
$$;

notify pgrst, 'reload schema';
