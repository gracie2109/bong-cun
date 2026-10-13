-- Shop checkout, step 5 (4/4): the shopper's own orders (docs/checkout-shop.md, section 5.2).
-- Safe to run more than once.
--
-- my_shop_orders lists them, my_shop_order reads one with its lines and timeline, and
-- cancel_my_shop_order cancels one that has not been packed. All of them only see orders of the
-- signed-in account, so another shopper's code answers "not found".

-- One order as the customer reads it. Staff names and ids are left out of the timeline.
create or replace function public.my_shop_order_json(o public.shop_orders) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', o.id,
    'code', o.code,
    'status', o.status,
    'delivery_method', o.delivery_method,
    'payment_method', o.payment_method,
    'receiver_name', o.receiver_name,
    'receiver_phone', o.receiver_phone,
    'ship_street', o.ship_street,
    'ship_ward_name', o.ship_ward_name,
    'ship_district_name', o.ship_district_name,
    'ship_province_name', o.ship_province_name,
    'weight_g', o.weight_g,
    'subtotal', o.subtotal,
    'shipping_fee_quote', o.shipping_fee_quote,
    'shipping_fee', o.shipping_fee,
    'shipping_fee_confirmed', o.shipping_fee is not null,
    'total', o.total,
    'customer_note', o.customer_note,
    'carrier', o.carrier,
    'tracking_code', o.tracking_code,
    'cancel_reason', o.cancel_reason,
    'placed_at', o.placed_at,
    'payment_status', case
      when exists (select 1 from public.invoices i where i.id = o.invoice_id and i.status = 'paid') then 'paid'
      else 'unpaid'
    end,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', l.product_id, 'unit_id', l.unit_id, 'name', l.name, 'unit', l.unit,
        'image_url', l.image_url, 'qty', l.qty, 'unit_price', l.unit_price, 'amount', l.amount
      ) order by l.line_no)
      from public.shop_order_lines l where l.order_id = o.id
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object('status', e.status, 'note', e.note, 'created_at', e.created_at)
                       order by e.created_at, e.id)
      from public.shop_order_events e where e.order_id = o.id
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.my_shop_order_json(public.shop_orders) from public, anon, authenticated;

-- p_status null lists every order; else only that status. 1-based page, page size 1..50.
-- Returns { rows: [{ id, code, status, delivery_method, total, line_count, first_name,
-- first_image, placed_at }], total_count }, newest first.
create or replace function public.my_shop_orders(
  p_status    text default null,
  p_page      int default 1,
  p_page_size int default 10
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := (select auth.uid());
  v_size int := least(greatest(coalesce(p_page_size, 10), 1), 50);
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_rows jsonb;
  v_total bigint;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;

  select count(*) into v_total from public.shop_orders o
  where o.user_id = v_uid and (p_status is null or o.status = p_status);

  select coalesce(jsonb_agg(x order by x.placed_at desc, x.code desc), '[]'::jsonb) into v_rows
  from (
    select o.id, o.code, o.status, o.delivery_method, o.total, o.placed_at,
           (select count(*) from public.shop_order_lines l where l.order_id = o.id) as line_count,
           (select l.name from public.shop_order_lines l where l.order_id = o.id order by l.line_no limit 1) as first_name,
           (select l.image_url from public.shop_order_lines l where l.order_id = o.id order by l.line_no limit 1) as first_image
    from public.shop_orders o
    where o.user_id = v_uid and (p_status is null or o.status = p_status)
    order by o.placed_at desc, o.code desc
    offset (v_page - 1) * v_size limit v_size
  ) x;

  return jsonb_build_object('rows', v_rows, 'total_count', v_total);
end;
$$;

revoke execute on function public.my_shop_orders(text, int, int) from public, anon;
grant execute on function public.my_shop_orders(text, int, int) to authenticated;

create or replace function public.my_shop_order(p_code text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.shop_orders;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_row from public.shop_orders where code = p_code and user_id = v_uid;
  if not found then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  return public.my_shop_order_json(v_row);
end;
$$;

revoke execute on function public.my_shop_order(text) from public, anon;
grant execute on function public.my_shop_order(text) to authenticated;

-- Cancels the caller's order while it is 'pending' or 'confirmed' (not packed yet, so no stock
-- was taken and no invoice exists). The row lock makes a double press, or a press racing with
-- staff packing the order, act once. Returns the order.
create or replace function public.cancel_my_shop_order(p_code text, p_reason text default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_row    public.shop_orders;
  v_reason text := left(nullif(btrim(coalesce(p_reason, '')), ''), 300);
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_row from public.shop_orders where code = p_code and user_id = v_uid for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  if v_row.status not in ('pending', 'confirmed') then
    raise exception 'this order can no longer be cancelled' using errcode = '22023', hint = 'not_cancellable';
  end if;

  update public.shop_orders
  set status = 'cancelled', cancelled_at = now(), cancel_reason = v_reason
  where id = v_row.id
  returning * into v_row;

  insert into public.shop_order_events (order_id, status, note, actor_id, actor_name)
  values (v_row.id, 'cancelled', v_reason, v_uid, 'Khách');

  return public.my_shop_order_json(v_row);
end;
$$;

revoke execute on function public.cancel_my_shop_order(text, text) from public, anon;
grant execute on function public.cancel_my_shop_order(text, text) to authenticated;

notify pgrst, 'reload schema';
