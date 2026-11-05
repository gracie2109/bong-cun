-- Attendance step 3: leave allowances and leave requests.
-- Replaces the placeholders of step 2 (leave_type_on, branch_leaves_on, my_leaves) and makes the
-- roster show approved leave. Leave is per person: an approved request holds at every branch.

-- ------------------------------------------------------------------- tables
create table if not exists public.leave_allowances (
  user_id     uuid not null references public.users (id) on delete cascade,
  year        integer not null check (year between 2020 and 2100),
  annual_days numeric(4, 1) not null check (annual_days between 0 and 60),
  updated_by  uuid references public.users (id) on delete set null,
  updated_at  timestamptz not null default now(),
  primary key (user_id, year)
);

create table if not exists public.leave_requests (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users (id) on delete restrict,
  user_name       text not null default '',
  branch_id       uuid not null references public.branches (id) on delete restrict,
  leave_type      text not null check (leave_type in ('annual', 'sick', 'unpaid', 'other')),
  from_date       date not null,
  to_date         date not null,
  part            text not null default 'full' check (part in ('full', 'am', 'pm')),
  days            numeric(5, 1) not null check (days >= 0),
  reason          text not null check (length(btrim(reason)) between 1 and 500),
  status          text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  decided_by      uuid references public.users (id) on delete set null,
  decided_by_name text,
  decided_at      timestamptz,
  decision_note   text check (decision_note is null or length(decision_note) <= 500),
  created_by      uuid references public.users (id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint leave_requests_range check (to_date >= from_date and to_date - from_date <= 60),
  constraint leave_requests_half_day check (part = 'full' or from_date = to_date),
  -- No two live requests of one person cover the same day.
  constraint leave_requests_no_overlap exclude using gist (
    user_id with =, daterange(from_date, to_date, '[]') with &&
  ) where (status in ('pending', 'approved'))
);
create index if not exists leave_requests_branch_status_idx on public.leave_requests (branch_id, status, from_date);
create index if not exists leave_requests_user_idx on public.leave_requests (user_id, from_date);

drop trigger if exists leave_requests_updated_at on public.leave_requests;
create trigger leave_requests_updated_at before update on public.leave_requests
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------- security
alter table public.leave_allowances enable row level security;
alter table public.leave_requests enable row level security;

revoke all on public.leave_allowances, public.leave_requests from anon, authenticated;
grant select on public.leave_allowances, public.leave_requests to authenticated;

-- May the caller see this person's attendance data: themselves, or a manager at one of their branches.
create or replace function public.can_view_staff(p_user uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user = (select auth.uid()) or exists (
    select 1 from public.staff_branches sb
    where sb.user_id = p_user and public.can_attendance('VIEW', sb.branch_id)
  );
$$;

revoke all on function public.can_view_staff(uuid) from public, anon, authenticated;

drop policy if exists "leave requests read" on public.leave_requests;
create policy "leave requests read" on public.leave_requests
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_attendance('VIEW', branch_id)));

drop policy if exists "leave allowances read" on public.leave_allowances;
create policy "leave allowances read" on public.leave_allowances
  for select to authenticated
  using ((select public.can_view_staff(user_id)));

-- ------------------------------------------------------------------ helpers
-- Yearly allowance: the row, or 12 days when nobody set one.
create or replace function public.leave_allowance_days(p_user uuid, p_year integer) returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select a.annual_days from public.leave_allowances a where a.user_id = p_user and a.year = p_year), 12);
$$;

-- Days a request takes: the days the branch is open, or 0.5 for half a day that it is open.
create or replace function public.leave_days(p_branch uuid, p_from date, p_to date, p_part text) returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select case when p_part = 'full' then count(*)::numeric else count(*) * 0.5 end
  from generate_series(p_from, p_to, interval '1 day') as d(day)
  left join public.branch_hours h on h.branch_id = p_branch and h.weekday = extract(isodow from d.day)::int
  where not coalesce(h.is_closed, false);
$$;

revoke all on function public.leave_allowance_days(uuid, integer) from public, anon, authenticated;
revoke all on function public.leave_days(uuid, date, date, text) from public, anon, authenticated;

