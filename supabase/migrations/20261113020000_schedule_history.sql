-- Schedule history: an append-only log of who changed which shift, request and setting, and when.
-- Rows are written by triggers (and by replace_availability), so every path is recorded: RPCs, copy
-- week, bulk approval, cron and the SQL Editor. Nobody can edit or delete a row; clients can only read.

-- Monday of the week a date falls in.
create or replace function public.week_of(p_date date) returns date
language sql
immutable
set search_path = ''
as $$ select p_date - (extract(isodow from p_date)::integer - 1); $$;

-- Whether a branch week was already published when a change happened. The publishing feature
-- (a later migration) replaces this; until then nothing is published.
create or replace function public.history_published_flag(p_branch uuid, p_monday date) returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select false; $$;

revoke all on function public.history_published_flag(uuid, date) from public, anon, authenticated;

create table if not exists public.schedule_history (
  id               bigint      generated always as identity primary key,
  branch_id        uuid        references public.branches (id) on delete cascade,
  week_monday      date,
  entity           text        not null check (entity in ('assignment', 'request', 'week', 'submission', 'settings', 'exemption', 'availability')),
  entity_id        text,
  action           text        not null check (action in (
    'insert', 'update', 'delete', 'submit', 'cancel', 'approve', 'reject', 'publish', 'auto_publish', 'declare_none', 'replace')),
  actor_id         uuid,
  actor_name       text        not null,
  target_user_id   uuid,
  target_user_name text,
  before           jsonb,
  after            jsonb,
  changed_fields   text[]      not null default '{}',
  reason           text        check (reason is null or char_length(reason) <= 300),
  source           text,
  was_published    boolean     not null default false,
  created_at       timestamptz not null default now()
);

create index if not exists schedule_history_week_idx on public.schedule_history (branch_id, week_monday, id desc);
create index if not exists schedule_history_target_idx on public.schedule_history (target_user_id, id desc);
create index if not exists schedule_history_entity_idx on public.schedule_history (entity, entity_id);

alter table public.schedule_history enable row level security;
revoke all on public.schedule_history from anon, authenticated;
grant select on public.schedule_history to authenticated;

drop policy if exists "history read" on public.schedule_history;
create policy "history read" on public.schedule_history
  for select to authenticated using (
    (branch_id is not null and (select public.can_attendance('VIEW', branch_id)))
    or (branch_id is null and target_user_id is not null and (select public.can_view_staff(target_user_id)))
  );

-- The log is append-only, even for the table owner. The one exception is the cascade that removes a
-- branch together with everything that belonged to it.
create or replace function public.schedule_history_guard() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' and old.branch_id is not null
     and not exists (select 1 from public.branches b where b.id = old.branch_id) then
    return old;
  end if;
  raise exception 'schedule_history is append-only' using errcode = '42501', hint = 'forbidden';
end;
$$;

drop trigger if exists schedule_history_no_change on public.schedule_history;
create trigger schedule_history_no_change before update or delete on public.schedule_history
  for each row execute function public.schedule_history_guard();

