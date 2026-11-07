-- Reminders and auto publishing: called directly, not through cron. Only branches that publish take part.
begin;
\ir _helpers/setup.psql
select plan(14);

insert into public.roles (name) values ('t_rem');
insert into public.role_permissions (role, permission, methods)
values ('t_rem', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('re_mgr@test.local', b.ba, 't_rem') as mgr,
  tests.create_staff('re_a@test.local', b.ba, 'cashier') as sa,
  tests.create_staff('re_b@test.local', b.ba, 'cashier') as sb,
  tests.create_staff('re_c@test.local', b.ba, 'cashier') as sc,
  tests.create_staff('re_d@test.local', b.ba, 'cashier') as sd,
  tests.create_staff('re_x@test.local', b.bb, 'cashier') as sx,
  public.week_of(public.vn_today()) as this_monday,
  public.week_of(public.vn_today()) + 7 as monday,
  gen_random_uuid() as tpl
from (select tests.create_branch('REA') as ba, tests.create_branch('REB') as bb) b;

insert into public.shift_templates (id, branch_id, name, start_time, end_time)
select tpl, ba, 'Morning', time '08:00', time '12:00' from ctx;
-- A closes at midnight of the Vietnamese tomorrow for next week: inside the next 24 hours.
-- B has the same window but does not publish.
insert into public.shift_registration_settings (branch_id, is_open, weeks_ahead, close_days_before, require_publish)
select ba, true, 4, (monday - (public.vn_today() + 1)), true from ctx
union all select bb, true, 4, (monday - (public.vn_today() + 1)), false from ctx;

-- sb has sent a request, sc declared no shifts, sd is exempt; sa has done nothing.
insert into public.shift_requests (branch_id, user_id, work_date, template_id, name, start_at, end_at, status)
select ba, sb, monday, tpl, 'Morning', public.shift_start_at(monday, time '08:00'), public.shift_end_at(monday, time '08:00', time '12:00'), 'pending' from ctx;
insert into public.shift_registration_submissions (branch_id, user_id, week_monday) select ba, sc, monday from ctx;
insert into public.shift_registration_exemptions (branch_id, user_id) select ba, sd from ctx;

select is((select count(*)::int from public.registration_missing_users((select ba from ctx), (select monday from ctx))), 1, 'only the person who did nothing is missing');

-- 1. Reminder before the deadline: one person, once.
select is(public.run_registration_reminders(), 1, 'one reminder goes out');
select is((select user_id from public.notifications where kind = 'registration_reminder'), (select sa from ctx), 'it goes to the person who did nothing');
select is(public.run_registration_reminders(), 0, 'running again sends nothing new');
select is((select count(*)::int from public.notifications where user_id = (select sx from ctx)), 0, 'a branch that does not publish is left alone');

-- 2. After the deadline the managers hear how many are missing, once.
select is(public.run_registration_reminders((public.vn_today() + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh' + interval '1 hour'), 1,
  'a manager notice goes out just after the deadline');
select is((select (data ->> 'missing_count')::int from public.notifications where kind = 'registration_missing'), 1, 'it says how many are missing');
select is(public.run_registration_reminders((public.vn_today() + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh' + interval '2 hours'), 0, 'and only once');

-- 3. Sunday evening nudge: next week is still a draft.
select is(public.run_publish_reminders(), 1, 'the manager is reminded that next week is a draft');
select is(public.run_publish_reminders(), 0, 'the reminder is sent once');
insert into public.schedule_weeks (branch_id, week_monday, status) select ba, monday, 'published' from ctx on conflict (branch_id, week_monday) do update set status = 'published';
delete from public.notifications where kind = 'publish_reminder';
select is(public.run_publish_reminders(), 0, 'a published next week needs no reminder');

-- 4. Auto publish of the week that has started.
insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at)
select ba, sa, this_monday, tpl, 'Morning', public.shift_start_at(this_monday, time '08:00'), public.shift_end_at(this_monday, time '08:00', time '12:00') from ctx;
select is(public.auto_publish_started_weeks(), 1, 'one branch has a draft started week');
select is((select auto_published from public.schedule_weeks where branch_id = (select ba from ctx) and week_monday = (select this_monday from ctx)), true, 'it is marked as published automatically');
select is((select count(*)::int from public.schedule_history where branch_id = (select ba from ctx) and action = 'auto_publish'), 1, 'the history says it was automatic');

select * from finish();
rollback;
