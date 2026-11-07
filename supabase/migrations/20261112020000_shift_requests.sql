-- Shift registration step 2: the registration window per branch and the requests staff send.
-- A request is one cell of the roster grid (a day and a shift template) that a person asks to work.
-- Deciding requests comes in step 3. Writes only through the RPCs below.

-- ------------------------------------------------------------------- tables
create table if not exists public.shift_registration_settings (
  branch_id           uuid primary key references public.branches (id) on delete cascade,
  is_open             boolean not null default false,
  weeks_ahead         integer not null default 2 check (weeks_ahead between 1 and 6),
  close_days_before   integer not null default 2 check (close_days_before between 0 and 14),
  max_shifts_per_week integer check (max_shifts_per_week is null or max_shifts_per_week between 1 and 21),
  staff_note          text check (staff_note is null or length(staff_note) <= 300),
  updated_by          uuid references public.users (id) on delete set null,
  updated_at          timestamptz not null default now()
);

create table if not exists public.shift_requests (
  id              uuid primary key default gen_random_uuid(),
  branch_id       uuid not null references public.branches (id) on delete cascade,
  user_id         uuid not null references public.users (id) on delete cascade,
  user_name       text not null default '',
  work_date       date not null,
  template_id     uuid references public.shift_templates (id) on delete set null,
  name            text not null,
  start_at        timestamptz not null,
  end_at          timestamptz not null,
  break_minutes   integer not null default 0 check (break_minutes >= 0),
  note            text check (note is null or length(note) <= 300),
  status          text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  assignment_id   uuid references public.shift_assignments (id) on delete set null,
  decided_by      uuid references public.users (id) on delete set null,
  decided_by_name text,
  decided_at      timestamptz,
  decision_note   text check (decision_note is null or length(decision_note) <= 300),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint shift_requests_span check (end_at > start_at and end_at - start_at <= interval '16 hours'),
  -- One person never has two pending requests at overlapping times.
  constraint shift_requests_no_overlap exclude using gist (
    user_id with =, tstzrange(start_at, end_at, '[)') with &&
  ) where (status = 'pending')
);
-- The same cell is requested once while it is alive.
create unique index if not exists shift_requests_cell_uniq
  on public.shift_requests (user_id, branch_id, work_date, template_id)
  where status in ('pending', 'approved');
create index if not exists shift_requests_branch_date_idx on public.shift_requests (branch_id, work_date);
create index if not exists shift_requests_user_date_idx on public.shift_requests (user_id, work_date);
create index if not exists shift_requests_pending_idx on public.shift_requests (branch_id) where status = 'pending';

drop trigger if exists shift_requests_updated_at on public.shift_requests;
create trigger shift_requests_updated_at before update on public.shift_requests
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------- security
alter table public.shift_registration_settings enable row level security;
alter table public.shift_requests enable row level security;
revoke all on public.shift_registration_settings, public.shift_requests from anon, authenticated;
grant select on public.shift_registration_settings, public.shift_requests to authenticated;

drop policy if exists "shift registration settings read" on public.shift_registration_settings;
create policy "shift registration settings read" on public.shift_registration_settings
  for select to authenticated
  using ((select public.is_branch_staff(branch_id)) or (select public.can_attendance('VIEW', branch_id)));

drop policy if exists "shift requests read" on public.shift_requests;
create policy "shift requests read" on public.shift_requests
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_attendance('VIEW', branch_id)));

-- -------------------------------------------------------------------- rules
-- Settings of one branch with the defaults filled in. Internal: callers check permission first.
create or replace function public.shift_registration_rules_raw(p_branch uuid) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'is_open', coalesce(s.is_open, false),
    'weeks_ahead', coalesce(s.weeks_ahead, 2),
    'close_days_before', coalesce(s.close_days_before, 2),
    'max_shifts_per_week', s.max_shifts_per_week,
    'staff_note', s.staff_note)
  from (select p_branch as branch_id) b
  left join public.shift_registration_settings s on s.branch_id = b.branch_id;
$$;

create or replace function public.shift_registration_rules(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.is_branch_staff(p_branch) or public.can_attendance('VIEW', p_branch)) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return public.shift_registration_rules_raw(p_branch);
end;
$$;

