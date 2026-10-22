-- Two-level addresses (province and commune from the location cache) next to the GHN three-level ones.
--
--  customer_addresses, shop_orders and shop_settings gain the columns for the new address; the GHN columns of
--  an address become optional, guarded by checks so every address has one complete form or the other. Old
--  addresses and orders are not touched (location_model stays 'ghn_legacy', no GHN code is converted).
--  save_my_address, place_shop_order, the order JSON functions and the shop settings functions are
--  their current definitions with only the address parts changed. The old payload of save_my_address
--  (GHN ids, no ward_location_code) still works for apps that are not updated.
--  Safe to run more than once.

alter table public.customer_addresses
  add column if not exists location_model text not null default 'ghn_legacy',
  add column if not exists province_location_code text references public.location_units (code),
  add column if not exists ward_location_code text references public.location_units (code),
  add column if not exists province_official_code text,
  add column if not exists ward_official_code text;

alter table public.customer_addresses
  alter column district_name drop not null,
  alter column ghn_province_id drop not null,
  alter column ghn_district_id drop not null,
  alter column ghn_ward_code drop not null;

alter table public.customer_addresses drop constraint if exists customer_addresses_location_model_check;
alter table public.customer_addresses add constraint customer_addresses_location_model_check
  check (location_model in ('ghn_legacy', 'vn_2025'));
alter table public.customer_addresses drop constraint if exists customer_addresses_location_fields_check;
alter table public.customer_addresses add constraint customer_addresses_location_fields_check check (
  (location_model = 'ghn_legacy' and district_name is not null and ghn_province_id is not null
     and ghn_district_id is not null and ghn_ward_code is not null)
  or (location_model = 'vn_2025' and ward_location_code is not null and province_location_code is not null));

alter table public.shop_orders
  add column if not exists ship_location_model text,
  add column if not exists ship_ward_location_code text,
  add column if not exists ship_province_location_code text,
  add column if not exists ship_ward_official_code text,
  add column if not exists ship_province_official_code text;

alter table public.shop_orders drop constraint if exists shop_orders_location_model_check;
alter table public.shop_orders add constraint shop_orders_location_model_check
  check (ship_location_model is null or ship_location_model in ('ghn_legacy', 'vn_2025'));
-- A delivery order has a place to send to: a GHN district and ward, or a commune of the new address.
alter table public.shop_orders drop constraint if exists shop_orders_delivery_target_check;
alter table public.shop_orders add constraint shop_orders_delivery_target_check check (
  (delivery_method = 'delivery')
  = ((ghn_district_id is not null and ghn_ward_code is not null) or ship_ward_location_code is not null)) not valid;
alter table public.shop_orders validate constraint shop_orders_delivery_target_check;
alter table public.shop_orders drop constraint if exists shop_orders_check;

alter table public.shop_settings
  add column if not exists from_ward_location_code text references public.location_units (code),
  add column if not exists from_street text;

create or replace function "public"."address_json"("a" "public"."customer_addresses") RETURNS "jsonb"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', a.id,
    'receiver_name', a.receiver_name,
    'phone', a.phone,
    'street', a.street,
    'province_name', a.province_name,
    'district_name', a.district_name,
    'ward_name', a.ward_name,
    'ghn_province_id', a.ghn_province_id,
    'ghn_district_id', a.ghn_district_id,
    'ghn_ward_code', a.ghn_ward_code,
    'is_default', a.is_default,
    'location_model', a.location_model,
    'province_location_code', a.province_location_code,
    'ward_location_code', a.ward_location_code,
    'province_official_code', a.province_official_code,
    'ward_official_code', a.ward_official_code
  );
$$;

