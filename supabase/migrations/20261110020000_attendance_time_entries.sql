-- Staff attendance, step 2 (docs: ke-hoach-cham-cong.md, sections 5.4-5.5, 7 and 8.2): clock in/out,
-- manager corrections with a change log, forgotten clock-outs closed by cron, the per-shift
-- attendance rows every report builds on, and the "today" board. Safe to run more than once.
--
-- Times always come from the server clock. Corrections need a reason and are logged; a manager can
-- never edit their own entry (except a super admin).

-- ------------------------------------------------------------------- tables
create table if not exists public.time_entries (
  id            uuid primary key default gen_random_uuid(),
  branch_id     uuid not null references public.branches (id) on delete restrict,
  user_id       uuid not null references public.users (id) on delete restrict,
  user_name     text not null,
  assignment_id uuid references public.shift_assignments (id) on delete set null,
  work_date     date not null,
  check_in_at   timestamptz not null,
  check_out_at  timestamptz,
  in_source     text not null default 'self' check (in_source in ('self', 'manager', 'auto')),
  out_source    text check (out_source is null or out_source in ('self', 'manager', 'auto')),
  review_reason text check (review_reason is null or review_reason in ('missing_checkout', 'unscheduled')),
  reviewed_by   uuid references public.users (id) on delete set null,
  reviewed_at   timestamptz,
  note          text check (note is null or length(note) <= 300),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint time_entries_out_after_in check (check_out_at is null or check_out_at >= check_in_at),
  constraint time_entries_within_a_day check (check_out_at is null or check_out_at - check_in_at <= interval '24 hours')
);
-- One open entry per person in the whole system, and one entry per scheduled shift.
create unique index if not exists time_entries_one_open_idx on public.time_entries (user_id) where check_out_at is null;
create unique index if not exists time_entries_one_per_shift_idx on public.time_entries (assignment_id) where assignment_id is not null;
create index if not exists time_entries_branch_date_idx on public.time_entries (branch_id, work_date);
create index if not exists time_entries_user_date_idx on public.time_entries (user_id, work_date);

create table if not exists public.time_entry_changes (
  id              uuid primary key default gen_random_uuid(),
  entry_id        uuid not null,
  branch_id       uuid not null,
  user_id         uuid not null,
  action          text not null check (action in ('create', 'update', 'delete', 'auto_close')),
  "before"        jsonb,
  "after"         jsonb,
  reason          text,
  changed_by      uuid references public.users (id) on delete set null,
  changed_by_name text,
  changed_at      timestamptz not null default now(),
  constraint time_entry_changes_reason check (action = 'auto_close' or length(btrim(coalesce(reason, ''))) > 0)
);
create index if not exists time_entry_changes_entry_idx on public.time_entry_changes (entry_id, changed_at);
create index if not exists time_entry_changes_branch_idx on public.time_entry_changes (branch_id, changed_at);

-- The calendar day of the check-in, on the salon's clock.
create or replace function public.time_entries_set_work_date() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.work_date := public.boarding_local_date(new.check_in_at);
  return new;
end;
$$;

drop trigger if exists time_entries_work_date on public.time_entries;
create trigger time_entries_work_date before insert or update of check_in_at on public.time_entries
  for each row execute function public.time_entries_set_work_date();
drop trigger if exists time_entries_updated_at on public.time_entries;
create trigger time_entries_updated_at before update on public.time_entries
  for each row execute function public.set_updated_at();

alter table public.time_entries enable row level security;
alter table public.time_entry_changes enable row level security;
revoke all on public.time_entries, public.time_entry_changes from anon, authenticated;
grant select on public.time_entries, public.time_entry_changes to authenticated;

drop policy if exists "time entries read" on public.time_entries;
create policy "time entries read" on public.time_entries
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_attendance('VIEW', branch_id)));

drop policy if exists "time entry changes read" on public.time_entry_changes;
create policy "time entry changes read" on public.time_entry_changes
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_attendance('VIEW', branch_id)));

-- ------------------------------------------------------------------ helpers
create or replace function public.minutes_between(p_from timestamptz, p_to timestamptz) returns integer
language sql
immutable
set search_path = ''
as $$ select floor(extract(epoch from (p_to - p_from)) / 60)::int; $$;

