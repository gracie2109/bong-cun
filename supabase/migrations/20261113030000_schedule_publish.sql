-- Publishing a week's schedule: per-branch switch, draft/published weeks, "no shifts this week"
-- declarations, exemptions, who has not registered, locked registration after publishing, and the
-- notice sent to a person whose published shifts change.
--
-- With require_publish off (the default) nothing changes for anyone: staff see their shifts as soon
-- as they are assigned and no publishing notices are sent.

alter table public.shift_registration_settings add column if not exists require_publish boolean not null default false;

-- ---------------------------------------------------------------- tables
create table if not exists public.schedule_weeks (
  branch_id         uuid        not null references public.branches (id) on delete cascade,
  week_monday       date        not null check (extract(isodow from week_monday) = 1),
  status            text        not null default 'draft' check (status in ('draft', 'published')),
  published_at      timestamptz,
  published_by      uuid,
  published_by_name text,
  auto_published    boolean     not null default false,
  notified_count    integer     not null default 0,
  updated_at        timestamptz not null default now(),
  primary key (branch_id, week_monday)
);

create table if not exists public.shift_registration_submissions (
  branch_id   uuid        not null references public.branches (id) on delete cascade,
  user_id     uuid        not null references public.users (id) on delete cascade,
  week_monday date        not null check (extract(isodow from week_monday) = 1),
  kind        text        not null default 'none' check (kind = 'none'),
  reason      text        check (reason is null or char_length(reason) <= 300),
  created_at  timestamptz not null default now(),
  primary key (branch_id, user_id, week_monday)
);