-- Approved leave that covers the shift starting at p_start_at. Half days cover the morning
-- (starting before 12:00 Vietnam time) or the afternoon.
create or replace function public.leave_type_on(p_user uuid, p_start_at timestamptz) returns text
language sql
stable
security definer
set search_path = ''
as $$
  select r.leave_type
  from public.leave_requests r
  where r.user_id = p_user and r.status = 'approved'
    and public.boarding_local_date(p_start_at) between r.from_date and r.to_date
    and (r.part = 'full'
         or (r.part = 'am' and (p_start_at at time zone 'Asia/Ho_Chi_Minh')::time < time '12:00')
         or (r.part = 'pm' and (p_start_at at time zone 'Asia/Ho_Chi_Minh')::time >= time '12:00'))
  limit 1;
$$;

-- Approved leaves of the branch's staff that touch [p_from, p_to].
create or replace function public.roster_leaves(p_branch uuid, p_from date, p_to date) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', r.user_id, 'from_date', r.from_date, 'to_date', r.to_date, 'part', r.part, 'leave_type', r.leave_type)
    order by r.from_date, r.user_id), '[]'::jsonb)
  from public.leave_requests r
  where r.status = 'approved' and r.from_date <= p_to and r.to_date >= p_from
    and exists (select 1 from public.staff_branches sb where sb.user_id = r.user_id and sb.branch_id = p_branch);
$$;

create or replace function public.branch_leaves_on(p_branch uuid, p_date date) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$ select public.roster_leaves(p_branch, p_date, p_date); $$;

create or replace function public.my_leaves(p_from date, p_to date) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', r.user_id, 'from_date', r.from_date, 'to_date', r.to_date, 'part', r.part, 'leave_type', r.leave_type)
    order by r.from_date), '[]'::jsonb)
  from public.leave_requests r
  where r.user_id = (select auth.uid()) and r.status = 'approved' and r.from_date <= p_to and r.to_date >= p_from;
$$;

revoke all on function public.roster_leaves(uuid, date, date) from public, anon, authenticated;
revoke all on function public.branch_leaves_on(uuid, date) from public, anon, authenticated;
revoke all on function public.my_leaves(date, date) from public, anon, authenticated;

-- The roster draws approved leave (step 1 returned an empty list).
create or replace function public.shift_roster(p_branch uuid, p_from date, p_to date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_attendance('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from + 1 > 42 then
    raise exception 'date range is longer than 42 days' using errcode = '22023', hint = 'range_too_long';
  end if;

  return jsonb_build_object(
    'staff', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', sb.user_id, 'name', public.staff_display_name(sb.user_id), 'role', sb.role,
        'photo_url', u.photo_url) order by public.staff_display_name(sb.user_id))
      from public.staff_branches sb
      join public.users u on u.id = sb.user_id
      where sb.branch_id = p_branch), '[]'::jsonb),
    'templates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'branch_id', t.branch_id, 'name', t.name,
        'start_time', to_char(t.start_time, 'HH24:MI'), 'end_time', to_char(t.end_time, 'HH24:MI'),
        'break_minutes', t.break_minutes, 'color', t.color, 'is_active', t.is_active,
        'sort_order', t.sort_order, 'overnight', t.end_time < t.start_time)
        order by t.sort_order, t.start_time, t.name)
      from public.shift_templates t
      where t.branch_id = p_branch and t.is_active), '[]'::jsonb),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'user_id', a.user_id, 'work_date', a.work_date, 'template_id', a.template_id,
        'name', a.name, 'color', coalesce(t.color, 'slate'), 'start_at', a.start_at, 'end_at', a.end_at,
        'break_minutes', a.break_minutes, 'note', a.note, 'has_entry', public.assignment_has_entry(a.id))
        order by a.start_at)
      from public.shift_assignments a
      left join public.shift_templates t on t.id = a.template_id
      where a.branch_id = p_branch and a.work_date between p_from and p_to), '[]'::jsonb),
    'leaves', public.roster_leaves(p_branch, p_from, p_to)
  );
end;
$$;