-- ---------------------------------------------------------------- writer
-- Adds one row. The reason and the name of the RPC come from transaction settings the RPC set
-- (app.schedule_reason, app.schedule_source). Rows of a branch that is being deleted are skipped.
create or replace function public.log_schedule_change(
  p_branch uuid, p_week date, p_entity text, p_entity_id text, p_action text,
  p_target uuid, p_before jsonb, p_after jsonb
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor  uuid := (select auth.uid());
  v_fields text[] := '{}';
begin
  if p_branch is not null and not exists (select 1 from public.branches b where b.id = p_branch) then
    return;
  end if;
  if p_action = 'update' and p_before is not null and p_after is not null then
    select coalesce(array_agg(k order by k), '{}') into v_fields
    from (
      select k from jsonb_object_keys(p_before || p_after) k
      where p_before -> k is distinct from p_after -> k
    ) d;
  end if;

  insert into public.schedule_history (
    branch_id, week_monday, entity, entity_id, action, actor_id, actor_name, target_user_id, target_user_name,
    before, after, changed_fields, reason, source, was_published
  ) values (
    p_branch, p_week, p_entity, p_entity_id, p_action, v_actor,
    case when v_actor is null then 'Hệ thống' else coalesce(public.staff_display_name(v_actor), 'Hệ thống') end,
    p_target, case when p_target is null then null else public.staff_display_name(p_target) end,
    p_before, p_after, v_fields,
    nullif(btrim(coalesce(current_setting('app.schedule_reason', true), '')), ''),
    nullif(btrim(coalesce(current_setting('app.schedule_source', true), '')), ''),
    case when p_branch is not null and p_week is not null then public.history_published_flag(p_branch, p_week) else false end
  );
end;
$$;

revoke all on function public.log_schedule_change(uuid, date, text, text, text, uuid, jsonb, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------- triggers
create or replace function public.trg_log_shift_assignment() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new) - 'updated_at';
    perform public.log_schedule_change(new.branch_id, public.week_of(new.work_date), 'assignment', new.id::text, 'insert', new.user_id, null, v_new);
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old) - 'updated_at';
    v_new := to_jsonb(new) - 'updated_at';
    if v_old is distinct from v_new then
      perform public.log_schedule_change(new.branch_id, public.week_of(new.work_date), 'assignment', new.id::text, 'update', new.user_id, v_old, v_new);
    end if;
  else
    v_old := to_jsonb(old) - 'updated_at';
    perform public.log_schedule_change(old.branch_id, public.week_of(old.work_date), 'assignment', old.id::text, 'delete', old.user_id, v_old, null);
  end if;
  return null;
end;
$$;

revoke all on function public.trg_log_shift_assignment() from public, anon, authenticated;

drop trigger if exists shift_assignments_log on public.shift_assignments;
create trigger shift_assignments_log after insert or update or delete on public.shift_assignments
  for each row execute function public.trg_log_shift_assignment();

create or replace function public.trg_log_shift_request() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action text;
begin
  if tg_op = 'INSERT' then
    v_action := 'submit';
  elsif new.status is distinct from old.status then
    v_action := case new.status when 'cancelled' then 'cancel' when 'approved' then 'approve' when 'rejected' then 'reject' else 'update' end;
  else
    return null;
  end if;
  perform public.log_schedule_change(
    new.branch_id, public.week_of(new.work_date), 'request', new.id::text, v_action, new.user_id,
    case when tg_op = 'UPDATE' then to_jsonb(old) - 'updated_at' end, to_jsonb(new) - 'updated_at');
  return null;
end;
$$;

revoke all on function public.trg_log_shift_request() from public, anon, authenticated;

drop trigger if exists shift_requests_log on public.shift_requests;
create trigger shift_requests_log after insert or update of status on public.shift_requests
  for each row execute function public.trg_log_shift_request();

