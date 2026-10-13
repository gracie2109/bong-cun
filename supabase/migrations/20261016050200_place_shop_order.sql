-- Shop checkout, step 5 (3/4): place_shop_order (docs/checkout-shop.md, section 5.3).
-- Safe to run more than once.
--
-- Runs with the rights of the function, but every check is about the signed-in shopper. The
-- browser sends what the shopper chose; the database reads the price, the stock and the address
-- itself. p:
--   { client_ref, delivery_method: 'delivery' | 'pickup', address_id?, receiver?: { name, phone },
--     lines: [{ product_id, unit_id?, qty }], shipping_fee_quote?, note? }
-- Returns { id, code, total, replayed }. Failures carry errcode 22023 and a hint the client turns
-- into a message; `detail` names the products when it matters.

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
    where pr.id = r.product_id and pr.is_active and g.is_active;
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

revoke execute on function public.place_shop_order(jsonb) from public, anon;
grant execute on function public.place_shop_order(jsonb) to authenticated;

notify pgrst, 'reload schema';