-- Annual leave counted for a person and year: used (approved), pending, allowance, what remains.
create or replace function public.leave_balance(p_user uuid, p_year integer) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_allowance numeric := public.leave_allowance_days(p_user, p_year);
  v_used      numeric;
  v_pending   numeric;
begin
  if (select auth.uid()) is null or not public.can_view_staff(p_user) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  select coalesce(sum(days) filter (where status = 'approved'), 0), coalesce(sum(days) filter (where status = 'pending'), 0)
    into v_used, v_pending
  from public.leave_requests
  where user_id = p_user and leave_type = 'annual' and extract(year from from_date) = p_year;
  return jsonb_build_object('allowance', v_allowance, 'used', v_used, 'pending', v_pending,
                            'remaining', v_allowance - v_used);
end;
$$;

-- A manager sets somebody's annual days (SETTING at one of their branches).
create or replace function public.save_leave_allowance(p_user uuid, p_year integer, p_days numeric) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.staff_branches sb where sb.user_id = p_user and public.can_attendance('SETTING', sb.branch_id)
  ) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_year is null or p_year not between 2020 and 2100 or p_days is null or p_days not between 0 and 60 then
    raise exception 'invalid allowance' using errcode = '22023', hint = 'bad_input';
  end if;
  insert into public.leave_allowances (user_id, year, annual_days, updated_by)
  values (p_user, p_year, p_days, (select auth.uid()))
  on conflict (user_id, year) do update set annual_days = excluded.annual_days, updated_by = excluded.updated_by, updated_at = now();
end;
$$;

-- Checks shared by both ways of filing a request.
create or replace function public.check_leave_input(p_type text, p_from date, p_to date, p_part text, p_reason text) returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_type is null or p_type not in ('annual', 'sick', 'unpaid', 'other')
     or p_part is null or p_part not in ('full', 'am', 'pm')
     or p_from is null or p_to is null or p_to < p_from or p_to - p_from > 60
     or (p_part <> 'full' and p_from <> p_to)
     or length(btrim(coalesce(p_reason, ''))) not between 1 and 500 then
    raise exception 'invalid leave request' using errcode = '22023', hint = 'bad_input';
  end if;
end;
$$;

revoke all on function public.check_leave_input(text, date, date, text, text) from public, anon, authenticated;

