-- Shop checkout, step 2: refresh the shop cart from the database (docs/checkout-shop.md,
-- sections 3.1, 3.2 and 5.2). Safe to run more than once.
--
-- The browser keeps only (product, unit, qty) for each cart line. This function gives back what
-- the cart screens need to draw those lines: name, picture, shared shop price, shipping rule,
-- weight and how many can still be sold. The price is never taken from the client.

-- Units of one product the shop can still sell, per base unit: stock at the online branch that
-- is not expired. Products that do not track stock have no row (they are always available).
-- Step 5 redefines this to also hold back what open online orders have reserved.
create or replace function public.shop_available_qty(p_products uuid[])
returns table (product_id uuid, qty numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, coalesce(sum(l.qty_on_hand) filter (
           where l.expiry_date is null or l.expiry_date >= public.business_date()), 0)
  from public.products p
  join public.shop_settings s on s.id
  left join public.stock_lots l
    on l.product_id = p.id and l.branch_id = s.online_branch_id and l.qty_on_hand > 0
  where p.id = any(p_products) and p.track_stock
  group by p.id;
$$;

revoke execute on function public.shop_available_qty(uuid[]) from public, anon, authenticated;

-- p_lines: [{ product_id, unit_id, qty }] (at most 30). One result per input line, in order:
-- { product_id, unit_id, qty, group_id, name, variant, image_url, unit_name, factor,
--   unit_price, weight_g, ship_policy, available, is_sellable, reason }
--   available   how many of this unit can be bought now, at most 99
--   weight_g    grams of one of this unit (the variant weight or the shop default, times factor)
--   reason      null when sellable, else 'not_found' | 'inactive' | 'unit_inactive'
create or replace function public.shop_cart_lines(p_lines jsonb) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_default int;
  v_result  jsonb;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'lines must be an array' using errcode = '22023', hint = 'invalid_lines';
  end if;
  if jsonb_array_length(p_lines) > 30 then
    raise exception 'a cart has 30 lines at most' using errcode = '22023', hint = 'cart_too_big';
  end if;

  select default_weight_g into v_default from public.shop_settings where id;
  v_default := coalesce(v_default, 500);

  with input as (
    select t.ord,
           nullif(t.x ->> 'product_id', '')::uuid as product_id,
           nullif(t.x ->> 'unit_id', '')::uuid as unit_id,
           least(greatest(coalesce(nullif(t.x ->> 'qty', '')::numeric, 1), 1), 99) as qty
    from jsonb_array_elements(p_lines) with ordinality as t(x, ord)
  ),
  stock as (
    select a.product_id, a.qty
    from public.shop_available_qty(array(select product_id from input where product_id is not null)) a
  ),
  rows as (
    select i.ord, i.product_id, i.unit_id, i.qty,
           p.id as found_id, p.group_id, p.name, p.unit as base_unit, p.is_active as product_active,
           p.track_stock, p.weight_g, p.ship_policy, p.image_url as variant_image,
           g.is_active as group_active, g.image_url as group_image,
           u.id as found_unit, u.name as unit_name, u.factor as unit_factor,
           (u.is_active and u.for_sale) as unit_ok,
           (select string_agg(v.value, ' / ' order by ga.sort_order)
            from public.product_group_attributes ga
            join public.product_variant_values pv on pv.attribute_id = ga.attribute_id and pv.product_id = p.id
            join public.product_attribute_values v on v.id = pv.value_id
            where ga.group_id = p.group_id) as variant,
           (select pi.url from public.product_images pi where pi.group_id = p.group_id
            order by pi.sort_order, pi.created_at, pi.id limit 1) as first_image,
           s.qty as stock_qty
    from input i
    left join public.products p on p.id = i.product_id
    left join public.product_groups g on g.id = p.group_id
    left join public.product_units u on u.id = i.unit_id and u.product_id = p.id
    left join stock s on s.product_id = p.id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'product_id', r.product_id,
      'unit_id', r.unit_id,
      'qty', r.qty,
      'group_id', r.group_id,
      'name', coalesce(r.name, ''),
      'variant', r.variant,
      'image_url', coalesce(r.variant_image, r.first_image, r.group_image),
      'unit_name', case when r.unit_id is null then r.base_unit else r.unit_name end,
      'factor', case when r.unit_id is null then 1 else r.unit_factor end,
      'unit_price', public.product_unit_price(r.product_id, null, r.unit_id),
      'weight_g', coalesce(r.weight_g, v_default) * case when r.unit_id is null then 1 else coalesce(r.unit_factor, 1) end,
      'ship_policy', coalesce(r.ship_policy, 'shippable'),
      'available', case
        when r.found_id is null then 0
        when not r.track_stock then 99
        else least(99, greatest(0, floor(coalesce(r.stock_qty, 0) / case when r.unit_id is null then 1 else coalesce(r.unit_factor, 1) end)))
      end,
      'is_sellable', r.found_id is not null and r.product_active and r.group_active
                     and (r.unit_id is null or coalesce(r.unit_ok, false)),
      'reason', case
        when r.found_id is null then 'not_found'
        when not (r.product_active and r.group_active) then 'inactive'
        when r.unit_id is not null and not coalesce(r.unit_ok, false) then 'unit_inactive'
        else null
      end
    ) order by r.ord
  ), '[]'::jsonb) into v_result
  from rows r;

  return v_result;
end;
$$;

revoke execute on function public.shop_cart_lines(jsonb) from public;
grant execute on function public.shop_cart_lines(jsonb) to anon, authenticated;

notify pgrst, 'reload schema';
