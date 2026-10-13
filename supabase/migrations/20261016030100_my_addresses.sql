-- Shop checkout, step 3 (2/2): address book RPCs and my_customer_id
-- (docs/checkout-shop.md, section 5.2). Safe to run more than once.
--
-- All of them are security definer and filter on auth.uid(), so a shopper only ever touches
-- their own addresses. An address is returned as
-- { id, receiver_name, phone, street, province_name, district_name, ward_name, ghn_province_id,
--   ghn_district_id, ghn_ward_code, is_default }.

-- The customer record linked to the signed-in account, or null (used when an order is placed).
create or replace function public.my_customer_id() returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.customers where user_id = (select auth.uid());
$$;

revoke execute on function public.my_customer_id() from public, anon;
grant execute on function public.my_customer_id() to authenticated;

create or replace function public.address_json(a public.customer_addresses) returns jsonb
language sql
immutable
set search_path = ''
as $$
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
    'is_default', a.is_default
  );
$$;

revoke execute on function public.address_json(public.customer_addresses) from public, anon, authenticated;

-- The signed-in shopper's addresses, the default first.
create or replace function public.my_addresses() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(public.address_json(a) order by a.is_default desc, a.created_at desc, a.id)
    from public.customer_addresses a
    where a.user_id = v_uid
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.my_addresses() from public, anon;
grant execute on function public.my_addresses() to authenticated;

-- Adds an address (p.id empty) or edits one of the caller's. p: { id?, receiver_name, phone,
-- street, province_name, district_name, ward_name, ghn_province_id, ghn_district_id,
-- ghn_ward_code, is_default? }. The first address is always the default; p.is_default = true
-- moves the default here. Returns the saved address.
create or replace function public.save_my_address(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  if v_prov = '' or v_dist = '' or v_ward = '' or v_prov_id is null or v_dist_id is null or v_ward_cd = '' then
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
      ghn_province_id, ghn_district_id, ghn_ward_code, is_default
    ) values (
      v_uid, v_name, v_phone, v_street, v_prov, v_dist, v_ward, v_prov_id, v_dist_id, v_ward_cd, v_default
    )
    returning * into v_row;
  else
    update public.customer_addresses
    set receiver_name = v_name, phone = v_phone, street = v_street,
        province_name = v_prov, district_name = v_dist, ward_name = v_ward,
        ghn_province_id = v_prov_id, ghn_district_id = v_dist_id, ghn_ward_code = v_ward_cd,
        is_default = v_default
    where id = v_id and user_id = v_uid
    returning * into v_row;
  end if;

  return public.address_json(v_row);
end;
$$;

revoke execute on function public.save_my_address(jsonb) from public, anon;
grant execute on function public.save_my_address(jsonb) to authenticated;

-- Makes one of the caller's addresses the default.
create or replace function public.set_default_my_address(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('customer_addresses:' || v_uid::text, 0));
  if not exists (select 1 from public.customer_addresses where id = p_id and user_id = v_uid) then
    raise exception 'address not found' using errcode = 'P0002', hint = 'address_not_found';
  end if;
  update public.customer_addresses set is_default = false where user_id = v_uid and is_default and id <> p_id;
  update public.customer_addresses set is_default = true where id = p_id and user_id = v_uid;
end;
$$;

revoke execute on function public.set_default_my_address(uuid) from public, anon;
grant execute on function public.set_default_my_address(uuid) to authenticated;

-- Deletes one of the caller's addresses; when it was the default, the newest remaining one
-- becomes the default.
create or replace function public.delete_my_address(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := (select auth.uid());
  v_default boolean;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('customer_addresses:' || v_uid::text, 0));
  delete from public.customer_addresses where id = p_id and user_id = v_uid returning is_default into v_default;
  if not found then
    raise exception 'address not found' using errcode = 'P0002', hint = 'address_not_found';
  end if;
  if v_default then
    update public.customer_addresses set is_default = true
    where id = (
      select id from public.customer_addresses where user_id = v_uid order by created_at desc, id limit 1
    );
  end if;
end;
$$;

revoke execute on function public.delete_my_address(uuid) from public, anon;
grant execute on function public.delete_my_address(uuid) to authenticated;

notify pgrst, 'reload schema';