-- Inserts a request; two live requests may not share a day.
create or replace function public.insert_leave(
  p_user uuid, p_branch uuid, p_type text, p_from date, p_to date, p_part text, p_reason text, p_status text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_days numeric := public.leave_days(p_branch, p_from, p_to, p_part);
  v_id   uuid;
  v_uid  uuid := (select auth.uid());
begin
  if v_days <= 0 then
    raise exception 'the branch is closed on those days' using errcode = '22023', hint = 'no_working_days';
  end if;
  begin
    insert into public.leave_requests (user_id, user_name, branch_id, leave_type, from_date, to_date, part, days, reason, status,
                                       decided_by, decided_by_name, decided_at, created_by)
    values (p_user, coalesce(public.staff_display_name(p_user), ''), p_branch, p_type, p_from, p_to, p_part, v_days, btrim(p_reason), p_status,
            case when p_status = 'approved' then v_uid end,
            case when p_status = 'approved' then public.staff_display_name(v_uid) end,
            case when p_status = 'approved' then now() end,
            v_uid)
    returning id into v_id;
  exception when exclusion_violation then
    raise exception 'those days overlap another request' using errcode = 'P0001', hint = 'leave_overlap';
  end;
  return jsonb_build_object('id', v_id, 'days', v_days,
    'warning', case when p_type = 'annual'
      and (select (b ->> 'remaining')::numeric - (b ->> 'pending')::numeric < 0
           from (select public.leave_balance(p_user, extract(year from p_from)::int) as b) x) then 'over_allowance' end);
end;
$$;

revoke all on function public.insert_leave(uuid, uuid, text, date, date, text, text, text) from public, anon, authenticated;

-- Staff file their own request at a branch they work at; it waits for a manager.
create or replace function public.request_leave(
  p_branch uuid, p_type text, p_from date, p_to date, p_part text, p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not public.is_branch_staff(p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  perform public.check_leave_input(p_type, p_from, p_to, p_part, p_reason);
  -- A week of grace so sick leave can be filed afterwards.
  if p_from < public.boarding_local_date(now()) - 7 then
    raise exception 'that date is too far in the past' using errcode = '22023', hint = 'too_old';
  end if;
  return public.insert_leave((select auth.uid()), p_branch, p_type, p_from, p_to, p_part, p_reason, 'pending');
end;
$$;

-- A manager files a request for somebody else; it is approved at once. Never for themselves.
create or replace function public.request_leave_for(
  p_user uuid, p_branch uuid, p_type text, p_from date, p_to date, p_part text, p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_attendance('UPDATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_user = (select auth.uid()) and not coalesce((select public.is_super_admin()), false) then
    raise exception 'you cannot approve your own leave' using errcode = 'P0001', hint = 'own_request';
  end if;
  if not exists (select 1 from public.staff_branches where user_id = p_user and branch_id = p_branch) then
    raise exception 'not staff of this branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  perform public.check_leave_input(p_type, p_from, p_to, p_part, p_reason);
  return public.insert_leave(p_user, p_branch, p_type, p_from, p_to, p_part, p_reason, 'approved');
end;
$$;

-- The owner withdraws a pending request, or an approved one that has not started.
create or replace function public.cancel_leave(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.leave_requests;
begin
  select * into v from public.leave_requests where id = p_id for update;
  if not found or v.user_id <> (select auth.uid()) then
    raise exception 'request not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not (v.status = 'pending' or (v.status = 'approved' and v.from_date > public.boarding_local_date(now()))) then
    raise exception 'this request can no longer be cancelled' using errcode = 'P0001', hint = 'not_cancellable';
  end if;
  update public.leave_requests set status = 'cancelled' where id = p_id;
end;
$$;

-- A manager approves or rejects a pending request; approving may change the type (e.g. to unpaid).
create or replace function public.decide_leave(
  p_id uuid, p_approve boolean, p_note text default null, p_type text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v         public.leave_requests;
  v_type    text;
  v_days    numeric;
  v_uid     uuid := (select auth.uid());
  v_warning text;
begin
  select * into v from public.leave_requests where id = p_id for update;
  if not found then
    raise exception 'request not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_attendance('UPDATE', v.branch_id) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if v.status <> 'pending' then
    raise exception 'the request was already decided' using errcode = 'P0001', hint = 'not_pending';
  end if;
  if v.user_id = v_uid and not coalesce((select public.is_super_admin()), false) then
    raise exception 'you cannot decide your own request' using errcode = 'P0001', hint = 'own_request';
  end if;
  v_type := coalesce(p_type, v.leave_type);
  if v_type not in ('annual', 'sick', 'unpaid', 'other') or length(coalesce(p_note, '')) > 500 then
    raise exception 'invalid decision' using errcode = '22023', hint = 'bad_input';
  end if;
  v_days := public.leave_days(v.branch_id, v.from_date, v.to_date, v.part);

  update public.leave_requests
  set status = case when p_approve then 'approved' else 'rejected' end,
      leave_type = v_type, days = v_days, decision_note = nullif(btrim(coalesce(p_note, '')), ''),
      decided_by = v_uid, decided_by_name = public.staff_display_name(v_uid), decided_at = now()
  where id = p_id;

  if p_approve and v_type = 'annual'
     and (public.leave_balance(v.user_id, extract(year from v.from_date)::int) ->> 'remaining')::numeric < 0 then
    v_warning := 'over_allowance';
  end if;
  return jsonb_build_object('status', case when p_approve then 'approved' else 'rejected' end, 'days', v_days, 'warning', v_warning);
end;
$$;

-- One row as the screens read it.
create or replace function public.leave_row(r public.leave_requests, p_branch_name text) returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id, 'user_id', r.user_id, 'user_name', r.user_name, 'branch_id', r.branch_id, 'branch_name', p_branch_name,
    'leave_type', r.leave_type, 'from_date', r.from_date, 'to_date', r.to_date, 'part', r.part, 'days', r.days,
    'reason', r.reason, 'status', r.status, 'decided_by_name', r.decided_by_name, 'decided_at', r.decided_at,
    'decision_note', r.decision_note, 'created_by_self', r.created_by = r.user_id, 'created_at', r.created_at);
$$;

revoke all on function public.leave_row(public.leave_requests, text) from public, anon, authenticated;

-- The manager's list: a branch (or every branch the caller may view when null), filtered and paged.
create or replace function public.list_leave_requests(
  p_branch uuid default null, p_status text default 'pending', p_from date default null, p_to date default null,
  p_search text default null, p_page integer default 1, p_page_size integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[] := public.attendance_branch_ids(p_branch, 'VIEW');
  v_size     integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset   integer := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total    integer;
  v_rows     jsonb;
begin
  if p_status is not null and p_status not in ('all', 'pending', 'approved', 'rejected', 'cancelled') then
    raise exception 'invalid status' using errcode = '22023', hint = 'bad_input';
  end if;

  with picked as (
    select r.id, r.from_date, r.created_at
    from public.leave_requests r
    where r.branch_id = any (v_branches)
      and (p_status is null or p_status = 'all' or r.status = p_status)
      and (p_from is null or r.to_date >= p_from)
      and (p_to is null or r.from_date <= p_to)
      and (nullif(btrim(coalesce(p_search, '')), '') is null or r.user_name ilike '%' || btrim(p_search) || '%')
  ),
  page as (
    select id from picked order by from_date desc, created_at desc limit v_size offset v_offset
  )
  select (select count(*) from picked),
         coalesce((select jsonb_agg(public.leave_row(r, b.name) order by r.from_date desc, r.created_at desc)
                   from public.leave_requests r
                   join public.branches b on b.id = r.branch_id
                   where r.id in (select id from page)), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$$;

-- My requests of a year, with my balance.
create or replace function public.my_leave_requests(p_year integer default null) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := (select auth.uid());
  v_year integer := coalesce(p_year, extract(year from public.boarding_local_date(now()))::int);
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'not_signed_in';
  end if;
  return jsonb_build_object(
    'year', v_year,
    'requests', coalesce((
      select jsonb_agg(public.leave_row(r, b.name) order by r.from_date desc)
      from public.leave_requests r join public.branches b on b.id = r.branch_id
      where r.user_id = v_uid and extract(year from r.from_date) = v_year), '[]'::jsonb),
    'balance', public.leave_balance(v_uid, v_year));
end;
$$;

-- Pending requests waiting for the caller, for the menu badge. Zero without the permission.
create or replace function public.pending_leave_count(p_branch uuid default null) returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.leave_requests r
  where r.status = 'pending' and r.user_id <> (select auth.uid())
    and public.can_attendance('UPDATE', r.branch_id)
    and (p_branch is null or r.branch_id = p_branch);
$$;

revoke all on function public.leave_balance(uuid, integer) from public, anon;
revoke all on function public.save_leave_allowance(uuid, integer, numeric) from public, anon;
revoke all on function public.request_leave(uuid, text, date, date, text, text) from public, anon;
revoke all on function public.request_leave_for(uuid, uuid, text, date, date, text, text) from public, anon;
revoke all on function public.cancel_leave(uuid) from public, anon;
revoke all on function public.decide_leave(uuid, boolean, text, text) from public, anon;
revoke all on function public.list_leave_requests(uuid, text, date, date, text, integer, integer) from public, anon;
revoke all on function public.my_leave_requests(integer) from public, anon;
revoke all on function public.pending_leave_count(uuid) from public, anon;
grant execute on function public.leave_balance(uuid, integer) to authenticated;
grant execute on function public.save_leave_allowance(uuid, integer, numeric) to authenticated;
grant execute on function public.request_leave(uuid, text, date, date, text, text) to authenticated;
grant execute on function public.request_leave_for(uuid, uuid, text, date, date, text, text) to authenticated;
grant execute on function public.cancel_leave(uuid) to authenticated;
grant execute on function public.decide_leave(uuid, boolean, text, text) to authenticated;
grant execute on function public.list_leave_requests(uuid, text, date, date, text, integer, integer) to authenticated;
grant execute on function public.my_leave_requests(integer) to authenticated;
grant execute on function public.pending_leave_count(uuid) to authenticated;

notify pgrst, 'reload schema';