create or replace function "public"."save_my_address"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid     uuid := (select auth.uid());
  v_id      uuid := nullif(p ->> 'id', '')::uuid;
  v_name    text := btrim(coalesce(p ->> 'receiver_name', ''));
  v_phone   text := btrim(coalesce(p ->> 'phone', ''));
  v_street  text := btrim(coalesce(p ->> 'street', ''));
  v_prov    text := btrim(coalesce(p ->> 'province_name', ''));
  v_dist    text := btrim(coalesce(p ->> 'district_name', ''));
  v_ward    text := btrim(coalesce(p ->> 'ward_name', ''));
  v_prov_id int := nullif(p ->> 'ghn_province_id', '')::int;
  v_dist_id int := nullif(p ->> 'ghn_district_id', '')::int;
  v_ward_cd text := btrim(coalesce(p ->> 'ghn_ward_code', ''));
  v_ward_loc text := nullif(btrim(coalesce(p ->> 'ward_location_code', '')), '');
  v_model   text := 'ghn_legacy';
  v_ward_u  public.location_units;
  v_prov_u  public.location_units;
  v_count   int;
  v_default boolean;
  v_row     public.customer_addresses;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if v_name = '' or v_street = '' then
    raise exception 'receiver and street are required' using errcode = '22023', hint = 'address_required';
  end if;
  if length(regexp_replace(v_phone, '\D', '', 'g')) not between 8 and 15 then
    raise exception 'invalid phone number' using errcode = '22023', hint = 'invalid_phone';
  end if;
  if v_ward_loc is not null then
    -- Two-level address: the province comes from the commune, so the client sends only the commune.
    select * into v_ward_u from public.location_units where code = v_ward_loc;
    if not found then
      raise exception 'location % not found', v_ward_loc using errcode = 'P0002', hint = 'location_not_found';
    end if;
    if v_ward_u.level <> 'commune' then
      raise exception 'choose a ward or commune' using errcode = '22023', hint = 'address_location';
    end if;
    if v_ward_u.status <> 'active' then
      raise exception 'location % is no longer in force', v_ward_loc using errcode = '22023', hint = 'location_inactive';
    end if;
    select * into v_prov_u from public.location_units where code = v_ward_u.parent_code;
    v_model := 'vn_2025';
    v_prov := v_prov_u.full_name;
    v_ward := v_ward_u.full_name;
    v_dist := null;
    v_prov_id := null;
    v_dist_id := null;
    v_ward_cd := null;
  elsif v_prov = '' or v_dist = '' or v_ward = '' or v_prov_id is null or v_dist_id is null or v_ward_cd = '' then
    raise exception 'choose province, district and ward' using errcode = '22023', hint = 'address_location';
  end if;

  -- One writer at a time per account keeps the 10-address limit and the single default exact.
  perform pg_advisory_xact_lock(hashtextextended('customer_addresses:' || v_uid::text, 0));

  select count(*) into v_count from public.customer_addresses where user_id = v_uid;
  if v_id is null and v_count >= 10 then
    raise exception 'an account keeps 10 addresses at most' using errcode = '22023', hint = 'address_limit';
  end if;

  if v_id is null then
    v_default := coalesce((p ->> 'is_default')::boolean, false) or v_count = 0;
  else
    select is_default into v_default from public.customer_addresses where id = v_id and user_id = v_uid;
    if not found then
      raise exception 'address not found' using errcode = 'P0002', hint = 'address_not_found';
    end if;
    v_default := v_default or coalesce((p ->> 'is_default')::boolean, false);
  end if;

  if v_default then
    update public.customer_addresses set is_default = false
    where user_id = v_uid and is_default and id is distinct from v_id;
  end if;

  if v_id is null then
    insert into public.customer_addresses (
      user_id, receiver_name, phone, street, province_name, district_name, ward_name,
      ghn_province_id, ghn_district_id, ghn_ward_code, is_default,
      location_model, province_location_code, ward_location_code, province_official_code, ward_official_code
    ) values (
      v_uid, v_name, v_phone, v_street, v_prov, v_dist, v_ward, v_prov_id, v_dist_id, v_ward_cd, v_default,
      v_model, v_prov_u.code, v_ward_u.code, v_prov_u.official_code, v_ward_u.official_code
    )
    returning * into v_row;
  else
    update public.customer_addresses
    set receiver_name = v_name, phone = v_phone, street = v_street,
        province_name = v_prov, district_name = v_dist, ward_name = v_ward,
        ghn_province_id = v_prov_id, ghn_district_id = v_dist_id, ghn_ward_code = v_ward_cd,
        is_default = v_default,
        location_model = v_model, province_location_code = v_prov_u.code, ward_location_code = v_ward_u.code,
        province_official_code = v_prov_u.official_code, ward_official_code = v_ward_u.official_code
    where id = v_id and user_id = v_uid
    returning * into v_row;
  end if;

  return public.address_json(v_row);
end;
$$;

