-- Shift registration step 1: weekly availability.
-- A person says "I cannot work Tuesdays" or "I prefer Saturday mornings". It is information for
-- the manager and for the registration page, never an approval flow. One pattern per person
-- (not per branch). Writes only through the RPCs below.

-- ------------------------------------------------------------------- table
create table if not exists public.staff_availability (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  weekday    smallint not null check (weekday between 1 and 7),
  kind       text not null check (kind in ('unavailable', 'preferred')),
  start_time time,
  end_time   time,
  note       text check (note is null or length(note) <= 200),
  updated_at timestamptz not null default now(),
  updated_by uuid references public.users (id) on delete set null,
  -- Whole day (both null) or a time range (both set and different; end < start crosses midnight).
  constraint staff_availability_range check (
    (start_time is null and end_time is null)
    or (start_time is not null and end_time is not null and end_time <> start_time)
  )
);
create index if not exists staff_availability_user_idx on public.staff_availability (user_id, weekday);

-- ----------------------------------------------------------------- security
-- The read policy below calls it as the signed-in user.
grant execute on function public.can_view_staff(uuid) to authenticated;

alter table public.staff_availability enable row level security;
revoke all on public.staff_availability from anon, authenticated;
grant select on public.staff_availability to authenticated;

drop policy if exists "staff availability read" on public.staff_availability;
create policy "staff availability read" on public.staff_availability
  for select to authenticated
  using ((select public.can_view_staff(user_id)));

-- ------------------------------------------------------------------ helpers
-- Validates the list a client sends: at most 21 items, each {weekday, kind, start_time?, end_time?, note?}.
create or replace function public.check_availability_items(p_items jsonb) returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_item jsonb;
  v_start time;
  v_end time;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'items must be a list' using errcode = '22023', hint = 'bad_input';
  end if;
  if jsonb_array_length(p_items) > 21 then
    raise exception 'too many availability rows' using errcode = 'P0001', hint = 'too_many';
  end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    if jsonb_typeof(v_item) <> 'object'
       or coalesce(v_item ->> 'weekday', '') !~ '^[1-7]$'
       or coalesce(v_item ->> 'kind', '') not in ('unavailable', 'preferred')
       or length(coalesce(v_item ->> 'note', '')) > 200 then
      raise exception 'invalid availability row' using errcode = '22023', hint = 'bad_input';
    end if;
    begin
      v_start := nullif(v_item ->> 'start_time', '')::time;
      v_end := nullif(v_item ->> 'end_time', '')::time;
    exception when others then
      raise exception 'invalid time' using errcode = '22023', hint = 'bad_input';
    end;
    if (v_start is null) <> (v_end is null) or v_start = v_end then
      raise exception 'invalid time range' using errcode = '22023', hint = 'bad_input';
    end if;
  end loop;
end;
$$;

-- Replaces every row of one person. The caller already passed its permission check.
create or replace function public.replace_availability(p_user uuid, p_items jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.check_availability_items(p_items);
  delete from public.staff_availability where user_id = p_user;
  insert into public.staff_availability (user_id, weekday, kind, start_time, end_time, note, updated_by)
  select p_user, (i ->> 'weekday')::smallint, i ->> 'kind',
         nullif(i ->> 'start_time', '')::time, nullif(i ->> 'end_time', '')::time,
         nullif(btrim(i ->> 'note'), ''), (select auth.uid())
  from jsonb_array_elements(p_items) i;
end;
$$;

create or replace function public.availability_rows(p_user uuid) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'weekday', a.weekday, 'kind', a.kind,
    'start_time', to_char(a.start_time, 'HH24:MI'), 'end_time', to_char(a.end_time, 'HH24:MI'),
    'note', a.note) order by a.weekday, a.start_time nulls first, a.kind), '[]'::jsonb)
  from public.staff_availability a
  where a.user_id = p_user;
$$;

-- 'unavailable' when the person blocked a day or a time range that overlaps the shift, else
-- 'preferred' when it falls in a preferred row, else null. The weekday is the one the shift starts on.
create or replace function public.availability_conflict(p_user uuid, p_start_at timestamptz, p_end_at timestamptz) returns text
language sql
stable
security definer
set search_path = ''
as $$
  with s as (select (p_start_at at time zone 'Asia/Ho_Chi_Minh')::date as d),
  hit as (
    select a.kind
    from public.staff_availability a, s
    where a.user_id = p_user
      and a.weekday = extract(isodow from s.d)::int
      and (a.start_time is null
           or (public.shift_start_at(s.d, a.start_time) < p_end_at
               and public.shift_end_at(s.d, a.start_time, a.end_time) > p_start_at))
  )
  select case
    when exists (select 1 from hit where kind = 'unavailable') then 'unavailable'
    when exists (select 1 from hit where kind = 'preferred') then 'preferred'
  end;
$$;

-- Everybody's availability at one branch, for the roster.
create or replace function public.roster_availability(p_branch uuid) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', a.user_id, 'weekday', a.weekday, 'kind', a.kind,
    'start_time', to_char(a.start_time, 'HH24:MI'), 'end_time', to_char(a.end_time, 'HH24:MI'))
    order by a.user_id, a.weekday, a.start_time nulls first), '[]'::jsonb)
  from public.staff_availability a
  where exists (select 1 from public.staff_branches sb where sb.user_id = a.user_id and sb.branch_id = p_branch);
$$;

-- ---------------------------------------------------------------- RPCs
create or replace function public.my_availability() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return public.availability_rows((select auth.uid()));
end;
$$;

create or replace function public.save_my_availability(p_items jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
begin
  if v_me is null or not exists (select 1 from public.staff_branches where user_id = v_me) then
    raise exception 'you do not work at any branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  perform public.replace_availability(v_me, p_items);
  return public.availability_rows(v_me);
end;
$$;

create or replace function public.staff_availability_of(p_user uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_user is null or not public.can_view_staff(p_user) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return public.availability_rows(p_user);
end;
$$;

-- A manager edits it for somebody who works at a branch where the manager has UPDATE.
create or replace function public.save_staff_availability(p_user uuid, p_items jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user is null or not exists (
    select 1 from public.staff_branches sb
    where sb.user_id = p_user and public.can_attendance('UPDATE', sb.branch_id)
  ) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  perform public.replace_availability(p_user, p_items);
  return public.availability_rows(p_user);
end;
$$;

revoke all on function public.check_availability_items(jsonb) from public, anon, authenticated;
revoke all on function public.replace_availability(uuid, jsonb) from public, anon, authenticated;
revoke all on function public.availability_rows(uuid) from public, anon, authenticated;
revoke all on function public.availability_conflict(uuid, timestamptz, timestamptz) from public, anon, authenticated;
revoke all on function public.roster_availability(uuid) from public, anon, authenticated;
revoke all on function public.my_availability() from public, anon;
revoke all on function public.save_my_availability(jsonb) from public, anon;
revoke all on function public.staff_availability_of(uuid) from public, anon;
revoke all on function public.save_staff_availability(uuid, jsonb) from public, anon;
grant execute on function public.my_availability() to authenticated;
grant execute on function public.save_my_availability(jsonb) to authenticated;
grant execute on function public.staff_availability_of(uuid) to authenticated;
grant execute on function public.save_staff_availability(uuid, jsonb) to authenticated;
