-- Staff attendance, step 1 (docs: ke-hoach-cham-cong.md, sections 5.1-5.3, 6 and 8.1): the
-- "attendance" permission, branch settings, shift templates and the roster. Safe to run more than once.
--
-- Every write goes through a security definer RPC; tables only grant SELECT with a policy as the
-- second line of defence. Errors carry an errcode and a `hint` that the app maps to a message.

-- --------------------------------------------------------------- permission
insert into public.permissions (name, description, methods, module, sort_order) values
  ('attendance', 'Nhân sự: lịch ca, chấm công, nghỉ phép, bảng công',
   array['CREATE','VIEW','DELETE','UPDATE','EXPORT','SETTING','ALL'], 'Nhân sự', 70)
on conflict (name) do nothing;

insert into public.role_permissions (role, permission, methods)
select r.role, r.permission, r.methods
from (values
  ('admin', 'attendance', array['ALL'])
) as r(role, permission, methods)
where exists (select 1 from public.roles where name = r.role)
on conflict do nothing;

-- p_branch is required: has_permission(..., null) means "at any branch" and must never be trusted.
create or replace function public.can_attendance(p_method text, p_branch uuid) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (p_branch is not null and (select public.has_permission('attendance', p_method, p_branch)));
$$;

revoke execute on function public.can_attendance(text, uuid) from public, anon;
grant execute on function public.can_attendance(text, uuid) to authenticated;

-- The caller has a row in staff_branches for this branch (self service needs nothing more).
create or replace function public.is_branch_staff(p_branch uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_branch is not null and exists (
    select 1 from public.staff_branches sb
    where sb.user_id = (select auth.uid()) and sb.branch_id = p_branch
  );
$$;

revoke execute on function public.is_branch_staff(uuid) from public, anon;
grant execute on function public.is_branch_staff(uuid) to authenticated;

-- The branches an attendance report covers: p_branch when given (the caller must hold the
-- permission there), otherwise every branch where the caller holds it. Never has_permission(null).
create or replace function public.attendance_branch_ids(p_branch uuid, p_method text default 'VIEW') returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
begin
  if p_branch is not null then
    if not public.can_attendance(p_method, p_branch) then
      raise exception 'not allowed at this branch' using errcode = '42501', hint = 'forbidden';
    end if;
    return array[p_branch];
  end if;

  select coalesce(array_agg(b.id), '{}') into v_ids
  from public.branches b
  where public.can_attendance(p_method, b.id);

  if cardinality(v_ids) = 0 then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return v_ids;
end;
$$;

revoke execute on function public.attendance_branch_ids(uuid, text) from public, anon, authenticated;

-- ------------------------------------------------------------------- tables
create table if not exists public.attendance_settings (
  branch_id            uuid primary key references public.branches (id) on delete cascade,
  late_grace_minutes   integer not null default 5   check (late_grace_minutes between 0 and 60),
  early_grace_minutes  integer not null default 5   check (early_grace_minutes between 0 and 60),
  checkin_early_minutes integer not null default 60 check (checkin_early_minutes between 0 and 240),
  overtime_min_minutes integer not null default 30  check (overtime_min_minutes between 0 and 240),
  allow_unscheduled    boolean not null default true,
  review_after_hours   integer not null default 16  check (review_after_hours between 4 and 24),
  updated_at           timestamptz not null default now(),
  updated_by           uuid references public.users (id) on delete set null
);

create table if not exists public.shift_templates (
  id            uuid primary key default gen_random_uuid(),
  branch_id     uuid not null references public.branches (id) on delete cascade,
  name          text not null check (length(btrim(name)) between 1 and 40),
  start_time    time not null,
  end_time      time not null,
  break_minutes integer not null default 0 check (break_minutes between 0 and 960),
  color         text not null default 'teal' check (color in ('teal', 'sky', 'amber', 'rose', 'violet', 'slate')),
  is_active     boolean not null default true,
  sort_order    integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint shift_templates_times_differ check (end_time <> start_time)
);
create unique index if not exists shift_templates_branch_name_idx on public.shift_templates (branch_id, lower(name));

create table if not exists public.shift_assignments (
  id            uuid primary key default gen_random_uuid(),
  branch_id     uuid not null references public.branches (id) on delete restrict,
  user_id       uuid not null references public.users (id) on delete restrict,
  work_date     date not null,
  template_id   uuid references public.shift_templates (id) on delete set null,
  name          text not null check (length(btrim(name)) between 1 and 40),
  start_at      timestamptz not null,
  end_at        timestamptz not null,
  break_minutes integer not null default 0 check (break_minutes >= 0),
  note          text check (note is null or length(note) <= 300),
  created_by    uuid references public.users (id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint shift_assignments_span check (
    end_at > start_at and end_at - start_at <= interval '16 hours'
  ),
  -- One person cannot be in two places: no overlap across any branch.
  constraint shift_assignments_no_overlap exclude using gist (
    user_id with =, tstzrange(start_at, end_at, '[)') with &&
  )
);
create index if not exists shift_assignments_branch_date_idx on public.shift_assignments (branch_id, work_date);
create index if not exists shift_assignments_user_date_idx on public.shift_assignments (user_id, work_date);

drop trigger if exists attendance_settings_updated_at on public.attendance_settings;
create trigger attendance_settings_updated_at before update on public.attendance_settings
  for each row execute function public.set_updated_at();
drop trigger if exists shift_templates_updated_at on public.shift_templates;
create trigger shift_templates_updated_at before update on public.shift_templates
  for each row execute function public.set_updated_at();
drop trigger if exists shift_assignments_updated_at on public.shift_assignments;
create trigger shift_assignments_updated_at before update on public.shift_assignments
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------- security
alter table public.attendance_settings enable row level security;
alter table public.shift_templates enable row level security;
alter table public.shift_assignments enable row level security;

revoke all on public.attendance_settings, public.shift_templates, public.shift_assignments from anon, authenticated;
grant select on public.attendance_settings, public.shift_templates, public.shift_assignments to authenticated;

drop policy if exists "attendance settings read" on public.attendance_settings;
create policy "attendance settings read" on public.attendance_settings
  for select to authenticated
  using ((select public.is_branch_staff(branch_id)) or (select public.can_attendance('VIEW', branch_id)));

drop policy if exists "shift templates read" on public.shift_templates;
create policy "shift templates read" on public.shift_templates
  for select to authenticated
  using ((select public.is_branch_staff(branch_id)) or (select public.can_attendance('VIEW', branch_id)));

drop policy if exists "shift assignments read" on public.shift_assignments;
create policy "shift assignments read" on public.shift_assignments
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_attendance('VIEW', branch_id)));