create or replace function "public"."place_shop_order"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
      ghn_district_id, ghn_ward_code, ship_location_model, ship_ward_location_code, ship_province_location_code,
      ship_ward_official_code, ship_province_official_code,
      weight_g, subtotal, shipping_fee_quote, total, customer_note, client_ref
    ) values (
      v_code, v_s.online_branch_id, v_uid, v_customer, v_method,
      case when v_method = 'delivery' then 'cod' else 'pay_at_store' end,
      v_name, v_phone, v_addr.street, v_addr.ward_name, v_addr.district_name, v_addr.province_name,
      v_addr.ghn_district_id, v_addr.ghn_ward_code, case when v_method = 'delivery' then v_addr.location_model end,
      v_addr.ward_location_code, v_addr.province_location_code, v_addr.ward_official_code, v_addr.province_official_code,
      v_weight, v_subtotal, v_quote, v_subtotal + v_quote,
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

create or replace function "public"."my_shop_order_json"("o" "public"."shop_orders") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    'ship_location_model', coalesce(o.ship_location_model, case when o.delivery_method = 'delivery' then 'ghn_legacy' end),
    'ship_ward_location_code', o.ship_ward_location_code,
    'ship_province_location_code', o.ship_province_location_code,
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

create or replace function "public"."staff_shop_order_json"("o" "public"."shop_orders") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    'ship_location_model', coalesce(o.ship_location_model, case when o.delivery_method = 'delivery' then 'ghn_legacy' end),
    'ship_ward_location_code', o.ship_ward_location_code,
    'ship_province_location_code', o.ship_province_location_code,
    'ship_ward_official_code', o.ship_ward_official_code,
    'ship_province_official_code', o.ship_province_official_code,
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

create or replace function "public"."shop_public_settings"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce((
    select jsonb_build_object(
      'online_branch_id', s.online_branch_id,
      'allow_cod', s.allow_cod,
      'allow_pickup', s.allow_pickup,
      'cod_max', s.cod_max,
      'default_weight_g', s.default_weight_g,
      'flat_shipping_fee', s.flat_shipping_fee,
      'free_ship_from', s.free_ship_from,
      'ghn_from_district_id', s.ghn_from_district_id,
      'ghn_from_ward_code', s.ghn_from_ward_code,
      'from_ward_location_code', s.from_ward_location_code,
      'pickup_address', s.pickup_address,
      'pickup_note', s.pickup_note
    )
    from public.shop_settings s
    where s.id
  ), '{}'::jsonb);
$$;

create or replace function "public"."save_shop_settings"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cur    public.shop_settings;
  v_branch uuid;
  v_cod    numeric;
  v_weight int;
  v_flat   numeric;
  v_free   numeric;
  v_from_loc text;
  v_from_u public.location_units;
begin
  select * into v_cur from public.shop_settings where id for update;
  if not found then
    raise exception 'shop settings are missing' using errcode = 'P0002';
  end if;
  if not public.can_shop_orders('ALL', v_cur.online_branch_id) then
    raise exception 'not allowed to edit shop settings' using errcode = '42501';
  end if;

  v_branch := coalesce(nullif(p ->> 'online_branch_id', '')::uuid, v_cur.online_branch_id);
  if v_branch is distinct from v_cur.online_branch_id then
    if not exists (select 1 from public.branches where id = v_branch and is_active) then
      raise exception 'branch is not available' using errcode = '22023', hint = 'invalid_branch';
    end if;
    if not public.can_shop_orders('ALL', v_branch) then
      raise exception 'not allowed to sell online from this branch' using errcode = '42501';
    end if;
  end if;

  v_cod    := coalesce(nullif(p ->> 'cod_max', '')::numeric, v_cur.cod_max);
  v_weight := coalesce(nullif(p ->> 'default_weight_g', '')::int, v_cur.default_weight_g);
  v_flat   := coalesce(nullif(p ->> 'flat_shipping_fee', '')::numeric, v_cur.flat_shipping_fee);
  if v_cod <= 0 or v_weight <= 0 or v_flat < 0 then
    raise exception 'invalid shipping or COD limits' using errcode = '22023', hint = 'invalid_limits';
  end if;
  -- An empty or zero threshold switches free shipping off.
  v_free := case
    when p ? 'free_ship_from' then nullif(nullif(p ->> 'free_ship_from', '')::numeric, 0)
    else v_cur.free_ship_from
  end;

  -- The sending ward of the two-level address must be a commune in force.
  if p ? 'from_ward_location_code' then
    v_from_loc := nullif(btrim(p ->> 'from_ward_location_code'), '');
    if v_from_loc is not null then
      select * into v_from_u from public.location_units where code = v_from_loc;
      if not found or v_from_u.level <> 'commune' then
        raise exception 'location % not found', v_from_loc using errcode = 'P0002', hint = 'location_not_found';
      end if;
      if v_from_u.status <> 'active' then
        raise exception 'location % is no longer in force', v_from_loc using errcode = '22023', hint = 'location_inactive';
      end if;
    end if;
  end if;

  update public.shop_settings s
  set online_branch_id = v_branch,
      allow_cod = coalesce((p ->> 'allow_cod')::boolean, s.allow_cod),
      allow_pickup = coalesce((p ->> 'allow_pickup')::boolean, s.allow_pickup),
      cod_max = v_cod,
      default_weight_g = v_weight,
      flat_shipping_fee = v_flat,
      free_ship_from = v_free,
      ghn_from_province_id = case when p ? 'ghn_from_province_id'
        then nullif(p ->> 'ghn_from_province_id', '')::int else s.ghn_from_province_id end,
      ghn_from_district_id = case when p ? 'ghn_from_district_id'
        then nullif(p ->> 'ghn_from_district_id', '')::int else s.ghn_from_district_id end,
      ghn_from_ward_code = case when p ? 'ghn_from_ward_code'
        then nullif(btrim(p ->> 'ghn_from_ward_code'), '') else s.ghn_from_ward_code end,
      from_address_text = case when p ? 'from_address_text'
        then nullif(btrim(p ->> 'from_address_text'), '') else s.from_address_text end,
      from_ward_location_code = case when p ? 'from_ward_location_code' then v_from_loc else s.from_ward_location_code end,
      from_street = case when p ? 'from_street'
        then nullif(btrim(p ->> 'from_street'), '') else s.from_street end,
      pickup_address = case when p ? 'pickup_address'
        then nullif(btrim(p ->> 'pickup_address'), '') else s.pickup_address end,
      pickup_note = case when p ? 'pickup_note'
        then nullif(btrim(p ->> 'pickup_note'), '') else s.pickup_note end,
      updated_at = now()
  where s.id;

  return public.shop_admin_settings();
end;
$$;
