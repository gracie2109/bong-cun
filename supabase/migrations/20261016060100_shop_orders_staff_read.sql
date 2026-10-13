-- Shop checkout, step 6 (2/3): what staff see of online orders (docs/checkout-shop.md, 5.2).
-- Safe to run more than once. Needs shop_orders: VIEW at the order's branch.

-- One order as staff read it; every status change returns the same shape.
-- "available" is what can be sold of a line's product, not counting this order's own hold.
create or replace function public.staff_shop_order_json(o public.shop_orders) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', o.id,
    'code', o.code,
    'branch_id', o.branch_id,
    'status', o.status,
    'delivery_method', o.delivery_method,
    'payment_method', o.payment_method,
    'customer_id', o.customer_id,
    'receiver_name', o.receiver_name,
    'receiver_phone', o.receiver_phone,
    'ship_street', o.ship_street,
    'ship_ward_name', o.ship_ward_name,
    'ship_district_name', o.ship_district_name,
    'ship_province_name', o.ship_province_name,
    'ghn_district_id', o.ghn_district_id,
    'ghn_ward_code', o.ghn_ward_code,
    'weight_g', o.weight_g,
    'subtotal', o.subtotal,
    'shipping_fee_quote', o.shipping_fee_quote,
    'shipping_fee', o.shipping_fee,
    'total', o.total,
    'customer_note', o.customer_note,
    'carrier', o.carrier,
    'tracking_code', o.tracking_code,
    'cancel_reason', o.cancel_reason,
    'placed_at', o.placed_at,
    'invoice', (
      select jsonb_build_object('id', i.id, 'code', i.code, 'status', i.status, 'total', i.total)
      from public.invoices i where i.id = o.invoice_id
    ),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', l.product_id, 'unit_id', l.unit_id, 'name', l.name, 'unit', l.unit,
        'image_url', l.image_url, 'qty', l.qty, 'unit_factor', l.unit_factor,
        'unit_price', l.unit_price, 'amount', l.amount,
        'track_stock', p.track_stock,
        'available', (
          select coalesce(
            (select a.qty from public.shop_available_qty(array[l.product_id]) a limit 1), 0)
            + case when o.status in ('pending', 'confirmed') then (
                select coalesce(sum(x.qty * x.unit_factor), 0)
                from public.shop_order_lines x where x.order_id = o.id and x.product_id = l.product_id)
              else 0 end
        )
      ) order by l.line_no)
      from public.shop_order_lines l
      join public.products p on p.id = l.product_id
      where l.order_id = o.id
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'status', e.status, 'note', e.note, 'actor_name', e.actor_name, 'created_at', e.created_at
      ) order by e.created_at, e.id)
      from public.shop_order_events e where e.order_id = o.id
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.staff_shop_order_json(public.shop_orders) from public, anon, authenticated;

-- p_branch null is the online branch. p_status is an order status, 'closed' (cancelled and
-- returned) or null for all. Search matches code, receiver name, phone and tracking code.
-- Returns { rows: [...], total_count, counts: { status: n } }; counts ignore p_status.
create or replace function public.list_shop_orders(
  p_branch uuid default null,
  p_status text default null,
  p_search text default null,
  p_page int default 1,
  p_page_size int default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branch uuid := coalesce(p_branch, (select online_branch_id from public.shop_settings where id));
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_off    int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_rows   jsonb;
  v_total  bigint;
  v_counts jsonb;
begin
  if not public.can_shop_orders('VIEW', v_branch) then
    raise exception 'not allowed to see online orders' using errcode = '42501';
  end if;

  with hits as (
    select o.* from public.shop_orders o
    where o.branch_id = v_branch
      and (v_term = '' or lower(public.immutable_unaccent(
             o.code || ' ' || o.receiver_name || ' ' || o.receiver_phone || ' ' || coalesce(o.tracking_code, '')))
           like '%' || v_term || '%')
  ), shown as (
    select h.* from hits h
    where p_status is null or h.status = p_status or (p_status = 'closed' and h.status in ('cancelled', 'returned'))
  )
  select
    (select coalesce(jsonb_object_agg(c.status, c.n), '{}'::jsonb)
       from (select status, count(*) as n from hits group by status) c),
    (select count(*) from shown),
    (select coalesce(jsonb_agg(r order by r.placed_at desc, r.id), '[]'::jsonb)
       from (
         select sh.id, sh.code, sh.placed_at, sh.receiver_name, sh.receiver_phone, sh.delivery_method, sh.status,
                sh.total, sh.tracking_code, sh.shipping_fee is not null as fee_confirmed,
                (select count(*) from public.shop_order_lines l where l.order_id = sh.id) as line_count
         from shown sh
         order by sh.placed_at desc, sh.id
         limit v_size offset v_off
       ) r)
  into v_counts, v_total, v_rows;

  return jsonb_build_object('rows', v_rows, 'total_count', v_total, 'counts', v_counts);
end;
$$;

revoke execute on function public.list_shop_orders(uuid, text, text, int, int) from public, anon;
grant execute on function public.list_shop_orders(uuid, text, text, int, int) to authenticated;

create or replace function public.get_shop_order(p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  o public.shop_orders;
begin
  select * into o from public.shop_orders where id = p_id;
  if not found or not public.can_shop_orders('VIEW', o.branch_id) then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  return public.staff_shop_order_json(o);
end;
$$;

revoke execute on function public.get_shop_order(uuid) from public, anon;
grant execute on function public.get_shop_order(uuid) to authenticated;

notify pgrst, 'reload schema';
