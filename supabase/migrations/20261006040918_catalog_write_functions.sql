-- Atomic multi-table writes for the catalog. SECURITY INVOKER (the default):
-- every statement runs as the caller, so the admin-only RLS policies still
-- apply and a non-admin gets a permission error instead of a silent write.
-- Doing this in one function means a failed join-table insert rolls the whole
-- save back (the Firestore version wrote documents one by one).

create function public.save_pet_service(p_id uuid, p jsonb) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_id is null then
    insert into public.pet_services
      (name, description, type, unit, general_price, duration_minutes, is_show)
    values (
      p ->> 'name',
      nullif(p ->> 'description', ''),
      nullif(p ->> 'type', ''),
      nullif(p ->> 'unit', ''),
      nullif(p ->> 'general_price', '')::numeric,
      nullif(p ->> 'duration_minutes', '')::int,
      coalesce((p ->> 'is_show')::boolean, true)
    )
    returning id into v_id;
  else
    update public.pet_services set
      name             = p ->> 'name',
      description      = nullif(p ->> 'description', ''),
      type             = nullif(p ->> 'type', ''),
      unit             = nullif(p ->> 'unit', ''),
      general_price    = nullif(p ->> 'general_price', '')::numeric,
      duration_minutes = nullif(p ->> 'duration_minutes', '')::int,
      is_show          = coalesce((p ->> 'is_show')::boolean, true)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'pet service % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  delete from public.pet_service_pets where service_id = v_id;
  insert into public.pet_service_pets (service_id, pet_id)
  select v_id, x::uuid
  from jsonb_array_elements_text(coalesce(p -> 'pet_ids', '[]'::jsonb)) as t(x);

  return v_id;
end;
$$;

create function public.save_pet_combo(p_id uuid, p jsonb) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_id is null then
    insert into public.pet_service_combos
      (name, description, origin_price, price, duration_minutes, mark_as_id,
       mark_start, mark_end, status)
    values (
      p ->> 'name',
      nullif(p ->> 'description', ''),
      nullif(p ->> 'origin_price', '')::numeric,
      nullif(p ->> 'price', '')::numeric,
      nullif(p ->> 'duration_minutes', '')::int,
      nullif(p ->> 'mark_as_id', ''),
      nullif(p ->> 'mark_start', '')::timestamptz,
      nullif(p ->> 'mark_end', '')::timestamptz,
      coalesce(nullif(p ->> 'status', '')::smallint, 1)
    )
    returning id into v_id;
  else
    update public.pet_service_combos set
      name             = p ->> 'name',
      description      = nullif(p ->> 'description', ''),
      origin_price     = nullif(p ->> 'origin_price', '')::numeric,
      price            = nullif(p ->> 'price', '')::numeric,
      duration_minutes = nullif(p ->> 'duration_minutes', '')::int,
      mark_as_id       = nullif(p ->> 'mark_as_id', ''),
      mark_start       = nullif(p ->> 'mark_start', '')::timestamptz,
      mark_end         = nullif(p ->> 'mark_end', '')::timestamptz,
      status           = coalesce(nullif(p ->> 'status', '')::smallint, 1)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'combo % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  delete from public.combo_pets where combo_id = v_id;
  insert into public.combo_pets (combo_id, pet_id)
  select v_id, x::uuid
  from jsonb_array_elements_text(coalesce(p -> 'pet_ids', '[]'::jsonb)) as t(x);

  delete from public.combo_services where combo_id = v_id;
  insert into public.combo_services (combo_id, service_id)
  select v_id, x::uuid
  from jsonb_array_elements_text(coalesce(p -> 'service_ids', '[]'::jsonb)) as t(x);

  return v_id;
end;
$$;

-- p_rows: [{ "weight_id": "lessthan2", "price": 120000 }, ...]
-- A row with an empty price means "no price for this weight" and removes it.
create function public.save_service_prices(p_pet_id uuid, p_service_id uuid, p_rows jsonb)
returns void
language plpgsql
set search_path = ''
as $$
begin
  delete from public.pet_service_prices
  where pet_id = p_pet_id
    and service_id = p_service_id
    and weight_id not in (
      select r.v ->> 'weight_id'
      from jsonb_array_elements(p_rows) as r(v)
      where nullif(r.v ->> 'price', '') is not null
    );

  insert into public.pet_service_prices (pet_id, service_id, weight_id, price)
  select p_pet_id, p_service_id, r.v ->> 'weight_id', (r.v ->> 'price')::numeric
  from jsonb_array_elements(p_rows) as r(v)
  where nullif(r.v ->> 'price', '') is not null
  on conflict (pet_id, service_id, weight_id) do update set price = excluded.price;
end;
$$;

revoke execute on function public.save_pet_service(uuid, jsonb) from public, anon;
revoke execute on function public.save_pet_combo(uuid, jsonb) from public, anon;
revoke execute on function public.save_service_prices(uuid, uuid, jsonb) from public, anon;
grant execute on function public.save_pet_service(uuid, jsonb) to authenticated;
grant execute on function public.save_pet_combo(uuid, jsonb) to authenticated;
grant execute on function public.save_service_prices(uuid, uuid, jsonb) to authenticated;