create table if not exists public.shift_registration_exemptions (
  branch_id  uuid        not null references public.branches (id) on delete cascade,
  user_id    uuid        not null references public.users (id) on delete cascade,
  note       text        check (note is null or char_length(note) <= 300),
  created_by uuid        references public.users (id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (branch_id, user_id)
);

alter table public.schedule_weeks enable row level security;
alter table public.shift_registration_submissions enable row level security;
alter table public.shift_registration_exemptions enable row level security;
revoke all on public.schedule_weeks, public.shift_registration_submissions, public.shift_registration_exemptions from anon, authenticated;
grant select on public.schedule_weeks, public.shift_registration_submissions, public.shift_registration_exemptions to authenticated;

drop policy if exists "weeks read" on public.schedule_weeks;
create policy "weeks read" on public.schedule_weeks
  for select to authenticated using ((select public.is_branch_staff(branch_id)) or (select public.can_attendance('VIEW', branch_id)));

drop policy if exists "submissions read" on public.shift_registration_submissions;
create policy "submissions read" on public.shift_registration_submissions
  for select to authenticated using (user_id = (select auth.uid()) or (select public.can_attendance('VIEW', branch_id)));

drop policy if exists "exemptions read" on public.shift_registration_exemptions;
create policy "exemptions read" on public.shift_registration_exemptions
  for select to authenticated using (user_id = (select auth.uid()) or (select public.can_attendance('VIEW', branch_id)));

drop trigger if exists schedule_weeks_set_updated_at on public.schedule_weeks;
create trigger schedule_weeks_set_updated_at before update on public.schedule_weeks
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------- small helpers
create or replace function public.vn_today() returns date
language sql
stable
set search_path = ''
as $$ select (now() at time zone 'Asia/Ho_Chi_Minh')::date; $$;

create or replace function public.branch_requires_publish(p_branch uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select coalesce((select s.require_publish from public.shift_registration_settings s where s.branch_id = p_branch), false); $$;

-- Whether staff may see the schedule of a week. A branch that does not publish shows everything; one
-- that does shows a week once it is published, and always shows the week that has already started.
create or replace function public.week_is_published(p_branch uuid, p_monday date) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not public.branch_requires_publish(p_branch)
      or p_monday <= public.week_of(public.vn_today())
      or exists (select 1 from public.schedule_weeks w
                 where w.branch_id = p_branch and w.week_monday = p_monday and w.status = 'published');
$$;

-- A published week is closed to staff: no new requests, no cancelling.
create or replace function public.week_locked(p_branch uuid, p_monday date) returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select public.branch_requires_publish(p_branch) and public.week_is_published(p_branch, p_monday); $$;

-- The history flag "changed after publishing" now has a real meaning.
create or replace function public.history_published_flag(p_branch uuid, p_monday date) returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select public.week_locked(p_branch, p_monday); $$;

-- What a person sees of their own request: while the week is not published a decision is hidden.
create or replace function public.request_decision_visible(r public.shift_requests) returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select r.status in ('pending', 'cancelled') or public.week_is_published(r.branch_id, public.week_of(r.work_date)); $$;

-- has_permission / can_attendance for somebody other than the caller.
create or replace function public.user_has_attendance(p_user uuid, p_method text, p_branch uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select u.role in ('admin', 'superAdmin') from public.users u where u.id = p_user), false)
      or exists (
        select 1 from public.staff_branches sb
        join public.role_permissions rp on rp.role = sb.role
        where sb.user_id = p_user and sb.branch_id = p_branch
          and rp.permission = 'attendance' and rp.methods && array[upper(p_method), 'ALL']);
$$;

-- Who has to register: staff of the branch, except managers (they assign shifts) and exempted people.
create or replace function public.staff_must_register(p_branch uuid, p_user uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.staff_branches sb where sb.user_id = p_user and sb.branch_id = p_branch)
     and not public.user_has_attendance(p_user, 'CREATE', p_branch)
     and not exists (select 1 from public.shift_registration_exemptions x where x.branch_id = p_branch and x.user_id = p_user);
$$;

revoke all on function public.vn_today() from public, anon, authenticated;
revoke all on function public.branch_requires_publish(uuid) from public, anon, authenticated;
revoke all on function public.week_is_published(uuid, date) from public, anon, authenticated;
revoke all on function public.week_locked(uuid, date) from public, anon, authenticated;
revoke all on function public.request_decision_visible(public.shift_requests) from public, anon, authenticated;
revoke all on function public.user_has_attendance(uuid, text, uuid) from public, anon, authenticated;
revoke all on function public.staff_must_register(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- history triggers for the new tables
create or replace function public.trg_log_schedule_week() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'published' and (tg_op = 'INSERT' or old.status is distinct from 'published') then
    perform public.log_schedule_change(
      new.branch_id, new.week_monday, 'week', new.branch_id::text || ':' || new.week_monday::text,
      case when new.auto_published then 'auto_publish' else 'publish' end, null,
      case when tg_op = 'UPDATE' then to_jsonb(old) - 'updated_at' end, to_jsonb(new) - 'updated_at');
  end if;
  return null;
end;
$$;

create or replace function public.trg_log_submission() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.log_schedule_change(old.branch_id, old.week_monday, 'submission',
      old.branch_id::text || ':' || old.user_id::text || ':' || old.week_monday::text, 'delete', old.user_id, to_jsonb(old), null);
  else
    perform public.log_schedule_change(new.branch_id, new.week_monday, 'submission',
      new.branch_id::text || ':' || new.user_id::text || ':' || new.week_monday::text, 'declare_none', new.user_id,
      case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  end if;
  return null;
end;
$$;

create or replace function public.trg_log_registration_settings() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) - 'updated_at' - 'updated_by' end;
  v_new jsonb := to_jsonb(new) - 'updated_at' - 'updated_by';
begin
  if tg_op = 'UPDATE' and v_old is not distinct from v_new then
    return null;
  end if;
  perform public.log_schedule_change(new.branch_id, null, 'settings', new.branch_id::text,
    case when tg_op = 'INSERT' then 'insert' else 'update' end, null, v_old, v_new);
  return null;
end;
$$;

create or replace function public.trg_log_exemption() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.log_schedule_change(old.branch_id, null, 'exemption', old.branch_id::text || ':' || old.user_id::text,
      'delete', old.user_id, to_jsonb(old), null);
  else
    perform public.log_schedule_change(new.branch_id, null, 'exemption', new.branch_id::text || ':' || new.user_id::text,
      case when tg_op = 'INSERT' then 'insert' else 'update' end, new.user_id,
      case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  end if;
  return null;
end;
$$;

revoke all on function public.trg_log_schedule_week() from public, anon, authenticated;
revoke all on function public.trg_log_submission() from public, anon, authenticated;
revoke all on function public.trg_log_registration_settings() from public, anon, authenticated;
revoke all on function public.trg_log_exemption() from public, anon, authenticated;

drop trigger if exists schedule_weeks_log on public.schedule_weeks;
create trigger schedule_weeks_log after insert or update on public.schedule_weeks
  for each row execute function public.trg_log_schedule_week();
drop trigger if exists shift_registration_submissions_log on public.shift_registration_submissions;
create trigger shift_registration_submissions_log after insert or update or delete on public.shift_registration_submissions
  for each row execute function public.trg_log_submission();
drop trigger if exists shift_registration_settings_log on public.shift_registration_settings;
create trigger shift_registration_settings_log after insert or update on public.shift_registration_settings
  for each row execute function public.trg_log_registration_settings();
drop trigger if exists shift_registration_exemptions_log on public.shift_registration_exemptions;
create trigger shift_registration_exemptions_log after insert or update or delete on public.shift_registration_exemptions
  for each row execute function public.trg_log_exemption();

-- ---------------------------------------------------------------- "your schedule changed"
-- A shift of a published week was added, changed or removed: tell the person. Publishing itself and
-- branches that do not publish stay silent.
create or replace function public.trg_notify_shift_change() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := nullif(btrim(coalesce(current_setting('app.schedule_reason', true), '')), '');
begin
  if coalesce(current_setting('app.schedule_publishing', true), '') = 'on' then
    return null;
  end if;
  if tg_op = 'UPDATE' and to_jsonb(old) - 'updated_at' is not distinct from to_jsonb(new) - 'updated_at' then
    return null;
  end if;
  if tg_op in ('UPDATE', 'DELETE') and public.week_locked(old.branch_id, public.week_of(old.work_date)) then
    perform public.notify_schedule_changed(old.user_id, old.branch_id, public.week_of(old.work_date), v_reason);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and public.week_locked(new.branch_id, public.week_of(new.work_date)) then
    if tg_op = 'UPDATE' and old.user_id = new.user_id and public.week_of(old.work_date) = public.week_of(new.work_date)
       and public.week_locked(old.branch_id, public.week_of(old.work_date)) then
      return null; -- the old side already notified this person for this week
    end if;
    perform public.notify_schedule_changed(new.user_id, new.branch_id, public.week_of(new.work_date), v_reason);
  end if;
  return null;
end;
$$;

revoke all on function public.trg_notify_shift_change() from public, anon, authenticated;

drop trigger if exists shift_assignments_notify on public.shift_assignments;
create trigger shift_assignments_notify after insert or update or delete on public.shift_assignments
  for each row execute function public.trg_notify_shift_change();

-- ---------------------------------------------------------------- reading the state
-- State of a week for the caller: staff of the branch and managers.
create or replace function public.schedule_week_status(p_branch uuid, p_monday date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_w       public.schedule_weeks;
  v_require boolean := public.branch_requires_publish(p_branch);
  v_manager boolean := public.can_attendance('VIEW', p_branch);
  v_missing integer;
begin
  if not (public.is_branch_staff(p_branch) or v_manager) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_monday is null or extract(isodow from p_monday) <> 1 then
    raise exception 'the date must be a Monday' using errcode = '22023', hint = 'bad_input';
  end if;
  select * into v_w from public.schedule_weeks where branch_id = p_branch and week_monday = p_monday;
  if v_manager then
    select count(*) into v_missing
    from public.staff_branches sb
    where sb.branch_id = p_branch and public.staff_must_register(p_branch, sb.user_id)
      and not exists (select 1 from public.shift_requests r
                      where r.branch_id = p_branch and r.user_id = sb.user_id and r.work_date between p_monday and p_monday + 6
                        and r.status <> 'cancelled')
      and not exists (select 1 from public.shift_registration_submissions x
                      where x.branch_id = p_branch and x.user_id = sb.user_id and x.week_monday = p_monday);
  end if;
  return jsonb_build_object(
    'require_publish', v_require,
    'status', case when v_require and public.week_is_published(p_branch, p_monday) then 'published' else 'draft' end,
    'published_at', v_w.published_at,
    'published_by_name', v_w.published_by_name,
    'auto_published', coalesce(v_w.auto_published, false),
    'pending_requests', case when v_manager then (
        select count(*) from public.shift_requests r
        where r.branch_id = p_branch and r.status = 'pending' and r.work_date between p_monday and p_monday + 6) end,
    'missing_count', v_missing);
end;
$$;

-- Who registered for a week, who declared "no shifts", who did neither.
create or replace function public.registration_status(p_branch uuid, p_monday date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rows    jsonb;
  v_missing integer;
begin
  if not public.can_attendance('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_monday is null or extract(isodow from p_monday) <> 1 then
    raise exception 'the date must be a Monday' using errcode = '22023', hint = 'bad_input';
  end if;

  with people as (
    select sb.user_id,
           public.staff_display_name(sb.user_id) as name,
           public.user_has_attendance(sb.user_id, 'CREATE', p_branch) as is_manager,
           exists (select 1 from public.shift_registration_exemptions x where x.branch_id = p_branch and x.user_id = sb.user_id) as is_exempt,
           (select count(*) from public.shift_requests r
             where r.branch_id = p_branch and r.user_id = sb.user_id and r.work_date between p_monday and p_monday + 6
               and r.status <> 'cancelled') as request_count,
           (select count(*) from public.shift_assignments a
             where a.branch_id = p_branch and a.user_id = sb.user_id and a.work_date between p_monday and p_monday + 6) as assigned_count,
           exists (select 1 from public.shift_registration_submissions x
                    where x.branch_id = p_branch and x.user_id = sb.user_id and x.week_monday = p_monday) as declared_none
    from public.staff_branches sb where sb.branch_id = p_branch
  ), states as (
    select p.*, case
        when p.is_manager then 'manager'
        when p.is_exempt then 'exempt'
        when p.request_count > 0 then 'submitted'
        when p.declared_none then 'declared_none'
        else 'missing' end as state
    from people p
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'user_id', s.user_id, 'name', s.name, 'must_register', s.state in ('submitted', 'declared_none', 'missing'),
           'state', s.state, 'request_count', s.request_count, 'assigned_count', s.assigned_count)
         order by (s.state = 'missing') desc, s.name), '[]'::jsonb),
         count(*) filter (where s.state = 'missing')
    into v_rows, v_missing
  from states s;

  return jsonb_build_object('rows', v_rows, 'missing_count', v_missing,
    'closes_at', public.shift_registration_window(p_branch, p_monday) -> 'closes_at');
end;
$$;

-- ---------------------------------------------------------------- "I cannot work any shift this week"
create or replace function public.declare_no_shifts(p_branch uuid, p_monday date, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := (select auth.uid());
  v_reason text := nullif(btrim(p_reason), '');
  v_window jsonb;
begin
  if v_me is null or not public.is_branch_staff(p_branch) then
    raise exception 'you do not work at this branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  if length(coalesce(v_reason, '')) > 300 then
    raise exception 'invalid request' using errcode = '22023', hint = 'bad_input';
  end if;
  v_window := public.shift_registration_window(p_branch, p_monday);
  if public.week_locked(p_branch, p_monday) then
    raise exception 'the week was already published' using errcode = 'P0001', hint = 'week_published';
  end if;
  if not (v_window ->> 'open')::boolean then
    raise exception 'registration is closed (%)', v_window ->> 'reason' using errcode = 'P0001', hint = 'registration_closed';
  end if;
  if exists (select 1 from public.shift_requests r
             where r.branch_id = p_branch and r.user_id = v_me and r.work_date between p_monday and p_monday + 6
               and r.status in ('pending', 'approved')) then
    raise exception 'cancel your requests first' using errcode = 'P0001', hint = 'has_requests';
  end if;
  perform set_config('app.schedule_source', 'declare_no_shifts', true);
  insert into public.shift_registration_submissions (branch_id, user_id, week_monday, reason)
  values (p_branch, v_me, p_monday, v_reason)
  on conflict (branch_id, user_id, week_monday) do update set reason = excluded.reason;
end;
$$;

create or replace function public.withdraw_no_shifts(p_branch uuid, p_monday date) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me     uuid := (select auth.uid());
  v_window jsonb;
begin
  if v_me is null or not public.is_branch_staff(p_branch) then
    raise exception 'you do not work at this branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  v_window := public.shift_registration_window(p_branch, p_monday);
  if public.week_locked(p_branch, p_monday) then
    raise exception 'the week was already published' using errcode = 'P0001', hint = 'week_published';
  end if;
  if not (v_window ->> 'open')::boolean then
    raise exception 'registration is closed (%)', v_window ->> 'reason' using errcode = 'P0001', hint = 'registration_closed';
  end if;
  perform set_config('app.schedule_source', 'withdraw_no_shifts', true);
  delete from public.shift_registration_submissions where branch_id = p_branch and user_id = v_me and week_monday = p_monday;
end;
$$;

-- ---------------------------------------------------------------- exemptions
create or replace function public.set_registration_exemption(p_branch uuid, p_user uuid, p_exempt boolean, p_note text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_note text := nullif(btrim(p_note), '');
begin
  if not public.can_attendance('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_user is null or p_exempt is null or length(coalesce(v_note, '')) > 300 then
    raise exception 'invalid request' using errcode = '22023', hint = 'bad_input';
  end if;
  if not exists (select 1 from public.staff_branches where user_id = p_user and branch_id = p_branch) then
    raise exception 'this person does not work at the branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  perform set_config('app.schedule_source', 'set_registration_exemption', true);
  if p_exempt then
    insert into public.shift_registration_exemptions (branch_id, user_id, note, created_by)
    values (p_branch, p_user, v_note, (select auth.uid()))
    on conflict (branch_id, user_id) do update set note = excluded.note;
  else
    delete from public.shift_registration_exemptions where branch_id = p_branch and user_id = p_user;
  end if;
end;
$$;

create or replace function public.list_registration_exemptions(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_attendance('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('user_id', x.user_id, 'name', public.staff_display_name(x.user_id), 'note', x.note)
                     order by public.staff_display_name(x.user_id))
    from public.shift_registration_exemptions x where x.branch_id = p_branch), '[]'::jsonb);
end;
$$;

-- ---------------------------------------------------------------- publishing
-- The work of publishing one week, shared by the button and the Monday cron (p_auto). Not callable by clients.
create or replace function public.do_publish_week(p_branch uuid, p_monday date, p_auto boolean, p_reject_note text) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := (select auth.uid());
  v_name     text := case when p_auto or v_me is null then 'Hệ thống' else coalesce(public.staff_display_name(v_me), 'Hệ thống') end;
  v_week     public.schedule_weeks;
  v_rejected integer;
  v_shifts   integer;
  v_notified integer := 0;
  v_range    text := to_char(p_monday, 'DD/MM') || '–' || to_char(p_monday + 6, 'DD/MM');
  v_branch   text := (select b.name from public.branches b where b.id = p_branch);
  r          record;
  v_count    integer;
begin
  insert into public.schedule_weeks (branch_id, week_monday) values (p_branch, p_monday) on conflict do nothing;
  select * into v_week from public.schedule_weeks where branch_id = p_branch and week_monday = p_monday for update;
  if v_week.status = 'published' then
    raise exception 'the week is already published' using errcode = 'P0001', hint = 'already_published';
  end if;

  perform set_config('app.schedule_publishing', 'on', true);
  perform set_config('app.schedule_source', case when p_auto then 'cron:auto_publish' else 'publish_schedule_week' end, true);

  -- Requests nobody decided are closed with a note, so nothing stays pending after publishing.
  update public.shift_requests set
    status = 'rejected', decided_by = case when p_auto then null else v_me end, decided_by_name = v_name,
    decided_at = now(), decision_note = left(p_reject_note, 300)
  where branch_id = p_branch and work_date between p_monday and p_monday + 6 and status = 'pending';
  get diagnostics v_rejected = row_count;

  select count(*) into v_shifts from public.shift_assignments
  where branch_id = p_branch and work_date between p_monday and p_monday + 6;

  update public.schedule_weeks set
    status = 'published', published_at = now(), published_by = case when p_auto then null else v_me end,
    published_by_name = v_name, auto_published = coalesce(p_auto, false)
  where branch_id = p_branch and week_monday = p_monday;

  -- One notice for everyone who has shifts that week or had to register.
  for r in
    select sb.user_id from public.staff_branches sb
    where sb.branch_id = p_branch
      and (exists (select 1 from public.shift_assignments a
                   where a.branch_id = p_branch and a.user_id = sb.user_id and a.work_date between p_monday and p_monday + 6)
           or public.staff_must_register(p_branch, sb.user_id))
  loop
    select count(*) into v_count from public.shift_assignments a
    where a.branch_id = p_branch and a.user_id = r.user_id and a.work_date between p_monday and p_monday + 6;
    perform public.notify_user(
      r.user_id, p_branch, 'schedule_published', 'Lịch tuần ' || v_range || ' đã phát hành',
      case when v_count > 0 then 'Bạn có ' || v_count || ' ca tuần này' else 'Bạn không có ca nào tuần này' end
        || coalesce(' tại ' || v_branch, '') || '.',
      jsonb_build_object('name', 'attendanceMe', 'query', jsonb_build_object('week', p_monday)),
      jsonb_build_object('week_monday', p_monday, 'shift_count', v_count));
    v_notified := v_notified + 1;
  end loop;

  update public.schedule_weeks set notified_count = v_notified where branch_id = p_branch and week_monday = p_monday;
  perform set_config('app.schedule_publishing', 'off', true);
  return jsonb_build_object('notified', v_notified, 'rejected', v_rejected, 'shifts', v_shifts);
end;
$$;

revoke all on function public.do_publish_week(uuid, date, boolean, text) from public, anon, authenticated;

create or replace function public.publish_schedule_week(
  p_branch uuid, p_monday date, p_reject_note text default 'Không được xếp khi phát hành lịch'
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_attendance('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_monday is null or extract(isodow from p_monday) <> 1 then
    raise exception 'the date must be a Monday' using errcode = '22023', hint = 'bad_input';
  end if;
  if not public.branch_requires_publish(p_branch) then
    raise exception 'publishing is switched off' using errcode = 'P0001', hint = 'publish_disabled';
  end if;
  if public.week_is_published(p_branch, p_monday) then
    raise exception 'the week is already published' using errcode = 'P0001', hint = 'already_published';
  end if;
  return public.do_publish_week(p_branch, p_monday, false, coalesce(nullif(btrim(p_reject_note), ''), 'Không được xếp khi phát hành lịch'));
end;
$$;

-- Switching publishing on: weeks that already have shifts are published at once, without notices, so
-- staff do not lose what they see today. The current and past weeks are visible anyway.
create or replace function public.publish_existing_weeks(p_branch uuid) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
  v_me uuid := (select auth.uid());
begin
  perform set_config('app.schedule_reason', 'Bật phát hành lịch', true);
  perform set_config('app.schedule_source', 'publish_existing_weeks', true);
  insert into public.schedule_weeks (branch_id, week_monday, status, published_at, published_by, published_by_name)
  select p_branch, w.monday, 'published', now(), v_me, coalesce(public.staff_display_name(v_me), 'Hệ thống')
  from (select distinct public.week_of(a.work_date) as monday from public.shift_assignments a
        where a.branch_id = p_branch and public.week_of(a.work_date) > public.week_of(public.vn_today())) w
  on conflict (branch_id, week_monday) do update set
    status = 'published', published_at = now(), published_by = excluded.published_by, published_by_name = excluded.published_by_name
  where public.schedule_weeks.status <> 'published';
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.publish_existing_weeks(uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------- "like last week" for one person
create or replace function public.assign_to_previous_week(p_branch uuid, p_monday date, p_user uuid, p_reason text default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  r         public.shift_assignments;
  v_copied  integer := 0;
  v_skipped integer := 0;
begin
  if not public.can_attendance('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_monday is null or extract(isodow from p_monday) <> 1 or p_user is null then
    raise exception 'invalid request' using errcode = '22023', hint = 'bad_input';
  end if;
  if not exists (select 1 from public.staff_branches where user_id = p_user and branch_id = p_branch) then
    raise exception 'this person does not work at the branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'assign_to_previous_week', true);

  for r in
    select * from public.shift_assignments
    where branch_id = p_branch and user_id = p_user and work_date >= p_monday - 7 and work_date < p_monday
    order by start_at
  loop
    if exists (select 1 from public.shift_assignments
               where branch_id = p_branch and user_id = p_user and work_date = r.work_date + 7) then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    begin
      insert into public.shift_assignments (
        branch_id, user_id, work_date, template_id, name, start_at, end_at, break_minutes, note, created_by
      ) values (
        p_branch, p_user, r.work_date + 7, r.template_id, r.name,
        ((r.start_at at time zone 'Asia/Ho_Chi_Minh') + interval '7 days') at time zone 'Asia/Ho_Chi_Minh',
        ((r.end_at at time zone 'Asia/Ho_Chi_Minh') + interval '7 days') at time zone 'Asia/Ho_Chi_Minh',
        r.break_minutes, r.note, (select auth.uid()));
      v_copied := v_copied + 1;
    exception when exclusion_violation then
      v_skipped := v_skipped + 1;
    end;
  end loop;
  return jsonb_build_object('copied', v_copied, 'skipped', v_skipped);
end;
$$;

revoke all on function public.schedule_week_status(uuid, date) from public, anon;
revoke all on function public.registration_status(uuid, date) from public, anon;
revoke all on function public.declare_no_shifts(uuid, date, text) from public, anon;
revoke all on function public.withdraw_no_shifts(uuid, date) from public, anon;
revoke all on function public.set_registration_exemption(uuid, uuid, boolean, text) from public, anon;
revoke all on function public.list_registration_exemptions(uuid) from public, anon;
revoke all on function public.publish_schedule_week(uuid, date, text) from public, anon;
revoke all on function public.assign_to_previous_week(uuid, date, uuid, text) from public, anon;
grant execute on function public.schedule_week_status(uuid, date) to authenticated;
grant execute on function public.registration_status(uuid, date) to authenticated;
grant execute on function public.declare_no_shifts(uuid, date, text) to authenticated;
grant execute on function public.withdraw_no_shifts(uuid, date) to authenticated;
grant execute on function public.set_registration_exemption(uuid, uuid, boolean, text) to authenticated;
grant execute on function public.list_registration_exemptions(uuid) to authenticated;
grant execute on function public.publish_schedule_week(uuid, date, text) to authenticated;
grant execute on function public.assign_to_previous_week(uuid, date, uuid, text) to authenticated;

-- ---------------------------------------------------------------- rewritten functions (copied from schema.sql, then edited)
create or replace function public.submit_shift_requests(p_branch uuid, p_monday date, p_items jsonb, p_note text default null) returns jsonb
language plpgsql security definer
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
  if public.week_locked(p_branch, p_monday) then
    raise exception 'the week was already published' using errcode = 'P0001', hint = 'week_published';
  end if;
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

      begin
        insert into public.shift_requests (
          branch_id, user_id, user_name, work_date, template_id, name, start_at, end_at, break_minutes, note
        ) values (
          p_branch, v_me, public.staff_display_name(v_me), v_date, v_tpl, v_t.name, v_start_at, v_end_at,
          v_t.break_minutes, v_note
        ) returning id into v_id;
      exception
        when exclusion_violation then
          raise exception 'overlaps another pending request' using errcode = 'P0001', hint = 'request_overlap';
        when unique_violation then
          raise exception 'already requested' using errcode = 'P0001', hint = 'duplicate';
      end;
      v_count := v_count + 1;

      v_warning := case
        when public.shift_on_leave(v_me, v_start_at) then 'on_leave'
        when public.availability_conflict(v_me, v_start_at, v_end_at) = 'unavailable' then 'unavailable'
      end;
      v_created := v_created || jsonb_strip_nulls(jsonb_build_object(
        'id', v_id, 'work_date', v_date, 'template_id', v_tpl, 'warning', v_warning));
    exception
      when others then
        get stacked diagnostics v_hint = pg_exception_hint;
        v_skipped := v_skipped || jsonb_build_object(
          'work_date', v_item ->> 'work_date', 'template_id', v_item ->> 'template_id', 'hint', coalesce(v_hint, 'bad_input'));
    end;
  end loop;
  -- Having asked for shifts replaces an earlier "no shifts this week".
  if jsonb_array_length(v_created) > 0 then
    delete from public.shift_registration_submissions where branch_id = p_branch and user_id = v_me and week_monday = p_monday;
  end if;
  return jsonb_build_object('created', v_created, 'skipped', v_skipped);
end;
$$;

create or replace function public.cancel_shift_request(p_id uuid) returns void
language plpgsql security definer
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
  if public.week_locked(v_row.branch_id, public.week_of(v_row.work_date)) then
    raise exception 'the week was already published' using errcode = 'P0001', hint = 'week_published';
  end if;
  update public.shift_requests set status = 'cancelled' where id = p_id;
end;
$$;

create or replace function public.my_schedule(p_from date, p_to date) returns jsonb
language plpgsql stable security definer
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
      where a.user_id = v_user and a.work_date between p_from and p_to
        and public.week_is_published(a.branch_id, public.week_of(a.work_date))), '[]'::jsonb),
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

create or replace function public.my_shift_requests(p_from date, p_to date) returns jsonb
language plpgsql stable security definer
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
      'status', case when public.request_decision_visible(r) then r.status else 'submitted' end, 'note', r.note,
      'decision_note', case when public.request_decision_visible(r) then r.decision_note end,
      'expired', r.status = 'pending' and r.start_at <= now(), 'assignment_id', case when public.request_decision_visible(r) then r.assignment_id end)
      order by r.work_date, r.start_at)
    from public.shift_requests r join public.branches b on b.id = r.branch_id
    where r.user_id = (select auth.uid()) and r.work_date between p_from and p_to), '[]'::jsonb);
end;
$$;

create or replace function public.shift_registration_board(p_branch uuid, p_monday date) returns jsonb
language plpgsql stable security definer
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
        'id', r.id, 'work_date', r.work_date, 'template_id', r.template_id, 'name', r.name,
        'status', case when public.request_decision_visible(r) then r.status else 'submitted' end,
        'note', r.note, 'decision_note', case when public.request_decision_visible(r) then r.decision_note end,
        'assignment_id', case when public.request_decision_visible(r) then r.assignment_id end,
        'start_at', r.start_at, 'end_at', r.end_at) order by r.work_date, r.start_at)
      from public.shift_requests r
      where r.user_id = v_me and r.branch_id = p_branch and r.work_date between p_monday and p_monday + 6
        and r.status <> 'cancelled'), '[]'::jsonb),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'branch_id', a.branch_id, 'branch_name', b.name, 'work_date', a.work_date,
        'template_id', a.template_id, 'name', a.name, 'start_at', a.start_at, 'end_at', a.end_at) order by a.start_at)
      from public.shift_assignments a join public.branches b on b.id = a.branch_id
      where a.user_id = v_me and a.work_date between p_monday and p_monday + 6
        and public.week_is_published(a.branch_id, p_monday)), '[]'::jsonb),
    'leaves', coalesce((
      select jsonb_agg(jsonb_build_object(
        'from_date', l.from_date, 'to_date', l.to_date, 'part', l.part, 'leave_type', l.leave_type)
        order by l.from_date)
      from public.leave_requests l
      where l.user_id = v_me and l.status = 'approved' and l.from_date <= p_monday + 6 and l.to_date >= p_monday), '[]'::jsonb),
    'availability', public.availability_rows(v_me),
    'needs', '[]'::jsonb,
    'week', public.schedule_week_status(p_branch, p_monday),
    'submission', (select jsonb_build_object('kind', x.kind, 'reason', x.reason)
                   from public.shift_registration_submissions x
                   where x.branch_id = p_branch and x.user_id = v_me and x.week_monday = p_monday)
  );