revoke all on function public.minutes_between(timestamptz, timestamptz) from public, anon, authenticated;

-- Replaces the placeholder of step 1: a shift is locked once somebody clocked in on it.
create or replace function public.assignment_has_entry(p_assignment uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select exists (select 1 from public.time_entries where assignment_id = p_assignment); $$;

revoke all on function public.assignment_has_entry(uuid) from public, anon, authenticated;

-- Placeholders for the leave tables (step 3 replaces them).
create or replace function public.leave_type_on(p_user uuid, p_start_at timestamptz) returns text
language sql
stable
set search_path = ''
as $$ select null::text; $$;

create or replace function public.branch_leaves_on(p_branch uuid, p_date date) returns jsonb
language sql
stable
set search_path = ''
as $$ select '[]'::jsonb; $$;

create or replace function public.my_leaves(p_from date, p_to date) returns jsonb
language sql
stable
set search_path = ''
as $$ select '[]'::jsonb; $$;

revoke all on function public.leave_type_on(uuid, timestamptz) from public, anon, authenticated;
revoke all on function public.branch_leaves_on(uuid, date) from public, anon, authenticated;
revoke all on function public.my_leaves(date, date) from public, anon, authenticated;

create or replace function public.shift_on_leave(p_user uuid, p_start_at timestamptz) returns boolean
language sql
stable
set search_path = ''
as $$ select public.leave_type_on(p_user, p_start_at) is not null; $$;

revoke all on function public.shift_on_leave(uuid, timestamptz) from public, anon, authenticated;

create or replace function public.log_time_entry_change(
  p_entry uuid, p_branch uuid, p_user uuid, p_action text, p_before jsonb, p_after jsonb, p_reason text
) returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.time_entry_changes (entry_id, branch_id, user_id, action, "before", "after", reason, changed_by, changed_by_name)
  values (p_entry, p_branch, p_user, p_action, p_before, p_after, nullif(btrim(p_reason), ''),
          (select auth.uid()), case when (select auth.uid()) is null then null else public.staff_display_name((select auth.uid())) end);
$$;

revoke all on function public.log_time_entry_change(uuid, uuid, uuid, text, jsonb, jsonb, text) from public, anon, authenticated;

create or replace function public.time_entry_snapshot(e public.time_entries) returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object('check_in_at', e.check_in_at, 'check_out_at', e.check_out_at,
                            'assignment_id', e.assignment_id, 'review_reason', e.review_reason, 'note', e.note);
$$;

revoke all on function public.time_entry_snapshot(public.time_entries) from public, anon, authenticated;

-- ------------------------------------------------------- closing stale entries
-- Entries still open after the branch's "review_after_hours" are closed with 0 minutes worked and
-- flagged for a manager. No hours are invented. p_user limits it to one person (clock in does that).
create or replace function public.close_stale_entries(p_user uuid default null) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r   public.time_entries;
  v_n integer := 0;
begin
  for r in
    select e.* from public.time_entries e
    where e.check_out_at is null
      and (p_user is null or e.user_id = p_user)
      and e.check_in_at < now() - make_interval(hours => (public.attendance_rules_raw(e.branch_id) ->> 'review_after_hours')::int)
    for update skip locked
  loop
    update public.time_entries
    set check_out_at = check_in_at, out_source = 'auto', review_reason = 'missing_checkout'
    where id = r.id;
    insert into public.time_entry_changes (entry_id, branch_id, user_id, action, "before", "after")
    values (r.id, r.branch_id, r.user_id, 'auto_close', public.time_entry_snapshot(r),
            jsonb_build_object('check_out_at', r.check_in_at, 'review_reason', 'missing_checkout'));
    v_n := v_n + 1;
  end loop;
  return v_n;
end;
$$;

revoke all on function public.close_stale_entries(uuid) from public, anon, authenticated;
grant execute on function public.close_stale_entries(uuid) to service_role;

-- Every hour at minute 5.
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('close-stale-time-entries')
  where exists (select 1 from cron.job where jobname = 'close-stale-time-entries');
  perform cron.schedule('close-stale-time-entries', '5 * * * *', 'select public.close_stale_entries()');
end;
$$;

-- ---------------------------------------------------------------- clocking
-- What the clock button shows: the branches the caller can clock in at, the open entry (if any),
-- and shifts that are on now or start within a day.
create or replace function public.clock_status() returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'forbidden';
  end if;
  perform public.close_stale_entries(v_user);

  return jsonb_build_object(
    'now', now(),
    'branches', coalesce((
      select jsonb_agg(jsonb_build_object('id', b.id, 'code', b.code, 'name', b.name) order by b.name)
      from public.staff_branches sb join public.branches b on b.id = sb.branch_id
      where sb.user_id = v_user and b.is_active), '[]'::jsonb),
    'open_entry', (
      select jsonb_build_object(
        'id', e.id, 'branch_id', e.branch_id, 'branch_name', b.name, 'check_in_at', e.check_in_at,
        'assignment_id', e.assignment_id, 'shift_name', a.name, 'shift_end_at', a.end_at)
      from public.time_entries e
      join public.branches b on b.id = e.branch_id
      left join public.shift_assignments a on a.id = e.assignment_id
      where e.user_id = v_user and e.check_out_at is null),
    'shifts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'branch_id', a.branch_id, 'branch_name', b.name, 'name', a.name,
        'start_at', a.start_at, 'end_at', a.end_at) order by a.start_at)
      from public.shift_assignments a
      join public.branches b on b.id = a.branch_id
      where a.user_id = v_user and a.end_at > now() and a.start_at < now() + interval '24 hours'
        and not exists (select 1 from public.time_entries e where e.assignment_id = a.id)), '[]'::jsonb)
  );
