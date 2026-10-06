-- p_id becomes an optional trailing argument (omit it to create), so the
-- generated TypeScript types are `p_id?: string` and need no hand edits.
drop function public.save_pet_service(uuid, jsonb);
drop function public.save_pet_combo(uuid, jsonb);

create function public.save_pet_service(p jsonb, p_id uuid default null) returns uuid
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

create function public.save_pet_combo(p jsonb, p_id uuid default null) returns uuid
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

revoke execute on function public.save_pet_service(jsonb, uuid) from public, anon;
revoke execute on function public.save_pet_combo(jsonb, uuid) from public, anon;
grant execute on function public.save_pet_service(jsonb, uuid) to authenticated;
grant execute on function public.save_pet_combo(jsonb, uuid) to authenticated;
