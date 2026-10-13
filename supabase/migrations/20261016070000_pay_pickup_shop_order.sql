-- Shop checkout, step 7 (1/2): the customer collects and pays an in-store pickup order at the
-- counter (docs/checkout-shop.md, 3.5 and 5.2). Safe to run more than once.
--
-- p_payments: [{ method: 'cash' | 'transfer' | 'card', amount, bank_ref? }], as in create_invoice.
-- Needs pos: CREATE at the order's branch and an open cash shift of the caller; the money goes
-- into that shift. The order must be packed. Pressing twice is harmless: an order that is already
-- completed is returned as it is, without a second payment.
-- Failures carry a hint: order_not_found, bad_status, no_open_shift, underpaid, overpaid.

create or replace function public.pay_pickup_shop_order(p_id uuid, p_payments jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  o        public.shop_orders;
  i        public.invoices;
  v_shift  uuid;
  v_pay    jsonb;
  v_method text;
  v_amount numeric;
  v_paid   numeric := 0;
  v_cash   numeric := 0;
  v_change numeric;
begin
  select * into o from public.shop_orders where id = p_id for update;
  if not found or v_uid is null or not public.can_pos('CREATE', o.branch_id) then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  if o.delivery_method <> 'pickup' then
    raise exception 'only a pickup order is paid at the counter' using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;
  if o.status = 'completed' then
    return public.staff_shop_order_json(o);
  end if;
  if o.status <> 'packed' then
    raise exception 'the order is % now', o.status using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;

  -- Locked like a sale, so the shift cannot be closed and counted while this payment commits.
  select id into v_shift
  from public.cash_shifts
  where branch_id = o.branch_id and opened_by = v_uid and status = 'open'
  for share;
  if v_shift is null then
    raise exception 'open a cash shift before taking payment' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  select * into i from public.invoices where id = o.invoice_id for update;

  for v_pay in select * from jsonb_array_elements(coalesce(p_payments, '[]'::jsonb)) loop
    v_method := v_pay ->> 'method';
    v_amount := coalesce(nullif(v_pay ->> 'amount', '')::numeric, 0);
    if v_amount <= 0 then
      continue;
    end if;
    if v_method not in ('cash', 'transfer', 'card') then
      raise exception 'unknown payment method %', v_method using errcode = '22023';
    end if;
    insert into public.payments (invoice_id, method, amount, bank_ref)
    values (i.id, v_method, v_amount, nullif(btrim(v_pay ->> 'bank_ref'), ''));
    v_paid := v_paid + v_amount;
    if v_method = 'cash' then
      v_cash := v_cash + v_amount;
    end if;
  end loop;

  if v_paid < i.total then
    raise exception 'payments do not cover the total' using errcode = '22023', hint = 'underpaid';
  end if;
  v_change := v_paid - i.total;
  -- Only cash can be overpaid and handed back.
  if v_change > v_cash then
    raise exception 'transfer and card cannot exceed the total' using errcode = '22023', hint = 'overpaid';
  end if;

  update public.invoices
  set status = 'paid', shift_id = v_shift, paid_amount = v_paid, change_amount = v_change,
      cashier_name = public.staff_display_name(v_uid)
  where id = i.id;

  update public.shop_orders set status = 'completed', completed_at = now() where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'completed');
  return public.staff_shop_order_json(o);
end;
$$;

revoke execute on function public.pay_pickup_shop_order(uuid, jsonb) from public, anon;
grant execute on function public.pay_pickup_shop_order(uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