create or replace function public.save_shift_registration_settings(p_branch uuid, p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_open boolean;
  v_weeks integer;
  v_close integer;
  v_max integer;
  v_note text;
begin
  if not public.can_attendance('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  begin
    v_open := coalesce((p ->> 'is_open')::boolean, false);
    v_weeks := coalesce((p ->> 'weeks_ahead')::integer, 2);
    v_close := coalesce((p ->> 'close_days_before')::integer, 2);
    v_max := nullif(p ->> 'max_shifts_per_week', '')::integer;
    v_note := nullif(btrim(p ->> 'staff_note'), '');
  exception when others then
    raise exception 'invalid settings' using errcode = '22023', hint = 'bad_input';
  end;
  if v_weeks not between 1 and 6 or v_close not between 0 and 14
     or (v_max is not null and v_max not between 1 and 21) or length(coalesce(v_note, '')) > 300 then
    raise exception 'invalid settings' using errcode = '22023', hint = 'bad_input';
  end if;

  insert into public.shift_registration_settings
    (branch_id, is_open, weeks_ahead, close_days_before, max_shifts_per_week, staff_note, updated_by, updated_at)
  values (p_branch, v_open, v_weeks, v_close, v_max, v_note, (select auth.uid()), now())
  on conflict (branch_id) do update set
    is_open = excluded.is_open, weeks_ahead = excluded.weeks_ahead, close_days_before = excluded.close_days_before,
    max_shifts_per_week = excluded.max_shifts_per_week, staff_note = excluded.staff_note,
    updated_by = excluded.updated_by, updated_at = excluded.updated_at;
  return public.shift_registration_rules_raw(p_branch);
end;
$$;

-- Is the week starting p_monday open for registration at the branch right now?
-- {open, closes_at, reason}; reason is closed / past_deadline / too_far when not open.
create or replace function public.shift_registration_window(p_branch uuid, p_monday date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rules jsonb := public.shift_registration_rules_raw(p_branch);
  v_closes timestamptz;
  v_this_monday date := date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh')::date)::date;
  v_reason text;
begin
  if p_monday is null or extract(isodow from p_monday) <> 1 then
    raise exception 'the date must be a Monday' using errcode = '22023', hint = 'bad_input';
  end if;
  v_closes := (p_monday - (v_rules ->> 'close_days_before')::integer)::timestamp at time zone 'Asia/Ho_Chi_Minh';
  v_reason := case
    when not (v_rules ->> 'is_open')::boolean then 'closed'
    when now() >= v_closes then 'past_deadline'
    when p_monday > v_this_monday + 7 * (v_rules ->> 'weeks_ahead')::integer then 'too_far'
  end;
  return jsonb_build_object('open', v_reason is null, 'closes_at', v_closes, 'reason', v_reason);
end;
$$;

-- ------------------------------------------------------------------ the board
-- Everything the registration page needs for one branch and week, in one call.
create or replace function public.shift_registration_board(p_branch uuid, p_monday date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
begin
  if not public.is_branch_staff(p_branch) then
    raise exception 'you do not work at this branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  return jsonb_build_object(
    'rules', public.shift_registration_rules_raw(p_branch),
    'window', public.shift_registration_window(p_branch, p_monday),
    'templates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'name', t.name, 'start_time', to_char(t.start_time, 'HH24:MI'),
        'end_time', to_char(t.end_time, 'HH24:MI'), 'break_minutes', t.break_minutes, 'color', t.color,
        'overnight', t.end_time < t.start_time) order by t.sort_order, t.start_time, t.name)
      from public.shift_templates t where t.branch_id = p_branch and t.is_active), '[]'::jsonb),
    'days', (select jsonb_agg(d::date order by d) from generate_series(p_monday, p_monday + 6, interval '1 day') d),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'work_date', r.work_date, 'template_id', r.template_id, 'name', r.name, 'status', r.status,
        'note', r.note, 'decision_note', r.decision_note, 'assignment_id', r.assignment_id,
        'start_at', r.start_at, 'end_at', r.end_at) order by r.work_date, r.start_at)
      from public.shift_requests r
      where r.user_id = v_me and r.branch_id = p_branch and r.work_date between p_monday and p_monday + 6
        and r.status <> 'cancelled'), '[]'::jsonb),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'branch_id', a.branch_id, 'branch_name', b.name, 'work_date', a.work_date,
        'template_id', a.template_id, 'name', a.name, 'start_at', a.start_at, 'end_at', a.end_at) order by a.start_at)
      from public.shift_assignments a join public.branches b on b.id = a.branch_id
      where a.user_id = v_me and a.work_date between p_monday and p_monday + 6), '[]'::jsonb),
    'leaves', coalesce((
      select jsonb_agg(jsonb_build_object(
        'from_date', l.from_date, 'to_date', l.to_date, 'part', l.part, 'leave_type', l.leave_type)
        order by l.from_date)
      from public.leave_requests l
      where l.user_id = v_me and l.status = 'approved' and l.from_date <= p_monday + 6 and l.to_date >= p_monday), '[]'::jsonb),
    'availability', public.availability_rows(v_me),
    'needs', '[]'::jsonb
  );