-- ------------------------------------------------------------------ helpers
-- Settings merged with the defaults; for functions that already checked the caller (and for cron).
create or replace function public.attendance_rules_raw(p_branch uuid) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'late_grace_minutes',    coalesce(s.late_grace_minutes, 5),
    'early_grace_minutes',   coalesce(s.early_grace_minutes, 5),
    'checkin_early_minutes', coalesce(s.checkin_early_minutes, 60),
    'overtime_min_minutes',  coalesce(s.overtime_min_minutes, 30),
    'allow_unscheduled',     coalesce(s.allow_unscheduled, true),
    'review_after_hours',    coalesce(s.review_after_hours, 16)
  )
  from (select 1) d
  left join public.attendance_settings s on s.branch_id = p_branch;
$$;

revoke all on function public.attendance_rules_raw(uuid) from public, anon, authenticated;

create or replace function public.attendance_rules(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.is_branch_staff(p_branch) or public.can_attendance('VIEW', p_branch)) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return public.attendance_rules_raw(p_branch);
end;
$$;

revoke all on function public.attendance_rules(uuid) from public, anon;
grant execute on function public.attendance_rules(uuid) to authenticated;

-- Start and end instants of a shift that starts on p_date at p_start; an end at or before the
-- start means the next morning. Vietnam time has no daylight saving.
create or replace function public.shift_start_at(p_date date, p_start time) returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select (p_date + p_start) at time zone 'Asia/Ho_Chi_Minh';
$$;

create or replace function public.shift_end_at(p_date date, p_start time, p_end time) returns timestamptz
language sql
immutable
set search_path = ''
as $$
  select (p_date + (case when p_end <= p_start then 1 else 0 end) + p_end) at time zone 'Asia/Ho_Chi_Minh';