end;
$$;

-- Clock in at a branch. Joins the earliest unclocked shift that is on now (or starts within the
-- branch's early window); without one it needs p_unscheduled_ok after the app asked the person.
create or replace function public.clock_in(
  p_branch uuid, p_note text default null, p_unscheduled_ok boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user   uuid := (select auth.uid());
  v_rules  jsonb;
  v_shift  public.shift_assignments;
  v_id     uuid;
  v_late   integer := 0;
  v_start  timestamptz;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'forbidden';
  end if;
  if not public.is_branch_staff(p_branch) or not exists (select 1 from public.branches where id = p_branch and is_active) then
    raise exception 'you do not work at this branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;

  perform public.close_stale_entries(v_user);
  if exists (select 1 from public.time_entries where user_id = v_user and check_out_at is null) then
    raise exception 'already clocked in' using errcode = 'P0001', hint = 'already_in';
  end if;

  v_rules := public.attendance_rules_raw(p_branch);
  select a.* into v_shift
  from public.shift_assignments a
  where a.user_id = v_user and a.branch_id = p_branch
    and now() >= a.start_at - make_interval(mins => (v_rules ->> 'checkin_early_minutes')::int)
    and now() < a.end_at
    and not exists (select 1 from public.time_entries e where e.assignment_id = a.id)
  order by a.start_at
  limit 1;

  if v_shift.id is null then
    if not (v_rules ->> 'allow_unscheduled')::boolean then
      raise exception 'no shift is scheduled now' using errcode = 'P0001', hint = 'no_shift';
    end if;
    if not coalesce(p_unscheduled_ok, false) then
      raise exception 'no shift is scheduled now' using errcode = 'P0001', hint = 'confirm_unscheduled';
    end if;
  else
    v_late := greatest(0, public.minutes_between(v_shift.start_at, now()));
    if v_late <= (v_rules ->> 'late_grace_minutes')::int then v_late := 0; end if;
  end if;
  v_start := coalesce(v_shift.start_at, now());

  begin
    insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, in_source, review_reason, note)
    values (p_branch, v_user, coalesce(public.staff_display_name(v_user), ''), v_shift.id, now(), 'self',
            case when v_shift.id is null then 'unscheduled' end, nullif(btrim(p_note), ''))
    returning id into v_id;
  exception when unique_violation then
    raise exception 'already clocked in' using errcode = 'P0001', hint = 'already_in';
  end;

  return jsonb_strip_nulls(jsonb_build_object(
    'entry_id', v_id, 'assignment_id', v_shift.id, 'shift_name', v_shift.name, 'late_minutes', v_late,
    'warning', case when public.shift_on_leave(v_user, v_start) then 'on_leave' end));
end;
$$;

create or replace function public.clock_out(p_note text default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user  uuid := (select auth.uid());
  v_entry public.time_entries;
  v_shift public.shift_assignments;
  v_rules jsonb;
  v_worked integer;
  v_early  integer := 0;
  v_over   integer := 0;
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'forbidden';
  end if;
  perform public.close_stale_entries(v_user);

  select * into v_entry from public.time_entries where user_id = v_user and check_out_at is null for update;
  if not found then
    raise exception 'not clocked in' using errcode = 'P0001', hint = 'not_in';
  end if;

  update public.time_entries
  set check_out_at = greatest(now(), check_in_at), out_source = 'self',
      note = coalesce(nullif(btrim(p_note), ''), note)
  where id = v_entry.id
  returning * into v_entry;

  v_rules := public.attendance_rules_raw(v_entry.branch_id);
  select * into v_shift from public.shift_assignments where id = v_entry.assignment_id;
  v_worked := greatest(0, public.minutes_between(v_entry.check_in_at, v_entry.check_out_at) - coalesce(v_shift.break_minutes, 0));
  if v_shift.id is not null then
    v_early := greatest(0, public.minutes_between(v_entry.check_out_at, v_shift.end_at));
    if v_early <= (v_rules ->> 'early_grace_minutes')::int then v_early := 0; end if;
    v_over := greatest(0, public.minutes_between(v_shift.end_at, v_entry.check_out_at));
    if v_over < (v_rules ->> 'overtime_min_minutes')::int then v_over := 0; end if;
  end if;

  return jsonb_build_object('entry_id', v_entry.id, 'worked_minutes', v_worked,
                            'early_minutes', v_early, 'overtime_minutes', v_over);
end;
$$;

-- --------------------------------------------------------- corrections by a manager
-- Shared checks of add/edit/delete: reason, permission at the branch, not your own entry.
create or replace function public.check_entry_edit(p_branch uuid, p_user uuid, p_method text, p_reason text) returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_attendance(p_method, p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  if p_user = (select auth.uid()) and not coalesce((select public.is_super_admin()), false) then
    raise exception 'you cannot change your own time entry' using errcode = 'P0001', hint = 'own_entry';
  end if;
end;
$$;

revoke all on function public.check_entry_edit(uuid, uuid, text, text) from public, anon, authenticated;

-- The times must be in the past and in order.
create or replace function public.check_entry_times(p_in timestamptz, p_out timestamptz) returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if p_in is null or (p_out is not null and p_out < p_in) or p_in > now() or (p_out is not null and p_out > now()) then
    raise exception 'times must be in the past and in order' using errcode = '22023', hint = 'future_time';
  end if;
  if p_out is not null and p_out - p_in > interval '24 hours' then
    raise exception 'an entry lasts 24 hours at most' using errcode = '22023', hint = 'bad_input';
  end if;
end;
$$;

revoke all on function public.check_entry_times(timestamptz, timestamptz) from public, anon, authenticated;

-- The shift an entry is attached to must be the person's, at the branch, and free.
create or replace function public.check_entry_shift(p_assignment uuid, p_branch uuid, p_user uuid, p_entry uuid) returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_assignment is null then return; end if;
  if not exists (select 1 from public.shift_assignments where id = p_assignment and branch_id = p_branch and user_id = p_user) then
    raise exception 'shift not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if exists (select 1 from public.time_entries where assignment_id = p_assignment and id is distinct from p_entry) then
    raise exception 'this shift already has a clock-in' using errcode = 'P0001', hint = 'has_entry';
  end if;
end;
$$;

revoke all on function public.check_entry_shift(uuid, uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.add_time_entry(
  p_branch uuid, p_user uuid, p_in timestamptz, p_out timestamptz, p_assignment uuid, p_reason text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_row public.time_entries;
begin
  perform public.check_entry_edit(p_branch, p_user, 'UPDATE', p_reason);
  if not exists (select 1 from public.staff_branches where user_id = p_user and branch_id = p_branch) then
    raise exception 'this person does not work at the branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  perform public.check_entry_times(p_in, p_out);
  perform public.check_entry_shift(p_assignment, p_branch, p_user, null);

  begin
    insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, check_out_at, in_source, out_source)
    values (p_branch, p_user, coalesce(public.staff_display_name(p_user), ''), p_assignment, p_in, p_out, 'manager',
            case when p_out is null then null else 'manager' end)
    returning * into v_row;
  exception when unique_violation then
    raise exception 'this person is already clocked in' using errcode = 'P0001', hint = 'already_in';
  end;
  v_id := v_row.id;
  perform public.log_time_entry_change(v_id, p_branch, p_user, 'create', null, public.time_entry_snapshot(v_row), p_reason);
  return v_id;
end;
$$;

create or replace function public.edit_time_entry(
  p_id uuid, p_in timestamptz, p_out timestamptz, p_assignment uuid, p_reason text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.time_entries;
  v_new public.time_entries;
begin
  select * into v_old from public.time_entries where id = p_id for update;
  if not found then
    raise exception 'time entry not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  perform public.check_entry_edit(v_old.branch_id, v_old.user_id, 'UPDATE', p_reason);
  perform public.check_entry_times(p_in, p_out);
  perform public.check_entry_shift(p_assignment, v_old.branch_id, v_old.user_id, p_id);

  begin
    update public.time_entries
    set check_in_at = p_in, check_out_at = p_out, assignment_id = p_assignment,
        out_source = case when p_out is null then null else 'manager' end,
        review_reason = null, reviewed_by = null, reviewed_at = null
    where id = p_id
    returning * into v_new;
  exception when unique_violation then
    raise exception 'this person is already clocked in' using errcode = 'P0001', hint = 'already_in';
  end;
  perform public.log_time_entry_change(p_id, v_old.branch_id, v_old.user_id, 'update',
                                       public.time_entry_snapshot(v_old), public.time_entry_snapshot(v_new), p_reason);
end;
$$;

create or replace function public.delete_time_entry(p_id uuid, p_reason text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old public.time_entries;
begin
  select * into v_old from public.time_entries where id = p_id for update;
  if not found then
    raise exception 'time entry not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  perform public.check_entry_edit(v_old.branch_id, v_old.user_id, 'DELETE', p_reason);
  delete from public.time_entries where id = p_id;
  perform public.log_time_entry_change(p_id, v_old.branch_id, v_old.user_id, 'delete',
                                       public.time_entry_snapshot(v_old), null, p_reason);
end;
$$;

-- "Seen": the flag stays on the entry but it leaves the review queue.
create or replace function public.mark_entry_reviewed(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from public.time_entries where id = p_id;
  if v_branch is null then
    raise exception 'time entry not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if not public.can_attendance('UPDATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  update public.time_entries set reviewed_by = (select auth.uid()), reviewed_at = now() where id = p_id;
end;
$$;

-- The change log of an entry (still readable after the entry was deleted), newest first.
create or replace function public.time_entry_history(p_id uuid) returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  return query
    select jsonb_build_object(
      'id', c.id, 'action', c.action, 'before', c."before", 'after', c."after", 'reason', c.reason,
      'changed_by_name', c.changed_by_name, 'changed_at', c.changed_at)
    from public.time_entry_changes c
    where c.entry_id = p_id
      and (c.user_id = (select auth.uid()) or public.can_attendance('VIEW', c.branch_id))
    order by c.changed_at desc, c.id;
end;
$$;

-- ------------------------------------------------------ attendance rows (reports)
-- One row per scheduled shift and one per entry without a shift, for the given branches and days.
-- The numbers follow section 7 of the plan; screens only show them. Not callable by clients:
-- the screens' functions check the permission and pass the branch list.
create or replace function public.attendance_rows(
  p_branch_ids uuid[], p_from date, p_to date, p_user uuid default null
) returns table (
  branch_id uuid, user_id uuid, user_name text, work_date date, assignment_id uuid, entry_id uuid,
  shift_name text, start_at timestamptz, end_at timestamptz, check_in_at timestamptz, check_out_at timestamptz,
  scheduled_minutes integer, worked_minutes integer, late_minutes integer, early_minutes integer,
  overtime_minutes integer, status text, leave_type text, review_reason text, reviewed boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with base as (
    select a.branch_id, a.user_id, a.work_date, a.id as assignment_id, a.name as shift_name, a.start_at, a.end_at,
           a.break_minutes, e.id as entry_id, e.check_in_at, e.check_out_at, e.review_reason, e.reviewed_at
    from public.shift_assignments a
    left join public.time_entries e on e.assignment_id = a.id
    where a.branch_id = any (p_branch_ids) and a.work_date between p_from and p_to
      and (p_user is null or a.user_id = p_user)
    union all
    select e.branch_id, e.user_id, e.work_date, null, null, null, null, 0,
           e.id, e.check_in_at, e.check_out_at, e.review_reason, e.reviewed_at
    from public.time_entries e
    where e.assignment_id is null and e.branch_id = any (p_branch_ids) and e.work_date between p_from and p_to
      and (p_user is null or e.user_id = p_user)
  ), step as (
    select b.*, public.attendance_rules_raw(b.branch_id) as rules,
           public.leave_type_on(b.user_id, coalesce(b.start_at, b.check_in_at)) as leave_type
    from base b
  ), calc as (
    select s.*,
      case when s.start_at is null then 0 else greatest(0, public.minutes_between(s.start_at, s.end_at) - s.break_minutes) end as scheduled_minutes,
      case when s.check_out_at is null then 0
           else greatest(0, public.minutes_between(s.check_in_at, s.check_out_at) - s.break_minutes) end as worked_minutes,
      case when s.start_at is null or s.check_in_at is null then 0
           when public.minutes_between(s.start_at, s.check_in_at) > (s.rules ->> 'late_grace_minutes')::int
             then public.minutes_between(s.start_at, s.check_in_at) else 0 end as late_minutes,
      case when s.end_at is null or s.check_out_at is null or s.review_reason = 'missing_checkout' then 0
           when public.minutes_between(s.check_out_at, s.end_at) > (s.rules ->> 'early_grace_minutes')::int
             then public.minutes_between(s.check_out_at, s.end_at) else 0 end as early_minutes,
      case when s.end_at is null or s.check_out_at is null or s.review_reason = 'missing_checkout' then 0
           when public.minutes_between(s.end_at, s.check_out_at) >= greatest(1, (s.rules ->> 'overtime_min_minutes')::int)
             then public.minutes_between(s.end_at, s.check_out_at) else 0 end as overtime_minutes
    from step s
  )
  select c.branch_id, c.user_id, public.staff_display_name(c.user_id), c.work_date, c.assignment_id, c.entry_id,
         c.shift_name, c.start_at, c.end_at, c.check_in_at, c.check_out_at,
         c.scheduled_minutes, c.worked_minutes, c.late_minutes, c.early_minutes, c.overtime_minutes,
         case
           when c.leave_type is not null then 'leave'
           when c.review_reason = 'missing_checkout' then 'missing_checkout'
           when c.entry_id is not null and c.check_out_at is null then 'working'
           when c.entry_id is not null and c.assignment_id is null then 'unscheduled'
           when c.entry_id is not null and c.late_minutes > 0 and c.early_minutes > 0 then 'late_early'
           when c.entry_id is not null and c.late_minutes > 0 then 'late'
           when c.entry_id is not null and c.early_minutes > 0 then 'early'
           when c.entry_id is not null then 'present'
           when c.end_at < now() then 'absent'
           when c.start_at <= now() then 'not_in'
           else 'upcoming'
         end,
         c.leave_type, c.review_reason, c.reviewed_at is not null
  from calc c;
$$;

revoke all on function public.attendance_rows(uuid[], date, date, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------- screens' reads
-- The "today" board of one branch: staff, the day's rows, leave, and the entries to review.
create or replace function public.attendance_today(p_branch uuid, p_date date default null) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_date date := coalesce(p_date, public.boarding_local_date(now()));
begin
  if not public.can_attendance('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;

  return jsonb_build_object(
    'date', v_date,
    'staff', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', sb.user_id, 'name', public.staff_display_name(sb.user_id), 'role', sb.role, 'photo_url', u.photo_url)
        order by public.staff_display_name(sb.user_id))
      from public.staff_branches sb join public.users u on u.id = sb.user_id
      where sb.branch_id = p_branch), '[]'::jsonb),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.start_at nulls last, r.check_in_at)
      from public.attendance_rows(array[p_branch], v_date, v_date) r), '[]'::jsonb),
    'leaves', public.branch_leaves_on(p_branch, v_date),
    'review', coalesce((
      select jsonb_agg(jsonb_build_object(
        'entry_id', e.id, 'user_id', e.user_id, 'user_name', e.user_name, 'work_date', e.work_date,
        'check_in_at', e.check_in_at, 'check_out_at', e.check_out_at, 'review_reason', e.review_reason)
        order by e.check_in_at desc)
      from (select * from public.time_entries
            where branch_id = p_branch and review_reason is not null and reviewed_at is null
              and work_date >= v_date - 30
            order by check_in_at desc limit 50) e), '[]'::jsonb)
  );
end;
$$;

-- The caller's own schedule and entries (every branch), for the "mine" page.
create or replace function public.my_schedule(p_from date, p_to date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
begin
  if v_user is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from + 1 > 93 then
    raise exception 'date range is longer than 93 days' using errcode = '22023', hint = 'range_too_long';
  end if;

  return jsonb_build_object(
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'branch_id', a.branch_id, 'branch_name', b.name, 'work_date', a.work_date, 'name', a.name,
        'start_at', a.start_at, 'end_at', a.end_at, 'break_minutes', a.break_minutes, 'note', a.note,
        'has_entry', public.assignment_has_entry(a.id)) order by a.start_at)
      from public.shift_assignments a join public.branches b on b.id = a.branch_id
      where a.user_id = v_user and a.work_date between p_from and p_to), '[]'::jsonb),
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id, 'branch_id', e.branch_id, 'branch_name', b.name, 'work_date', e.work_date,
        'assignment_id', e.assignment_id, 'check_in_at', e.check_in_at, 'check_out_at', e.check_out_at,
        'review_reason', e.review_reason) order by e.check_in_at)
      from public.time_entries e join public.branches b on b.id = e.branch_id
      where e.user_id = v_user and e.work_date between p_from and p_to), '[]'::jsonb),
    'leaves', public.my_leaves(p_from, p_to)
  );
