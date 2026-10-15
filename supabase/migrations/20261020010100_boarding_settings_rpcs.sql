-- Pet hotel (boarding), step 1 (2/2): RPCs for the settings screen
-- (docs/khach-san-thu-cung.md, section 6). Runs after 20261020010000_boarding_schema.sql.
-- Safe to run more than once.
--
-- Refusals carry a `hint` the screen turns into text: duplicate_name, duplicate_code, no_price,
-- bad_input, bad_rules, not_found.

-- --------------------------------------------------------------------- prices
-- Price per night of a kennel type at a branch: the branch's own price first, then the shared one.
create or replace function public.kennel_night_price(p_type uuid, p_branch uuid) returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select p.night_price
  from public.kennel_type_prices p
  where p.kennel_type_id = p_type and (p.branch_id = p_branch or p.branch_id is null)
  order by (p.branch_id is null)
  limit 1;
$$;

-- Price per night for each further pet sharing the kennel; falls back to the normal price.
create or replace function public.kennel_extra_pet_price(p_type uuid, p_branch uuid) returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(p.extra_pet_night_price, p.night_price)
  from public.kennel_type_prices p
  where p.kennel_type_id = p_type and (p.branch_id = p_branch or p.branch_id is null)
  order by (p.branch_id is null)
  limit 1;
$$;

