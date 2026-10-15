-- Medical records, step 7 (3/4): medicine sold only at the clinic (docs/ho-so-benh-an.md, question 2).
-- Safe to run more than once.
--
-- Before: every active product group is listed and sold on the online shop.
-- After: a group marked "clinic only" is hidden from the shop lists and refused in the cart and at
-- checkout; the POS and the clinic are not affected. The flag is switched by set_product_group_clinic_only.
-- Copies of shop_product_groups and shop_related_groups (20261018010000), shop_cart_lines
-- (20261016020000) and place_shop_order (20261016050200), each with one more condition.

alter table public.product_groups add column if not exists clinic_only boolean not null default false;

create or replace function public.set_product_group_clinic_only(p_group uuid, p_value boolean) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_products('UPDATE') then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  update public.product_groups set clinic_only = coalesce(p_value, false) where id = p_group;
  if not found then
    raise exception 'product % not found', p_group using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.set_product_group_clinic_only(uuid, boolean) from public, anon;
grant execute on function public.set_product_group_clinic_only(uuid, boolean) to authenticated;

create or replace function public.shop_product_groups(
  p_search   text default null,
  p_category uuid default null,
  p_brand    uuid default null,
  p_sort     text default 'newest',
  p_limit    int  default 24,
  p_offset   int  default 0
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term,
           nullif(btrim(coalesce(p_search, '')), '') as code
  ), candidates as (
    select g.id, g.name, g.created_at
    from public.product_groups g, params
    where g.is_active and not g.clinic_only
      and (p_brand is null or g.brand_id = p_brand)
      and (
        p_category is null
        or g.category_id = p_category
        or g.category_id in (select id from public.product_categories where parent_id = p_category)
      )
      and (
        params.term is null
        or lower(public.immutable_unaccent(g.name)) like '%' || params.term || '%'
        or exists (
          select 1 from public.products p
          where p.group_id = g.id
            and (p.sku ilike '%' || params.code || '%' or p.barcode ilike '%' || params.code || '%')
        )
      )
  ), variants as (
    select p.id, p.group_id, p.price, p.track_stock
    from public.products p
    where p.is_active and p.group_id in (select id from candidates)
  ), stock as (
    select s.product_id, s.qty
    from public.shop_available_qty(array(select id from variants)) s
  ), matched as (
    select c.id, c.name, c.created_at,
           min(v.price) as price_min,
           bool_or(not v.track_stock or coalesce(s.qty, 0) > 0) as in_stock
    from candidates c
    join variants v on v.group_id = c.id
    left join stock s on s.product_id = v.id
    group by c.id, c.name, c.created_at
  ), ordered as (
    select m.*,
           row_number() over (
             order by
               case when p_sort = 'newest' and not m.in_stock then 1 else 0 end,
               case when p_sort = 'price_asc' then m.price_min end asc,
               case when p_sort = 'price_desc' then m.price_min end desc,
               case when p_sort = 'name' then lower(m.name) end asc,
               m.created_at desc,
               m.id
           ) as rn
    from matched m
  ), page as (
    select * from ordered
    where rn > greatest(p_offset, 0) and rn <= greatest(p_offset, 0) + greatest(p_limit, 1)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(
        public.product_group_json(page.id, false) || jsonb_build_object('in_stock', page.in_stock)
        order by page.rn
      )
      from page
    ), '[]'::jsonb)
  );
$$;

create or replace function public.shop_related_groups(p_group uuid, p_limit int default 8) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with source as (
    select category_id from public.product_groups where id = p_group
  ), picked as (
    select g.id, g.created_at
    from public.product_groups g, source
    where g.is_active and not g.clinic_only
      and g.id <> p_group
      and source.category_id is not null
      and g.category_id = source.category_id
      and exists (select 1 from public.products p where p.group_id = g.id and p.is_active)
    order by g.created_at desc, g.id
    limit greatest(least(coalesce(p_limit, 8), 24), 1)
  ), stock as (
    select s.product_id, s.qty
    from public.shop_available_qty(
      array(select p.id from public.products p where p.is_active and p.group_id in (select id from picked))
    ) s
  )
  select coalesce(jsonb_agg(
    public.product_group_json(pk.id, false) || jsonb_build_object('in_stock', coalesce((
      select bool_or(not p.track_stock or coalesce(s.qty, 0) > 0)
      from public.products p
      left join stock s on s.product_id = p.id
      where p.group_id = pk.id and p.is_active
    ), false))
    order by pk.created_at desc, pk.id
  ), '[]'::jsonb)
  from picked pk;