end;
$$;

create or replace function public.shift_registration_rules_raw(p_branch uuid) returns jsonb
language sql stable security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'is_open', coalesce(s.is_open, false),
    'weeks_ahead', coalesce(s.weeks_ahead, 2),
    'close_days_before', coalesce(s.close_days_before, 2),
    'max_shifts_per_week', s.max_shifts_per_week,
    'staff_note', s.staff_note,
    'require_publish', coalesce(s.require_publish, false))
  from (select p_branch as branch_id) b
  left join public.shift_registration_settings s on s.branch_id = b.branch_id;
$$;

-- Registration settings (copied from schema.sql) plus the publishing switch. Turning the switch on may
-- publish the weeks that already have shifts ("publish_existing"), so staff keep seeing them.
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
  v_require boolean;
  v_was boolean := public.branch_requires_publish(p_branch);
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
    v_require := coalesce((p ->> 'require_publish')::boolean, v_was);
  exception when others then
    raise exception 'invalid settings' using errcode = '22023', hint = 'bad_input';
  end;
  if v_weeks not between 1 and 6 or v_close not between 0 and 14
     or (v_max is not null and v_max not between 1 and 21) or length(coalesce(v_note, '')) > 300 then
    raise exception 'invalid settings' using errcode = '22023', hint = 'bad_input';
  end if;

  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p ->> 'reason'), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'save_shift_registration_settings', true);
  insert into public.shift_registration_settings
    (branch_id, is_open, weeks_ahead, close_days_before, max_shifts_per_week, staff_note, require_publish, updated_by, updated_at)
  values (p_branch, v_open, v_weeks, v_close, v_max, v_note, v_require, (select auth.uid()), now())
  on conflict (branch_id) do update set
    is_open = excluded.is_open, weeks_ahead = excluded.weeks_ahead, close_days_before = excluded.close_days_before,
    max_shifts_per_week = excluded.max_shifts_per_week, staff_note = excluded.staff_note,
    require_publish = excluded.require_publish, updated_by = excluded.updated_by, updated_at = excluded.updated_at;

  if v_require and not v_was and coalesce((p ->> 'publish_existing')::boolean, false) then
    perform public.publish_existing_weeks(p_branch);
  end if;
  return public.shift_registration_rules_raw(p_branch);
end;
$$;

-- Lists the future weeks that already have shifts: what switching publishing on would hide.
create or replace function public.weeks_with_shifts(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_attendance('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('week_monday', w.monday, 'shifts', w.shifts) order by w.monday)
    from (select public.week_of(a.work_date) as monday, count(*) as shifts
          from public.shift_assignments a
          where a.branch_id = p_branch and public.week_of(a.work_date) > public.week_of(public.vn_today())
          group by 1) w), '[]'::jsonb);
end;
$$;

revoke all on function public.weeks_with_shifts(uuid) from public, anon;
grant execute on function public.weeks_with_shifts(uuid) to authenticated;
