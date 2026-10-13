-- Spa appointments, step 1 (2/4): opening hours, spa tables and the staff list. Runs after 20261013030000_spa_schema.sql.

-- ------------------------------------------------------------ opening hours
-- Hours of one day at a branch (internal; the RPCs below use it).
create or replace function public.spa_hours(p_branch uuid, p_date date)
returns table (open_time time, close_time time, is_closed boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(h.open_time, time '08:00'),
         coalesce(h.close_time, time '20:00'),
         coalesce(h.is_closed, false)
  from (select 1) as one
  left join public.branch_hours h
    on h.branch_id = p_branch and h.weekday = extract(isodow from p_date)::int;
$$;

revoke execute on function public.spa_hours(uuid, date) from public, anon, authenticated;

-- Hours of the week for the settings screen: always 7 rows, defaults filled in.
create or replace function public.spa_week_hours(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_agg(jsonb_build_object(
      'weekday', d.weekday,
      'open_time', to_char(coalesce(h.open_time, time '08:00'), 'HH24:MI'),
      'close_time', to_char(coalesce(h.close_time, time '20:00'), 'HH24:MI'),
      'is_closed', coalesce(h.is_closed, false)
    ) order by d.weekday)
    from generate_series(1, 7) as d(weekday)
    left join public.branch_hours h on h.branch_id = p_branch and h.weekday = d.weekday
  );
end;
$$;

revoke execute on function public.spa_week_hours(uuid) from public, anon;
grant execute on function public.spa_week_hours(uuid) to authenticated;

-- p: [{ weekday, open_time: 'HH:MM', close_time: 'HH:MM', is_closed }]
create or replace function public.save_branch_hours(p_branch uuid, p jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb;
  v_closed boolean;
  v_open time;
  v_close time;
begin
  if not public.can_schedule('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  for v_row in select * from jsonb_array_elements(coalesce(p, '[]'::jsonb)) loop
    v_closed := coalesce((v_row ->> 'is_closed')::boolean, false);
    v_open := coalesce(nullif(v_row ->> 'open_time', '')::time, time '08:00');
    v_close := coalesce(nullif(v_row ->> 'close_time', '')::time, time '20:00');
    if not v_closed and v_close <= v_open then
      raise exception 'closing time must be after opening time' using errcode = '22023', hint = 'bad_hours';
    end if;
    insert into public.branch_hours (branch_id, weekday, open_time, close_time, is_closed)
    values (p_branch, (v_row ->> 'weekday')::smallint, v_open, v_close, v_closed)
    on conflict (branch_id, weekday) do update
      set open_time = excluded.open_time, close_time = excluded.close_time, is_closed = excluded.is_closed;
  end loop;
end;
$$;

revoke execute on function public.save_branch_hours(uuid, jsonb) from public, anon;
grant execute on function public.save_branch_hours(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------------ spa tables
-- p: { branch_id, name, is_active?, sort_order? }. Tables are archived (is_active), not deleted.
create or replace function public.save_spa_resource(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_id uuid;
begin
  if p_id is not null then
    select branch_id into v_branch from public.spa_resources where id = p_id;
    if v_branch is null then
      raise exception 'spa table % not found', p_id using errcode = 'P0002';
    end if;
  end if;
  if v_branch is null or not public.can_schedule('SETTING', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if p_id is null then
    insert into public.spa_resources (branch_id, name, is_active, sort_order)
    values (
      v_branch,
      btrim(p ->> 'name'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce((p ->> 'sort_order')::int, 0)
    )
    returning id into v_id;
  else
    update public.spa_resources set
      name = coalesce(nullif(btrim(p ->> 'name'), ''), name),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce((p ->> 'sort_order')::int, sort_order)
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

revoke execute on function public.save_spa_resource(jsonb, uuid) from public, anon;
grant execute on function public.save_spa_resource(jsonb, uuid) to authenticated;

-- ---------------------------------------------------------------- spa staff
-- Staff at a branch with whether they do services. Anyone who may view the schedule can read it
-- (the booking dialog picks from the ones with does_services).
create or replace function public.list_branch_staff(p_branch uuid)
returns table (user_id uuid, name text, role text, does_services boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
    select sb.user_id, public.staff_display_name(sb.user_id), sb.role, sb.does_services
    from public.staff_branches sb
    where sb.branch_id = p_branch
    order by 2;
end;
$$;

revoke execute on function public.list_branch_staff(uuid) from public, anon;
grant execute on function public.list_branch_staff(uuid) to authenticated;

create or replace function public.set_staff_does_services(p_user uuid, p_branch uuid, p_value boolean) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_schedule('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.staff_branches set does_services = p_value
  where user_id = p_user and branch_id = p_branch;
  if not found then
    raise exception 'staff member is not assigned to this branch' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.set_staff_does_services(uuid, uuid, boolean) from public, anon;
grant execute on function public.set_staff_does_services(uuid, uuid, boolean) to authenticated;