-- ---------------------------------------------------------------- availability
-- Saving rewrites every row, so a per-row trigger would write dozens of lines. One line per save.
create or replace function public.replace_availability(p_user uuid, p_items jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_before jsonb;
begin
  perform public.check_availability_items(p_items);
  perform set_config('app.schedule_source', 'replace_availability', true);
  select coalesce(jsonb_agg(jsonb_build_object(
    'weekday', a.weekday, 'kind', a.kind, 'start_time', a.start_time, 'end_time', a.end_time, 'note', a.note
  ) order by a.weekday, a.start_time), '[]'::jsonb) into v_before
  from public.staff_availability a where a.user_id = p_user;

  delete from public.staff_availability where user_id = p_user;
  insert into public.staff_availability (user_id, weekday, kind, start_time, end_time, note, updated_by)
  select p_user, (i ->> 'weekday')::smallint, i ->> 'kind',
         nullif(i ->> 'start_time', '')::time, nullif(i ->> 'end_time', '')::time,
         nullif(btrim(i ->> 'note'), ''), (select auth.uid())
  from jsonb_array_elements(p_items) i;

  perform public.log_schedule_change(null, null, 'availability', p_user::text, 'replace', p_user, v_before, p_items);
end;
$$;

-- ---------------------------------------------------------------- reading
create or replace function public.schedule_history_list(
  p_branch uuid default null, p_from date default null, p_to date default null, p_user uuid default null,
  p_entity text default null, p_published_only boolean default false, p_page integer default 1, p_page_size integer default 30
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[] := public.attendance_branch_ids(p_branch, 'VIEW');
  v_size     integer := least(greatest(coalesce(p_page_size, 30), 1), 100);
  v_offset   integer := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total    integer;
  v_rows     jsonb;
begin
  if p_entity is not null and p_entity not in ('assignment', 'request', 'week', 'submission', 'settings', 'exemption', 'availability') then
    raise exception 'invalid entity' using errcode = '22023', hint = 'bad_input';
  end if;

  with picked as (
    select h.id from public.schedule_history h
    where (h.branch_id = any (v_branches)
           or (p_branch is null and h.branch_id is null and h.target_user_id is not null and public.can_view_staff(h.target_user_id)))
      and (p_from is null or coalesce(h.week_monday, (h.created_at at time zone 'Asia/Ho_Chi_Minh')::date) >= public.week_of(p_from))
      and (p_to is null or coalesce(h.week_monday, (h.created_at at time zone 'Asia/Ho_Chi_Minh')::date) <= p_to)
      and (p_user is null or h.target_user_id = p_user)
      and (p_entity is null or h.entity = p_entity)
      and (not coalesce(p_published_only, false) or h.was_published)
  ),
  page as (select id from picked order by id desc limit v_size offset v_offset)
  select (select count(*) from picked),
         coalesce((select jsonb_agg(to_jsonb(h) order by h.id desc)
                   from public.schedule_history h where h.id in (select id from page)), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$$;

-- Everything that happened to one shift or request, newest first (the roster cell's history).
create or replace function public.schedule_history_of(p_entity text, p_entity_id text) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rows jsonb;
begin
  if p_entity is null or p_entity_id is null then
    raise exception 'invalid request' using errcode = '22023', hint = 'bad_input';
  end if;
  select coalesce(jsonb_agg(to_jsonb(h) order by h.id desc), '[]'::jsonb) into v_rows
  from (
    select * from public.schedule_history s
    where s.entity = p_entity and s.entity_id = p_entity_id
      and ((s.branch_id is not null and public.can_attendance('VIEW', s.branch_id))
           or (s.branch_id is null and s.target_user_id is not null and public.can_view_staff(s.target_user_id)))
    order by s.id desc limit 100
  ) h;
  return v_rows;
end;
$$;

revoke all on function public.schedule_history_list(uuid, date, date, uuid, text, boolean, integer, integer) from public, anon;
revoke all on function public.schedule_history_of(text, text) from public, anon;
grant execute on function public.schedule_history_list(uuid, date, date, uuid, text, boolean, integer, integer) to authenticated;
grant execute on function public.schedule_history_of(text, text) to authenticated;

-- ---------------------------------------------------------------- reasons
-- The next five functions take an optional reason that goes into the history. The old signatures are
-- dropped in this migration, so a call without the reason still resolves to the new one.

-- assign_shift: now takes an optional reason (kept in the history).
drop function if exists public.assign_shift(uuid, uuid, date, uuid, time, time, integer, text);
create or replace function public.assign_shift(p_branch uuid, p_user uuid, p_date date, p_template uuid, p_start time default null::time, p_end time default null::time, p_break integer default null::integer, p_note text default null::text, p_reason text default null) returns jsonb
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
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'assign_shift', true);
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

revoke all on function public.assign_shift(uuid, uuid, date, uuid, time, time, integer, text, text) from public, anon;
grant execute on function public.assign_shift(uuid, uuid, date, uuid, time, time, integer, text, text) to authenticated;

-- update_shift_assignment: now takes an optional reason (kept in the history).
drop function if exists public.update_shift_assignment(uuid, jsonb);
create or replace function public.update_shift_assignment(p_id uuid, p jsonb, p_reason text default null) returns void
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
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'update_shift_assignment', true);
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

revoke all on function public.update_shift_assignment(uuid, jsonb, text) from public, anon;
grant execute on function public.update_shift_assignment(uuid, jsonb, text) to authenticated;

-- remove_shift_assignment: now takes an optional reason (kept in the history).
drop function if exists public.remove_shift_assignment(uuid);
create or replace function public.remove_shift_assignment(p_id uuid, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'remove_shift_assignment', true);
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

revoke all on function public.remove_shift_assignment(uuid, text) from public, anon;
grant execute on function public.remove_shift_assignment(uuid, text) to authenticated;

-- copy_roster_week: now takes an optional reason (kept in the history).
drop function if exists public.copy_roster_week(uuid, date, date, boolean);
create or replace function public.copy_roster_week(p_branch uuid, p_from_monday date, p_to_monday date, p_overwrite boolean default false, p_reason text default null) returns jsonb
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
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'copy_roster_week', true);
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

revoke all on function public.copy_roster_week(uuid, date, date, boolean, text) from public, anon;
grant execute on function public.copy_roster_week(uuid, date, date, boolean, text) to authenticated;

-- decide_shift_requests: now takes an optional reason (kept in the history).
drop function if exists public.decide_shift_requests(uuid[], boolean, text);
create or replace function public.decide_shift_requests(p_ids uuid[], p_approve boolean, p_note text default null::text, p_reason text default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := (select auth.uid());
  v_name     text := public.staff_display_name((select auth.uid()));
  v_note     text := nullif(btrim(p_note), '');
  v_id       uuid;
  v_req      public.shift_requests;
  v_assign   uuid;
  v_hint     text;
  v_approved integer := 0;
  v_rejected integer := 0;
  v_failed   jsonb := '[]'::jsonb;
begin
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'decide_shift_requests', true);
  if v_me is null then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_ids is null or cardinality(p_ids) not between 1 and 200 or p_approve is null or length(coalesce(v_note, '')) > 300 then
    raise exception 'invalid request' using errcode = '22023', hint = 'bad_input';
  end if;

  foreach v_id in array p_ids loop
    begin
      select * into v_req from public.shift_requests where id = v_id for update;
      if not found then
        raise exception 'request not found' using errcode = 'P0001', hint = 'not_found';
      end if;
      if not public.can_attendance('CREATE', v_req.branch_id) then
        raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
      end if;
      if v_req.status <> 'pending' then
        raise exception 'the request was already decided' using errcode = 'P0001', hint = 'not_pending';
      end if;
      if v_req.user_id = v_me and not public.is_super_admin() then
        raise exception 'you cannot decide your own request' using errcode = 'P0001', hint = 'own_request';
      end if;

      v_assign := null;
      if p_approve then
        if v_req.start_at <= now() then
          raise exception 'the shift already started' using errcode = 'P0001', hint = 'too_late';
        end if;
        if not exists (select 1 from public.staff_branches where user_id = v_req.user_id and branch_id = v_req.branch_id) then
          raise exception 'this person no longer works at the branch' using errcode = 'P0001', hint = 'not_branch_staff';
        end if;
        -- The manager may have put this person on the same shift by hand already.
        select a.id into v_assign from public.shift_assignments a
        where a.user_id = v_req.user_id and a.branch_id = v_req.branch_id and a.work_date = v_req.work_date
          and a.template_id is not distinct from v_req.template_id and a.start_at = v_req.start_at and a.end_at = v_req.end_at
        limit 1;
        if v_assign is null then
          begin
            insert into public.shift_assignments (
              branch_id, user_id, work_date, template_id, name, start_at, end_at, break_minutes, note, created_by
            ) values (
              v_req.branch_id, v_req.user_id, v_req.work_date, v_req.template_id, v_req.name, v_req.start_at,
              v_req.end_at, v_req.break_minutes, v_req.note, v_me
            ) returning id into v_assign;
          exception when exclusion_violation then
            raise exception 'this person already has a shift at that time' using errcode = 'P0001', hint = 'shift_overlap';
          end;
        end if;
      end if;

      update public.shift_requests set
        status = case when p_approve then 'approved' else 'rejected' end,
        assignment_id = v_assign, decided_by = v_me, decided_by_name = v_name, decided_at = now(), decision_note = v_note
      where id = v_id;
      if p_approve then v_approved := v_approved + 1; else v_rejected := v_rejected + 1; end if;
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_failed := v_failed || jsonb_build_object('id', v_id, 'hint', coalesce(v_hint, 'bad_input'));
    end;
  end loop;
  return jsonb_build_object('approved', v_approved, 'rejected', v_rejected, 'failed', v_failed);
end;
$$;

revoke all on function public.decide_shift_requests(uuid[], boolean, text, text) from public, anon;
grant execute on function public.decide_shift_requests(uuid[], boolean, text, text) to authenticated;