$$;

-- Length of a shift in minutes, overnight aware.
create or replace function public.shift_minutes(p_start time, p_end time) returns integer
language sql
immutable
set search_path = ''
as $$
  select (extract(epoch from (p_end - p_start)) / 60)::int + case when p_end <= p_start then 1440 else 0 end;
$$;

revoke all on function public.shift_start_at(date, time) from public, anon, authenticated;
revoke all on function public.shift_end_at(date, time, time) from public, anon, authenticated;
revoke all on function public.shift_minutes(time, time) from public, anon, authenticated;

-- Placeholders that later migrations replace once their tables exist (time entries, leave).
create or replace function public.assignment_has_entry(p_assignment uuid) returns boolean
language sql
stable
set search_path = ''
as $$ select false; $$;

create or replace function public.shift_on_leave(p_user uuid, p_start_at timestamptz) returns boolean
language sql
stable
set search_path = ''
as $$ select false; $$;

revoke all on function public.assignment_has_entry(uuid) from public, anon, authenticated;
revoke all on function public.shift_on_leave(uuid, timestamptz) from public, anon, authenticated;

-- ----------------------------------------------------------------- settings
create or replace function public.save_attendance_settings(p_branch uuid, p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cur jsonb;
begin
  if not public.can_attendance('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if not exists (select 1 from public.branches where id = p_branch) or jsonb_typeof(p) is distinct from 'object' then
    raise exception 'bad settings' using errcode = '22023', hint = 'bad_input';
  end if;

  v_cur := public.attendance_rules_raw(p_branch);
  begin
    insert into public.attendance_settings (
      branch_id, late_grace_minutes, early_grace_minutes, checkin_early_minutes,
      overtime_min_minutes, allow_unscheduled, review_after_hours, updated_by
    ) values (
      p_branch,
      coalesce((p ->> 'late_grace_minutes')::int,    (v_cur ->> 'late_grace_minutes')::int),
      coalesce((p ->> 'early_grace_minutes')::int,   (v_cur ->> 'early_grace_minutes')::int),
      coalesce((p ->> 'checkin_early_minutes')::int, (v_cur ->> 'checkin_early_minutes')::int),
      coalesce((p ->> 'overtime_min_minutes')::int,  (v_cur ->> 'overtime_min_minutes')::int),
      coalesce((p ->> 'allow_unscheduled')::boolean, (v_cur ->> 'allow_unscheduled')::boolean),
      coalesce((p ->> 'review_after_hours')::int,    (v_cur ->> 'review_after_hours')::int),
      (select auth.uid())
    )
    on conflict (branch_id) do update set
      late_grace_minutes    = excluded.late_grace_minutes,
      early_grace_minutes   = excluded.early_grace_minutes,
      checkin_early_minutes = excluded.checkin_early_minutes,
      overtime_min_minutes  = excluded.overtime_min_minutes,
      allow_unscheduled     = excluded.allow_unscheduled,
      review_after_hours    = excluded.review_after_hours,
      updated_by            = excluded.updated_by;
  exception when invalid_text_representation or check_violation or numeric_value_out_of_range then
    raise exception 'settings out of range' using errcode = '22023', hint = 'bad_input';
  end;
  return public.attendance_rules_raw(p_branch);
end;
$$;

revoke all on function public.save_attendance_settings(uuid, jsonb) from public, anon;
grant execute on function public.save_attendance_settings(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------- shift templates
create or replace function public.list_shift_templates(p_branch uuid, p_include_inactive boolean default false)
returns setof jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.is_branch_staff(p_branch) or public.can_attendance('VIEW', p_branch)) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return query
    select jsonb_build_object(
      'id', t.id, 'branch_id', t.branch_id, 'name', t.name,
      'start_time', to_char(t.start_time, 'HH24:MI'), 'end_time', to_char(t.end_time, 'HH24:MI'),
      'break_minutes', t.break_minutes, 'color', t.color, 'is_active', t.is_active,
      'sort_order', t.sort_order, 'overnight', t.end_time < t.start_time)
    from public.shift_templates t
    where t.branch_id = p_branch and (p_include_inactive or t.is_active)
    order by t.sort_order, t.start_time, t.name;
end;
$$;

revoke all on function public.list_shift_templates(uuid, boolean) from public, anon;
grant execute on function public.list_shift_templates(uuid, boolean) to authenticated;

create or replace function public.save_shift_template(p_branch uuid, p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id    uuid;
  v_name  text;
  v_start time;
  v_end   time;
  v_break int;
begin
  if not public.can_attendance('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'bad template' using errcode = '22023', hint = 'bad_input';
  end if;

  begin
    v_id    := nullif(p ->> 'id', '')::uuid;
    v_name  := btrim(coalesce(p ->> 'name', ''));
    v_start := (p ->> 'start_time')::time;
    v_end   := (p ->> 'end_time')::time;
    v_break := coalesce((p ->> 'break_minutes')::int, 0);
  exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format then
    raise exception 'bad template' using errcode = '22023', hint = 'bad_input';
  end;
  if length(v_name) not between 1 and 40 or v_start is null or v_end is null or v_start = v_end
     or v_break < 0 or v_break >= public.shift_minutes(v_start, v_end)
     or public.shift_minutes(v_start, v_end) > 960 then
    raise exception 'bad template' using errcode = '22023', hint = 'bad_input';
  end if;

  begin
    if v_id is null then
      insert into public.shift_templates (branch_id, name, start_time, end_time, break_minutes, color, sort_order)
      values (p_branch, v_name, v_start, v_end, v_break,
              coalesce(p ->> 'color', 'teal'), coalesce((p ->> 'sort_order')::int, 0))
      returning id into v_id;
    else
      update public.shift_templates set
        name = v_name, start_time = v_start, end_time = v_end, break_minutes = v_break,
        color = coalesce(p ->> 'color', color), sort_order = coalesce((p ->> 'sort_order')::int, sort_order)
      where id = v_id and branch_id = p_branch;
      if not found then
        raise exception 'template not found' using errcode = 'P0001', hint = 'not_found';
      end if;
    end if;
  exception
    when unique_violation then
      raise exception 'a shift with this name exists' using errcode = 'P0001', hint = 'name_taken';
    when check_violation then
      raise exception 'bad template' using errcode = '22023', hint = 'bad_input';
  end;
  return v_id;
end;
$$;

create or replace function public.set_shift_template_active(p_id uuid, p_active boolean) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from public.shift_templates where id = p_id;
  if v_branch is null then
    raise exception 'template not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if not public.can_attendance('SETTING', v_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  update public.shift_templates set is_active = coalesce(p_active, true) where id = p_id;
end;
$$;

revoke all on function public.save_shift_template(uuid, jsonb) from public, anon;
revoke all on function public.set_shift_template_active(uuid, boolean) from public, anon;
grant execute on function public.save_shift_template(uuid, jsonb) to authenticated;
grant execute on function public.set_shift_template_active(uuid, boolean) to authenticated;

-- ------------------------------------------------------------- the roster
-- Put one person on a shift. A template gives the times; without one p_start and p_end are required.
-- Returns {id, warning?}; warning "on_leave" when the person has approved leave then.
create or replace function public.assign_shift(
  p_branch uuid, p_user uuid, p_date date, p_template uuid,
  p_start time default null, p_end time default null, p_break integer default null, p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tpl    public.shift_templates;
  v_name   text;
  v_start  time := p_start;
  v_end    time := p_end;
  v_break  int := p_break;
  v_start_at timestamptz;
  v_id     uuid;
begin
  if not public.can_attendance('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_user is null or p_date is null then
    raise exception 'user and date are required' using errcode = '22023', hint = 'bad_input';
  end if;
  if not exists (select 1 from public.staff_branches where user_id = p_user and branch_id = p_branch) then
    raise exception 'this person does not work at the branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;

  if p_template is not null then
    select * into v_tpl from public.shift_templates where id = p_template and branch_id = p_branch and is_active;
    if not found then
      raise exception 'template not found' using errcode = 'P0001', hint = 'not_found';
    end if;
    v_name := v_tpl.name;
    v_start := v_tpl.start_time;
    v_end := v_tpl.end_time;
    v_break := coalesce(p_break, v_tpl.break_minutes);
  else
    if v_start is null or v_end is null or v_start = v_end then
      raise exception 'start and end are required' using errcode = '22023', hint = 'bad_input';
    end if;
    v_name := 'Tùy chỉnh';
    v_break := coalesce(v_break, 0);
  end if;
  if v_break < 0 or v_break >= public.shift_minutes(v_start, v_end) or public.shift_minutes(v_start, v_end) > 960 then
    raise exception 'bad shift length' using errcode = '22023', hint = 'bad_input';
  end if;

  v_start_at := public.shift_start_at(p_date, v_start);
  begin
    insert into public.shift_assignments (
      branch_id, user_id, work_date, template_id, name, start_at, end_at, break_minutes, note, created_by
    ) values (
      p_branch, p_user, p_date, p_template, v_name, v_start_at,
      public.shift_end_at(p_date, v_start, v_end), v_break, nullif(btrim(p_note), ''), (select auth.uid())
    ) returning id into v_id;
  exception
    when exclusion_violation then
      raise exception 'this person already has a shift at that time' using errcode = 'P0001', hint = 'shift_overlap';
    when check_violation then
      raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end;

  return jsonb_strip_nulls(jsonb_build_object(
    'id', v_id,
    'warning', case when public.shift_on_leave(p_user, v_start_at) then 'on_leave' end
  ));
end;
$$;

-- Change a shift: p may hold template_id, start_time, end_time, break_minutes, note, work_date.
-- A shift that already has a clock-in only lets the note change.
create or replace function public.update_shift_assignment(p_id uuid, p jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row    public.shift_assignments;
  v_tpl    public.shift_templates;
  v_date   date;
  v_start  time;
  v_end    time;
  v_break  int;
  v_name   text;
  v_tpl_id uuid;
  v_note   text;
begin
  select * into v_row from public.shift_assignments where id = p_id;
  if not found then
    raise exception 'shift not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if not public.can_attendance('UPDATE', v_row.branch_id) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end if;

  v_note := case when p ? 'note' then nullif(btrim(p ->> 'note'), '') else v_row.note end;
  if public.assignment_has_entry(p_id) then
    if p ?| array['template_id', 'start_time', 'end_time', 'break_minutes', 'work_date'] then
      raise exception 'this shift already has a clock-in' using errcode = 'P0001', hint = 'has_entry';
    end if;
    update public.shift_assignments set note = v_note where id = p_id;
    return;
  end if;

  begin
    v_date := coalesce((p ->> 'work_date')::date, v_row.work_date);
    v_tpl_id := case when p ? 'template_id' then nullif(p ->> 'template_id', '')::uuid else v_row.template_id end;
    v_start := coalesce((p ->> 'start_time')::time, (v_row.start_at at time zone 'Asia/Ho_Chi_Minh')::time);
    v_end := coalesce((p ->> 'end_time')::time, (v_row.end_at at time zone 'Asia/Ho_Chi_Minh')::time);
    v_break := coalesce((p ->> 'break_minutes')::int, v_row.break_minutes);
  exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format then
    raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end;
  v_name := v_row.name;

  if p ? 'template_id' and v_tpl_id is not null then
    select * into v_tpl from public.shift_templates where id = v_tpl_id and branch_id = v_row.branch_id and is_active;
    if not found then
      raise exception 'template not found' using errcode = 'P0001', hint = 'not_found';
    end if;
    v_name := v_tpl.name;
    if not (p ? 'start_time') then v_start := v_tpl.start_time; end if;
    if not (p ? 'end_time') then v_end := v_tpl.end_time; end if;
    if not (p ? 'break_minutes') then v_break := v_tpl.break_minutes; end if;
  elsif p ? 'template_id' then
    v_name := 'Tùy chỉnh';
  end if;

  if v_start = v_end or v_break < 0 or v_break >= public.shift_minutes(v_start, v_end)
     or public.shift_minutes(v_start, v_end) > 960 then
    raise exception 'bad shift length' using errcode = '22023', hint = 'bad_input';
  end if;

  begin
    update public.shift_assignments set
      work_date = v_date, template_id = v_tpl_id, name = v_name,
      start_at = public.shift_start_at(v_date, v_start), end_at = public.shift_end_at(v_date, v_start, v_end),
      break_minutes = v_break, note = v_note
    where id = p_id;
  exception
    when exclusion_violation then
      raise exception 'this person already has a shift at that time' using errcode = 'P0001', hint = 'shift_overlap';
    when check_violation then
      raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end;
end;
$$;

create or replace function public.remove_shift_assignment(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from public.shift_assignments where id = p_id;
  if v_branch is null then
    raise exception 'shift not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if not public.can_attendance('DELETE', v_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if public.assignment_has_entry(p_id) then
    raise exception 'this shift already has a clock-in' using errcode = 'P0001', hint = 'has_entry';
  end if;
  delete from public.shift_assignments where id = p_id;
end;
$$;

-- Copy one week of shifts to another week (both start on a Monday). People who left the branch,
-- cells that already have a shift (unless p_overwrite) and clashes are skipped.
create or replace function public.copy_roster_week(
  p_branch uuid, p_from_monday date, p_to_monday date, p_overwrite boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r        public.shift_assignments;
  v_shift  int;
  v_copied int := 0;
  v_skipped int := 0;
begin
  if not public.can_attendance('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_from_monday is null or p_to_monday is null or p_from_monday = p_to_monday
     or extract(isodow from p_from_monday) <> 1 or extract(isodow from p_to_monday) <> 1 then
    raise exception 'both dates must be different Mondays' using errcode = '22023', hint = 'bad_input';
  end if;
  v_shift := p_to_monday - p_from_monday;

  for r in
    select * from public.shift_assignments
    where branch_id = p_branch and work_date >= p_from_monday and work_date < p_from_monday + 7
    order by start_at
  loop
    if not exists (select 1 from public.staff_branches where user_id = r.user_id and branch_id = p_branch) then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    if exists (select 1 from public.shift_assignments
               where branch_id = p_branch and user_id = r.user_id and work_date = r.work_date + v_shift) then
      if not coalesce(p_overwrite, false) then
        v_skipped := v_skipped + 1;
        continue;
      end if;
      delete from public.shift_assignments a
      where a.branch_id = p_branch and a.user_id = r.user_id and a.work_date = r.work_date + v_shift
        and not public.assignment_has_entry(a.id);
    end if;
    begin
      insert into public.shift_assignments (
        branch_id, user_id, work_date, template_id, name, start_at, end_at, break_minutes, note, created_by
      ) values (
        p_branch, r.user_id, r.work_date + v_shift, r.template_id, r.name,
        ((r.start_at at time zone 'Asia/Ho_Chi_Minh') + v_shift * interval '1 day') at time zone 'Asia/Ho_Chi_Minh',
        ((r.end_at at time zone 'Asia/Ho_Chi_Minh') + v_shift * interval '1 day') at time zone 'Asia/Ho_Chi_Minh',
        r.break_minutes, r.note, (select auth.uid())
      );
      v_copied := v_copied + 1;
    exception when exclusion_violation then
      v_skipped := v_skipped + 1;
    end;
  end loop;
  return jsonb_build_object('copied', v_copied, 'skipped', v_skipped);
end;
$$;

-- Everything the roster grid needs for [p_from, p_to] (at most 42 days) in one call.
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
    'leaves', '[]'::jsonb
  );
end;
$$;

revoke all on function public.assign_shift(uuid, uuid, date, uuid, time, time, integer, text) from public, anon;
revoke all on function public.update_shift_assignment(uuid, jsonb) from public, anon;
revoke all on function public.remove_shift_assignment(uuid) from public, anon;
revoke all on function public.copy_roster_week(uuid, date, date, boolean) from public, anon;
revoke all on function public.shift_roster(uuid, date, date) from public, anon;
grant execute on function public.assign_shift(uuid, uuid, date, uuid, time, time, integer, text) to authenticated;
grant execute on function public.update_shift_assignment(uuid, jsonb) to authenticated;
grant execute on function public.remove_shift_assignment(uuid) to authenticated;
grant execute on function public.copy_roster_week(uuid, date, date, boolean) to authenticated;
grant execute on function public.shift_roster(uuid, date, date) to authenticated;

notify pgrst, 'reload schema';