revoke execute on function public.kennel_night_price(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.kennel_extra_pet_price(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- kennel types
-- p: { name, description?, photo_url?, species_ids?, max_weight_kg?, max_pets?, purpose?,
--      is_active?, is_public?, sort_order?,
--      night_price, extra_pet_night_price?          -- the shared price
--      branch_prices?: [{ branch_id, night_price, extra_pet_night_price? }] }
-- On update a missing field keeps its value (a null max_weight_kg clears it). branch_prices,
-- when given, replaces the branch prices of the branches the caller may set up.
create or replace function public.save_kennel_type(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
  v_name text := nullif(btrim(p ->> 'name'), '');
  v_species uuid[];
  v_row jsonb;
  v_branch uuid;
  v_kept uuid[] := '{}';
begin
  if not public.can_boarding('SETTING') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and v_name is null then
    raise exception 'name is required' using errcode = '22023', hint = 'bad_input';
  end if;
  if p_id is not null and not exists (select 1 from public.kennel_types where id = p_id) then
    raise exception 'kennel type % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_name is not null and exists (
    select 1 from public.kennel_types
    where lower(btrim(name)) = lower(v_name) and id is distinct from p_id
  ) then
    raise exception 'a kennel type with this name exists' using errcode = '23505', hint = 'duplicate_name';
  end if;

  if p ? 'species_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_species
    from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);
  end if;

  if p_id is null then
    insert into public.kennel_types (
      name, description, photo_url, species_ids, max_weight_kg, max_pets, purpose, is_active, is_public, sort_order
    ) values (
      v_name,
      nullif(btrim(p ->> 'description'), ''),
      nullif(btrim(p ->> 'photo_url'), ''),
      coalesce(v_species, '{}'),
      nullif(p ->> 'max_weight_kg', '')::numeric,
      coalesce(nullif(p ->> 'max_pets', '')::int, 1),
      coalesce(nullif(p ->> 'purpose', ''), 'boarding'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce((p ->> 'is_public')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.kennel_types set
      name = coalesce(v_name, name),
      description = case when p ? 'description' then nullif(btrim(p ->> 'description'), '') else description end,
      photo_url = case when p ? 'photo_url' then nullif(btrim(p ->> 'photo_url'), '') else photo_url end,
      species_ids = coalesce(v_species, species_ids),
      max_weight_kg = case when p ? 'max_weight_kg' then nullif(p ->> 'max_weight_kg', '')::numeric else max_weight_kg end,
      max_pets = coalesce(nullif(p ->> 'max_pets', '')::int, max_pets),
      purpose = coalesce(nullif(p ->> 'purpose', ''), purpose),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      is_public = coalesce((p ->> 'is_public')::boolean, is_public),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id;
  end if;

  -- The shared price is required once; afterwards only changed when sent.
  if p ? 'night_price' then
    if nullif(p ->> 'night_price', '') is null then
      raise exception 'night price is required' using errcode = '22023', hint = 'no_price';
    end if;
    insert into public.kennel_type_prices (kennel_type_id, branch_id, night_price, extra_pet_night_price)
    values (v_id, null, (p ->> 'night_price')::numeric, nullif(p ->> 'extra_pet_night_price', '')::numeric)
    on conflict on constraint kennel_type_prices_key do update
      set night_price = excluded.night_price, extra_pet_night_price = excluded.extra_pet_night_price;
  elsif p_id is null then
    raise exception 'night price is required' using errcode = '22023', hint = 'no_price';
  end if;

  if p ? 'branch_prices' then
    for v_row in select * from jsonb_array_elements(coalesce(p -> 'branch_prices', '[]'::jsonb)) loop
      v_branch := nullif(v_row ->> 'branch_id', '')::uuid;
      if v_branch is null or not public.can_boarding('SETTING', v_branch) then
        raise exception 'not allowed' using errcode = '42501';
      end if;
      if nullif(v_row ->> 'night_price', '') is null then
        raise exception 'night price is required' using errcode = '22023', hint = 'no_price';
      end if;
      insert into public.kennel_type_prices (kennel_type_id, branch_id, night_price, extra_pet_night_price)
      values (v_id, v_branch, (v_row ->> 'night_price')::numeric, nullif(v_row ->> 'extra_pet_night_price', '')::numeric)
      on conflict on constraint kennel_type_prices_key do update
        set night_price = excluded.night_price, extra_pet_night_price = excluded.extra_pet_night_price;
      v_kept := v_kept || v_branch;
    end loop;
    -- A branch left out of the list goes back to the shared price.
    delete from public.kennel_type_prices
    where kennel_type_id = v_id
      and branch_id is not null
      and branch_id <> all (v_kept)
      and public.can_boarding('SETTING', branch_id);
  end if;

  return v_id;
end;
$$;

revoke execute on function public.save_kennel_type(jsonb, uuid) from public, anon;
grant execute on function public.save_kennel_type(jsonb, uuid) to authenticated;

-- One page: { total, rows: [{ id, name, description, photo_url, species_ids, species_names,
-- max_weight_kg, max_pets, purpose, is_active, is_public, sort_order, night_price,
-- extra_pet_night_price, has_branch_price, shared_night_price, shared_extra_pet_night_price,
-- branch_prices: [{ branch_id, branch_name, night_price, extra_pet_night_price }], kennel_count }] }.
-- night_price is the price that applies at p_branch. Search matches the name, accents ignored.
create or replace function public.list_kennel_types(
  p_branch      uuid,
  p_search      text default null,
  p_page        int default 1,
  p_page_size   int default 20,
  p_active_only boolean default false
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select k.*
    from public.kennel_types k
    where (not p_active_only or k.is_active)
      and (v_term = '' or lower(public.immutable_unaccent(k.name)) like v_like)
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', k.id,
        'name', k.name,
        'description', k.description,
        'photo_url', k.photo_url,
        'species_ids', to_jsonb(k.species_ids),
        'species_names', coalesce((
          select jsonb_agg(s.name order by s.name) from public.species s where s.id = any (k.species_ids)
        ), '[]'::jsonb),
        'max_weight_kg', k.max_weight_kg,
        'max_pets', k.max_pets,
        'purpose', k.purpose,
        'is_active', k.is_active,
        'is_public', k.is_public,
        'sort_order', k.sort_order,
        'night_price', public.kennel_night_price(k.id, p_branch),
        'extra_pet_night_price', public.kennel_extra_pet_price(k.id, p_branch),
        'has_branch_price', exists (
          select 1 from public.kennel_type_prices p where p.kennel_type_id = k.id and p.branch_id = p_branch
        ),
        'shared_night_price', (
          select p.night_price from public.kennel_type_prices p where p.kennel_type_id = k.id and p.branch_id is null
        ),
        'shared_extra_pet_night_price', (
          select p.extra_pet_night_price from public.kennel_type_prices p where p.kennel_type_id = k.id and p.branch_id is null
        ),
        'branch_prices', coalesce((
          select jsonb_agg(jsonb_build_object(
            'branch_id', p.branch_id,
            'branch_name', b.name,
            'night_price', p.night_price,
            'extra_pet_night_price', p.extra_pet_night_price
          ) order by b.name)
          from public.kennel_type_prices p join public.branches b on b.id = p.branch_id
          where p.kennel_type_id = k.id
        ), '[]'::jsonb),
        'kennel_count', (
          select count(*) from public.kennels n where n.kennel_type_id = k.id and n.branch_id = p_branch
        )
      ) order by k.sort_order, lower(k.name), k.id)
      from (select * from f order by sort_order, lower(name), id limit v_size offset v_offset) k
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function public.list_kennel_types(uuid, text, int, int, boolean) from public, anon;
grant execute on function public.list_kennel_types(uuid, text, int, int, boolean) to authenticated;

-- --------------------------------------------------------------------- kennels
-- p: { branch_id, kennel_type_id, code, name?, status?, is_active?, sort_order? }.
-- Kennels are switched off (is_active), not deleted: past stays keep pointing at them.
create or replace function public.save_kennel(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_code text := nullif(btrim(p ->> 'code'), '');
  v_type uuid := nullif(p ->> 'kennel_type_id', '')::uuid;
  v_id uuid;
begin
  if p_id is not null then
    select branch_id into v_branch from public.kennels where id = p_id;
    if v_branch is null then
      raise exception 'kennel % not found', p_id using errcode = 'P0002', hint = 'not_found';
    end if;
  end if;
  if v_branch is null or not public.can_boarding('SETTING', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and (v_code is null or v_type is null) then
    raise exception 'code and kennel type are required' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_type is not null and not exists (select 1 from public.kennel_types where id = v_type) then
    raise exception 'kennel type not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_code is not null and exists (
    select 1 from public.kennels
    where branch_id = v_branch and lower(btrim(code)) = lower(v_code) and id is distinct from p_id
  ) then
    raise exception 'a kennel with this code exists at the branch' using errcode = '23505', hint = 'duplicate_code';
  end if;

  if p_id is null then
    insert into public.kennels (branch_id, kennel_type_id, code, name, status, is_active, sort_order)
    values (
      v_branch, v_type, v_code,
      nullif(btrim(p ->> 'name'), ''),
      coalesce(nullif(p ->> 'status', ''), 'ready'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.kennels set
      kennel_type_id = coalesce(v_type, kennel_type_id),
      code = coalesce(v_code, code),
      name = case when p ? 'name' then nullif(btrim(p ->> 'name'), '') else name end,
      status = coalesce(nullif(p ->> 'status', ''), status),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

revoke execute on function public.save_kennel(jsonb, uuid) from public, anon;
grant execute on function public.save_kennel(jsonb, uuid) to authenticated;

-- One page: { total, rows: [{ id, branch_id, kennel_type_id, kennel_type_name, code, name,
-- status, is_active, sort_order }] }. Search matches the code, name or type, accents ignored.
create or replace function public.list_kennels(
  p_branch    uuid,
  p_search    text default null,
  p_type      uuid default null,
  p_page      int default 1,
  p_page_size int default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select n.*, t.name as type_name, t.sort_order as type_sort
    from public.kennels n
    join public.kennel_types t on t.id = n.kennel_type_id
    where n.branch_id = p_branch
      and (p_type is null or n.kennel_type_id = p_type)
      and (
        v_term = ''
        or lower(public.immutable_unaccent(n.code)) like v_like
        or lower(public.immutable_unaccent(coalesce(n.name, ''))) like v_like
        or lower(public.immutable_unaccent(t.name)) like v_like
      )
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', k.id,
        'branch_id', k.branch_id,
        'kennel_type_id', k.kennel_type_id,
        'kennel_type_name', k.type_name,
        'code', k.code,
        'name', k.name,
        'status', k.status,
        'is_active', k.is_active,
        'sort_order', k.sort_order
      ) order by k.type_sort, lower(k.type_name), k.sort_order, lower(k.code), k.id)
      from (
        select * from f order by type_sort, lower(type_name), sort_order, lower(code), id
        limit v_size offset v_offset
      ) k
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function public.list_kennels(uuid, text, uuid, int, int) from public, anon;
grant execute on function public.list_kennels(uuid, text, uuid, int, int) to authenticated;

-- ready / cleaning / maintenance. Needs "boarding: UPDATE" (the "Đã dọn" button of the board).
create or replace function public.set_kennel_status(p_id uuid, p_status text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  if p_status is null or p_status not in ('ready', 'cleaning', 'maintenance') then
    raise exception 'bad status' using errcode = '22023', hint = 'bad_input';
  end if;
  select branch_id into v_branch from public.kennels where id = p_id;
  if v_branch is null then
    raise exception 'kennel % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.kennels set status = p_status where id = p_id;
end;
$$;

revoke execute on function public.set_kennel_status(uuid, text) from public, anon;
grant execute on function public.set_kennel_status(uuid, text) to authenticated;

-- --------------------------------------------------------------------- rules
-- { check_in_from, check_out_by, late_half_until: 'HH:MM', max_nights, day_stay_nights }.
-- A branch without a row gets the defaults (08:00, 12:00, 18:00, 30 nights, 1 night).
create or replace function public.boarding_settings_get(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'check_in_from', to_char(coalesce(s.check_in_from, time '08:00'), 'HH24:MI'),
      'check_out_by', to_char(coalesce(s.check_out_by, time '12:00'), 'HH24:MI'),
      'late_half_until', to_char(coalesce(s.late_half_until, time '18:00'), 'HH24:MI'),
      'max_nights', coalesce(s.max_nights, 30),
      'day_stay_nights', coalesce(s.day_stay_nights, 1)
    )
    from (select 1) as one
    left join public.boarding_settings s on s.branch_id = p_branch
  );
end;
$$;

revoke execute on function public.boarding_settings_get(uuid) from public, anon;
grant execute on function public.boarding_settings_get(uuid) to authenticated;

create or replace function public.save_boarding_settings(p_branch uuid, p jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_in time := coalesce(nullif(p ->> 'check_in_from', '')::time, time '08:00');
  v_out time := coalesce(nullif(p ->> 'check_out_by', '')::time, time '12:00');
  v_late time := coalesce(nullif(p ->> 'late_half_until', '')::time, time '18:00');
  v_nights int := coalesce(nullif(p ->> 'max_nights', '')::int, 30);
  v_day numeric := coalesce(nullif(p ->> 'day_stay_nights', '')::numeric, 1);
begin
  if not public.can_boarding('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_out >= v_late or v_nights < 1 or v_nights > 365 or v_day not in (0.5, 1) then
    raise exception 'invalid boarding rules' using errcode = '22023', hint = 'bad_rules';
  end if;
  insert into public.boarding_settings (branch_id, check_in_from, check_out_by, late_half_until, max_nights, day_stay_nights)
  values (p_branch, v_in, v_out, v_late, v_nights, v_day)
  on conflict (branch_id) do update set
    check_in_from = excluded.check_in_from,
    check_out_by = excluded.check_out_by,
    late_half_until = excluded.late_half_until,
    max_nights = excluded.max_nights,
    day_stay_nights = excluded.day_stay_nights;
end;
$$;

revoke execute on function public.save_boarding_settings(uuid, jsonb) from public, anon;
grant execute on function public.save_boarding_settings(uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