end;
$$;

-- ----------------------------------------------------------------- requests
-- Sends one request per cell. A cell that cannot be requested is skipped with its reason;
-- the others are still created. Returns {created: [...], skipped: [...]}.
create or replace function public.submit_shift_requests(
  p_branch uuid, p_monday date, p_items jsonb, p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  v_window jsonb;
  v_rules jsonb;
  v_max integer;
  v_count integer;
  v_item jsonb;
  v_date date;
  v_tpl uuid;
  v_t public.shift_templates;
  v_start_at timestamptz;
  v_end_at timestamptz;
  v_id uuid;
  v_warning text;
  v_hint text;
  v_created jsonb := '[]'::jsonb;
  v_skipped jsonb := '[]'::jsonb;
  v_note text := nullif(btrim(p_note), '');
begin
  if v_me is null or not public.is_branch_staff(p_branch)
     or not exists (select 1 from public.branches where id = p_branch and is_active) then
    raise exception 'you do not work at this branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  v_window := public.shift_registration_window(p_branch, p_monday);
  if not (v_window ->> 'open')::boolean then
    raise exception 'registration is closed (%)', v_window ->> 'reason' using errcode = 'P0001', hint = 'registration_closed';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 21
     or length(coalesce(v_note, '')) > 300 then
    raise exception 'invalid request list' using errcode = '22023', hint = 'bad_input';
  end if;

  v_rules := public.shift_registration_rules_raw(p_branch);
  v_max := (v_rules ->> 'max_shifts_per_week')::integer;
  -- Alive requests and shifts already on the roster count toward the weekly limit.
  select (select count(*) from public.shift_requests r
          where r.user_id = v_me and r.branch_id = p_branch and r.status = 'pending'
            and r.work_date between p_monday and p_monday + 6)
       + (select count(*) from public.shift_assignments a
          where a.user_id = v_me and a.branch_id = p_branch and a.work_date between p_monday and p_monday + 6)
  into v_count;

  for v_item in select * from jsonb_array_elements(p_items) loop
    begin
      begin
        v_date := (v_item ->> 'work_date')::date;
        v_tpl := (v_item ->> 'template_id')::uuid;
      exception when others then
        raise exception 'invalid cell' using errcode = '22023', hint = 'bad_input';
      end;
      if v_date is null or v_tpl is null or v_date < p_monday or v_date > p_monday + 6 then
        raise exception 'invalid cell' using errcode = '22023', hint = 'bad_input';
      end if;
      select * into v_t from public.shift_templates where id = v_tpl and branch_id = p_branch and is_active;
      if not found then
        raise exception 'template not found' using errcode = 'P0001', hint = 'not_found';
      end if;
      if exists (select 1 from public.shift_requests r
                 where r.user_id = v_me and r.branch_id = p_branch and r.work_date = v_date
                   and r.template_id = v_tpl and r.status in ('pending', 'approved')) then
        raise exception 'already requested' using errcode = 'P0001', hint = 'duplicate';
      end if;
      if exists (select 1 from public.shift_assignments a
                 where a.user_id = v_me and a.branch_id = p_branch and a.work_date = v_date and a.template_id = v_tpl) then
        raise exception 'already on the roster' using errcode = 'P0001', hint = 'already_on_roster';
      end if;
      v_start_at := public.shift_start_at(v_date, v_t.start_time);
      v_end_at := public.shift_end_at(v_date, v_t.start_time, v_t.end_time);
      if exists (select 1 from public.shift_assignments a
                 where a.user_id = v_me and tstzrange(a.start_at, a.end_at, '[)') && tstzrange(v_start_at, v_end_at, '[)')) then
        raise exception 'overlaps a shift you already have' using errcode = 'P0001', hint = 'shift_overlap';
      end if;
      if v_max is not null and v_count >= v_max then
        raise exception 'weekly limit reached' using errcode = 'P0001', hint = 'over_weekly_limit';
      end if;

      insert into public.shift_requests (
        branch_id, user_id, user_name, work_date, template_id, name, start_at, end_at, break_minutes, note
      ) values (
        p_branch, v_me, public.staff_display_name(v_me), v_date, v_tpl, v_t.name, v_start_at, v_end_at,
        v_t.break_minutes, v_note
      ) returning id into v_id;
      v_count := v_count + 1;

      v_warning := case
        when public.shift_on_leave(v_me, v_start_at) then 'on_leave'
        when public.availability_conflict(v_me, v_start_at, v_end_at) = 'unavailable' then 'unavailable'
      end;
      v_created := v_created || jsonb_strip_nulls(jsonb_build_object(
        'id', v_id, 'work_date', v_date, 'template_id', v_tpl, 'warning', v_warning));
    exception
      when exclusion_violation then
        v_skipped := v_skipped || jsonb_build_object('work_date', v_item ->> 'work_date', 'template_id', v_item ->> 'template_id', 'hint', 'request_overlap');
      when unique_violation then
        v_skipped := v_skipped || jsonb_build_object('work_date', v_item ->> 'work_date', 'template_id', v_item ->> 'template_id', 'hint', 'duplicate');
      when others then
        get stacked diagnostics v_hint = pg_exception_hint;
        v_skipped := v_skipped || jsonb_build_object(
          'work_date', v_item ->> 'work_date', 'template_id', v_item ->> 'template_id', 'hint', coalesce(v_hint, 'bad_input'));
    end;
  end loop;
  return jsonb_build_object('created', v_created, 'skipped', v_skipped);
end;
$$;

create or replace function public.cancel_shift_request(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row public.shift_requests;
begin
  select * into v_row from public.shift_requests where id = p_id for update;
  if not found or v_row.user_id is distinct from (select auth.uid()) then
    raise exception 'request not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if v_row.status <> 'pending' then
    raise exception 'the request was already decided' using errcode = 'P0001', hint = 'not_pending';
  end if;
  update public.shift_requests set status = 'cancelled' where id = p_id;
end;
$$;

-- The caller's own requests at every branch in a date range (at most 93 days).
create or replace function public.my_shift_requests(p_from date, p_to date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from > 92 then
    raise exception 'date range is longer than 93 days' using errcode = '22023', hint = 'range_too_long';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', r.id, 'branch_id', r.branch_id, 'branch_name', b.name, 'work_date', r.work_date,
      'template_id', r.template_id, 'name', r.name, 'start_at', r.start_at, 'end_at', r.end_at,
      'status', r.status, 'note', r.note, 'decision_note', r.decision_note,
      'expired', r.status = 'pending' and r.start_at <= now(), 'assignment_id', r.assignment_id)
      order by r.work_date, r.start_at)
    from public.shift_requests r join public.branches b on b.id = r.branch_id
    where r.user_id = (select auth.uid()) and r.work_date between p_from and p_to), '[]'::jsonb);
end;
$$;

revoke all on function public.shift_registration_rules_raw(uuid) from public, anon, authenticated;
revoke all on function public.shift_registration_window(uuid, date) from public, anon, authenticated;
revoke all on function public.shift_registration_rules(uuid) from public, anon;
revoke all on function public.save_shift_registration_settings(uuid, jsonb) from public, anon;
revoke all on function public.shift_registration_board(uuid, date) from public, anon;
revoke all on function public.submit_shift_requests(uuid, date, jsonb, text) from public, anon;
revoke all on function public.cancel_shift_request(uuid) from public, anon;
revoke all on function public.my_shift_requests(date, date) from public, anon;
grant execute on function public.shift_registration_rules(uuid) to authenticated;
grant execute on function public.save_shift_registration_settings(uuid, jsonb) to authenticated;
grant execute on function public.shift_registration_board(uuid, date) to authenticated;
grant execute on function public.submit_shift_requests(uuid, date, jsonb, text) to authenticated;
grant execute on function public.cancel_shift_request(uuid) to authenticated;
grant execute on function public.my_shift_requests(date, date) to authenticated;