$$;

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
           (g.is_active and not g.clinic_only) as group_active, g.image_url as group_image,
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

create or replace function public.place_shop_order(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_ref      uuid := nullif(p ->> 'client_ref', '')::uuid;
  v_old      public.shop_orders;
  v_s        public.shop_settings;
  v_user     public.users;
  v_method   text := coalesce(p ->> 'delivery_method', '');
  v_addr     public.customer_addresses;
  v_name     text;
  v_phone    text;
  v_n        int := 0;
  r          record;
  v_prod     record;
  v_unit     public.product_units;
  v_factor   numeric;
  v_price    numeric;
  v_lines    jsonb := '[]'::jsonb;
  v_ids      uuid[] := '{}';
  v_subtotal numeric := 0;
  v_goods_g  numeric := 0;
  v_weight   int;
  v_quote    numeric;
  v_missing  text;
  v_customer uuid;
  v_id       uuid;
  v_code     text;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if v_ref is null then
    raise exception 'client_ref is required' using errcode = '22023', hint = 'client_ref_required';
  end if;

  -- A retry of the same press returns the order that press made.
  select * into v_old from public.shop_orders where client_ref = v_ref;
  if found then
    if v_old.user_id <> v_uid then
      raise exception 'client_ref is already used' using errcode = '22023', hint = 'client_ref_required';
    end if;
    return jsonb_build_object('id', v_old.id, 'code', v_old.code, 'total', v_old.total, 'replayed', true);
  end if;

  select * into v_s from public.shop_settings where id;
  if not found then
    raise exception 'shop settings are missing' using errcode = 'P0002';
  end if;
  select * into v_user from public.users where id = v_uid;

  -- --------------------------------------------------- delivery method and receiver
  if v_method not in ('delivery', 'pickup') then
    raise exception 'choose delivery or pickup' using errcode = '22023', hint = 'invalid_delivery';
  end if;
  if v_method = 'delivery' then
    if not v_s.allow_cod then
      raise exception 'delivery is switched off' using errcode = '22023', hint = 'delivery_disabled';
    end if;
    select * into v_addr from public.customer_addresses
    where id = nullif(p ->> 'address_id', '')::uuid and user_id = v_uid;
    if not found then
      raise exception 'address not found' using errcode = '22023', hint = 'address_not_found';
    end if;
    v_name := v_addr.receiver_name;
    v_phone := v_addr.phone;
  else
    if not v_s.allow_pickup then
      raise exception 'pickup is switched off' using errcode = '22023', hint = 'pickup_disabled';
    end if;
    v_name := coalesce(nullif(btrim(p #>> '{receiver,name}'), ''),
                       nullif(btrim(v_user.full_name), ''), nullif(btrim(v_user.display_name), ''), '');
    v_phone := coalesce(nullif(btrim(p #>> '{receiver,phone}'), ''), nullif(btrim(v_user.phone_number), ''), '');
    if v_name = '' then
      raise exception 'receiver name is required' using errcode = '22023', hint = 'receiver_required';
    end if;
    if length(regexp_replace(v_phone, '\D', '', 'g')) not between 8 and 15 then
      raise exception 'invalid phone number' using errcode = '22023', hint = 'invalid_phone';
    end if;
  end if;

  -- ------------------------------------------------------------------- lines
  if jsonb_typeof(p -> 'lines') <> 'array' or jsonb_array_length(p -> 'lines') = 0 then
    raise exception 'the cart is empty' using errcode = '22023', hint = 'cart_empty';
  end if;
  if jsonb_array_length(p -> 'lines') > 30 then
    raise exception 'a cart has 30 lines at most' using errcode = '22023', hint = 'cart_too_big';
  end if;

  -- The same product in the same unit twice is one line.
  for r in
    with input as (
      select nullif(t.x ->> 'product_id', '')::uuid as product_id,
             nullif(t.x ->> 'unit_id', '')::uuid as unit_id,
             coalesce(nullif(t.x ->> 'qty', '')::numeric, 0) as qty,
             t.ord
      from jsonb_array_elements(p -> 'lines') with ordinality as t(x, ord)
    )
    select product_id, unit_id, sum(qty) as qty
    from input
    group by product_id, unit_id
    order by min(ord)
  loop
    v_n := v_n + 1;
    if r.product_id is null or r.qty <> floor(r.qty) or r.qty < 1 or r.qty > 99 then
      raise exception 'invalid quantity on line %', v_n using errcode = '22023', hint = 'invalid_qty';
    end if;

    select pr.id, pr.name, pr.unit as base_unit, pr.track_stock, pr.weight_g, pr.ship_policy,
           coalesce(pr.image_url, (
             select pi.url from public.product_images pi where pi.group_id = pr.group_id
             order by pi.sort_order, pi.created_at, pi.id limit 1), g.image_url) as image_url
    into v_prod
    from public.products pr
    join public.product_groups g on g.id = pr.group_id
    where pr.id = r.product_id and pr.is_active and g.is_active and not g.clinic_only;
    if not found then
      raise exception 'a product is no longer sold' using errcode = '22023', hint = 'product_unavailable';
    end if;

    v_factor := 1;
    if r.unit_id is not null then
      select * into v_unit from public.product_units
      where id = r.unit_id and product_id = r.product_id and is_active and for_sale;
      if not found then
        raise exception '% is no longer sold in this unit', v_prod.name
          using errcode = '22023', hint = 'product_unavailable', detail = v_prod.name;
      end if;
      v_factor := v_unit.factor;
    end if;

    v_price := public.product_unit_price(r.product_id, null, r.unit_id);
    if v_price is null then
      raise exception '% has no price', v_prod.name
        using errcode = '22023', hint = 'product_unavailable', detail = v_prod.name;
    end if;
    if v_method = 'delivery' and v_prod.ship_policy = 'in_store_only' then
      raise exception '% can only be picked up in store', v_prod.name
        using errcode = '22023', hint = 'in_store_only', detail = v_prod.name;
    end if;

    v_subtotal := v_subtotal + v_price * r.qty;
    v_goods_g := v_goods_g + coalesce(v_prod.weight_g, v_s.default_weight_g) * v_factor * r.qty;
    v_ids := v_ids || r.product_id;
    v_lines := v_lines || jsonb_build_object(
      'product_id', r.product_id,
      'unit_id', r.unit_id,
      'unit_factor', v_factor,
      'name', v_prod.name,
      'unit', case when r.unit_id is null then v_prod.base_unit else v_unit.name end,
      'image_url', v_prod.image_url,
      'qty', r.qty,
      'unit_price', v_price,
      'amount', v_price * r.qty,
      'base_qty', r.qty * v_factor,
      'track_stock', v_prod.track_stock
    );
  end loop;

  -- ----------------------------------------------------------------- stock
  -- Orders placed at the same moment check their stock one after another, so the last item
  -- goes to one of them only.
  perform pg_advisory_xact_lock(hashtextextended('shop_order:' || v_s.online_branch_id::text, 0));

  select string_agg(n.name, ', ' order by n.name) into v_missing
  from (
    select (l ->> 'product_id')::uuid as product_id, min(l ->> 'name') as name,
           sum((l ->> 'base_qty')::numeric) as need
    from jsonb_array_elements(v_lines) as t(l)
    where (l ->> 'track_stock')::boolean
    group by 1
  ) n
  left join public.shop_available_qty(v_ids) a on a.product_id = n.product_id
  where n.need > coalesce(a.qty, 0);
  if v_missing is not null then
    raise exception 'not enough stock: %', v_missing using errcode = '22023', hint = 'out_of_stock', detail = v_missing;
  end if;

  -- ------------------------------------------------------- weight and shipping
  v_weight := ceil(v_goods_g)::int + 100;
  if v_method = 'delivery' and v_weight > 30000 then
    raise exception 'parcel is too heavy to deliver' using errcode = '22023', hint = 'too_heavy';
  end if;

  if v_method = 'pickup' or (v_s.free_ship_from is not null and v_subtotal >= v_s.free_ship_from) then
    v_quote := 0;
  else
    -- The browser sends the estimate it showed; it is only an estimate, kept inside a sane range.
    -- Staff fix the real fee when they confirm the order.
    v_quote := least(greatest(round(coalesce(nullif(p ->> 'shipping_fee_quote', '')::numeric, v_s.flat_shipping_fee)), 0), 500000);
  end if;

  if v_method = 'delivery' and v_subtotal + v_quote > v_s.cod_max then
    raise exception 'cash on delivery is limited to % VND', v_s.cod_max using errcode = '22023', hint = 'cod_limit';
  end if;

  -- ----------------------------------------------------- customer to bill
  -- The account's own customer; else the customer with the receiver's phone (billing only, the
  -- account is never linked to someone else's record); else a new customer linked to the account.
  select id into v_customer from public.customers where user_id = v_uid;
  if v_customer is null then
    select id into v_customer from public.customers
    where phone_digits = regexp_replace(v_phone, '\D', '', 'g');
  end if;
  if v_customer is null then
    insert into public.customers (full_name, phone, email, user_id)
    values (coalesce(nullif(btrim(v_user.full_name), ''), v_name), v_phone, v_user.email, v_uid)
    on conflict do nothing
    returning id into v_customer;
    if v_customer is null then
      select id into v_customer from public.customers
      where user_id = v_uid or phone_digits = regexp_replace(v_phone, '\D', '', 'g')
      order by (user_id = v_uid) desc nulls last limit 1;
    end if;
  end if;

  -- ------------------------------------------------------------------ order
  v_code := public.next_doc_code(v_s.online_branch_id, 'DH');
  begin
    insert into public.shop_orders (
      code, branch_id, user_id, customer_id, delivery_method, payment_method,
      receiver_name, receiver_phone, ship_street, ship_ward_name, ship_district_name, ship_province_name,
      ghn_district_id, ghn_ward_code, weight_g, subtotal, shipping_fee_quote, total, customer_note, client_ref
    ) values (
      v_code, v_s.online_branch_id, v_uid, v_customer, v_method,
      case when v_method = 'delivery' then 'cod' else 'pay_at_store' end,
      v_name, v_phone, v_addr.street, v_addr.ward_name, v_addr.district_name, v_addr.province_name,
      v_addr.ghn_district_id, v_addr.ghn_ward_code, v_weight, v_subtotal, v_quote, v_subtotal + v_quote,
      left(nullif(btrim(coalesce(p ->> 'note', '')), ''), 300), v_ref
    )
    returning id into v_id;
  exception when unique_violation then
    -- Two presses of the same button raced; the other one won.
    select * into v_old from public.shop_orders where client_ref = v_ref and user_id = v_uid;
    if not found then
      raise;
    end if;
    return jsonb_build_object('id', v_old.id, 'code', v_old.code, 'total', v_old.total, 'replayed', true);
  end;

  insert into public.shop_order_lines (
    order_id, line_no, product_id, unit_id, unit_factor, name, unit, image_url, qty, unit_price, amount
  )
  select v_id, t.ord, (t.l ->> 'product_id')::uuid, nullif(t.l ->> 'unit_id', '')::uuid,
         (t.l ->> 'unit_factor')::numeric, t.l ->> 'name', t.l ->> 'unit', t.l ->> 'image_url',
         (t.l ->> 'qty')::numeric, (t.l ->> 'unit_price')::numeric, (t.l ->> 'amount')::numeric
  from jsonb_array_elements(v_lines) with ordinality as t(l, ord);

  insert into public.shop_order_events (order_id, status, actor_id, actor_name)
  values (v_id, 'pending', v_uid, 'Khách');

  return jsonb_build_object('id', v_id, 'code', v_code, 'total', v_subtotal + v_quote, 'replayed', false);
end;
$$;

revoke execute on function public.shop_product_groups(text, uuid, uuid, text, int, int) from public;
grant execute on function public.shop_product_groups(text, uuid, uuid, text, int, int) to anon, authenticated;
revoke execute on function public.shop_related_groups(uuid, int) from public;
grant execute on function public.shop_related_groups(uuid, int) to anon, authenticated;
revoke execute on function public.shop_cart_lines(jsonb) from public;
grant execute on function public.shop_cart_lines(jsonb) to anon, authenticated;
revoke execute on function public.place_shop_order(jsonb) from public, anon;
grant execute on function public.place_shop_order(jsonb) to authenticated;

notify pgrst, 'reload schema';