end;
$$;

revoke all on function public.clock_status() from public, anon;
revoke all on function public.clock_in(uuid, text, boolean) from public, anon;
revoke all on function public.clock_out(text) from public, anon;
revoke all on function public.add_time_entry(uuid, uuid, timestamptz, timestamptz, uuid, text) from public, anon;
revoke all on function public.edit_time_entry(uuid, timestamptz, timestamptz, uuid, text) from public, anon;
revoke all on function public.delete_time_entry(uuid, text) from public, anon;
revoke all on function public.mark_entry_reviewed(uuid) from public, anon;
revoke all on function public.time_entry_history(uuid) from public, anon;
revoke all on function public.attendance_today(uuid, date) from public, anon;
revoke all on function public.my_schedule(date, date) from public, anon;
grant execute on function public.clock_status() to authenticated;
grant execute on function public.clock_in(uuid, text, boolean) to authenticated;
grant execute on function public.clock_out(text) to authenticated;
grant execute on function public.add_time_entry(uuid, uuid, timestamptz, timestamptz, uuid, text) to authenticated;
grant execute on function public.edit_time_entry(uuid, timestamptz, timestamptz, uuid, text) to authenticated;
grant execute on function public.delete_time_entry(uuid, text) to authenticated;
grant execute on function public.mark_entry_reviewed(uuid) to authenticated;
grant execute on function public.time_entry_history(uuid) to authenticated;
grant execute on function public.attendance_today(uuid, date) to authenticated;
grant execute on function public.my_schedule(date, date) to authenticated;

notify pgrst, 'reload schema';
