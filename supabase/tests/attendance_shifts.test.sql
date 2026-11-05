-- Attendance step 1: shift templates, roster, settings and branch scope.
begin;
\ir _helpers/setup.psql
select plan(23);

insert into public.roles (name) values ('t_hr');
insert into public.role_permissions (role, permission, methods)
values ('t_hr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select a as branch_a, b as branch_b,
       date_trunc('week', current_date)::date + 7 as monday
from tests.create_branch('AA') as a, tests.create_branch('AB') as b;
alter table ctx
  add column hr_a uuid, add column hr_b uuid, add column s1 uuid, add column s2 uuid,
  add column outsider uuid, add column tpl_day uuid, add column tpl_night uuid, add column res jsonb;
update ctx set
  hr_a = tests.create_staff('hr-a@test.local', branch_a, 't_hr'),
  hr_b = tests.create_staff('hr-b@test.local', branch_b, 't_hr'),
  s1 = tests.create_staff('s1@test.local', branch_a, 'cashier'),
  s2 = tests.create_staff('s2@test.local', branch_a, 'cashier'),
  outsider = tests.create_staff('out@test.local', branch_b, 'cashier');
insert into public.staff_branches (user_id, branch_id, role) select s1, branch_b, 'cashier' from ctx;
grant select, update on ctx to authenticated;

-- A manager at A creates templates, including one that runs overnight.
select tests.login(hr_a) from ctx;
set local role authenticated;
update ctx set
  tpl_day = public.save_shift_template(branch_a, '{"name":"Ca sang","start_time":"08:00","end_time":"14:00"}'),
  tpl_night = public.save_shift_template(branch_a, '{"name":"Ca dem","start_time":"20:00","end_time":"08:00","break_minutes":60,"color":"violet"}');
select is((select count(*)::int from public.list_shift_templates((select branch_a from ctx))), 2, 'templates are listed');
select throws_ok(
  format($$select public.save_shift_template(%L, '{"name":"ca sang","start_time":"09:00","end_time":"12:00"}')$$, (select branch_a from ctx)),
  'P0001', 'a shift with this name exists', 'template names are unique per branch, ignoring case');
select throws_ok(
  format($$select public.save_shift_template(%L, '{"name":"Zero","start_time":"09:00","end_time":"09:00"}')$$, (select branch_a from ctx)),
  '22023', 'bad template', 'start and end cannot be equal');
select throws_ok(
  format($$select public.save_shift_template(%L, '{"name":"Long break","start_time":"09:00","end_time":"10:00","break_minutes":60}')$$, (select branch_a from ctx)),
  '22023', 'bad template', 'a break as long as the shift is refused');

-- Overnight assignment keeps the start date and ends the next morning (Vietnam time).
update ctx set res = public.assign_shift(branch_a, s1, monday, tpl_night);
select is(
  (select (a.end_at - a.start_at)::text from public.shift_assignments a where a.id = (select (res ->> 'id')::uuid from ctx)),
  '12:00:00', 'a 20:00-08:00 shift lasts 12 hours');
select is(
  (select (a.end_at at time zone 'Asia/Ho_Chi_Minh')::date - a.work_date from public.shift_assignments a where a.id = (select (res ->> 'id')::uuid from ctx)),
  1, 'the overnight shift ends the day after it starts');
select throws_ok(
  format($$select public.assign_shift(%L, %L, %L::date, null, '06:00'::time, '21:00'::time)$$, (select branch_a from ctx), (select s1 from ctx), (select monday from ctx)),
  'P0001', 'this person already has a shift at that time', 'overlapping shifts are refused');
select throws_ok(
  format($$select public.assign_shift(%L, %L, %L::date, %L)$$, (select branch_a from ctx), (select outsider from ctx), (select monday from ctx), (select tpl_day from ctx)),
  'P0001', 'this person does not work at the branch', 'only people of the branch can be scheduled');
select throws_ok(
  format($$select public.assign_shift(%L, %L, %L::date, null, '07:00'::time, '07:00'::time)$$, (select branch_a from ctx), (select s2 from ctx), (select monday from ctx)),
  '22023', 'start and end are required', 'a custom shift needs distinct times');
select throws_ok(
  format($$select public.assign_shift(%L, %L, %L::date, %L)$$, (select branch_b from ctx), (select s1 from ctx), (select monday from ctx), (select tpl_day from ctx)),
  '42501', 'not allowed', 'a manager at A cannot schedule at B');

-- Copy the week: the day shift for s2 and the night shift for s1 go to the next Monday.
select lives_ok(
  format($$select public.assign_shift(%L, %L, %L::date, %L)$$, (select branch_a from ctx), (select s2 from ctx), (select monday from ctx), (select tpl_day from ctx)),
  'a second person gets the day shift');
update ctx set res = public.copy_roster_week(branch_a, monday, monday + 7);
select is((select (res ->> 'copied')::int from ctx), 2, 'two shifts are copied to the next week');
update ctx set res = public.copy_roster_week(branch_a, monday, monday + 7);
select is((select (res ->> 'skipped')::int from ctx), 2, 'copying again skips cells that already have a shift');
select throws_ok(
  format($$select public.copy_roster_week(%L, %L::date + 1, %L::date + 8)$$, (select branch_a from ctx), (select monday from ctx), (select monday from ctx)),
  '22023', 'both dates must be different Mondays', 'copying needs Mondays');

-- Roster read and range limit.
select is(
  (select jsonb_array_length(public.shift_roster(branch_a, monday, monday + 13) -> 'assignments') from ctx), 4,
  'the roster of two weeks lists the four shifts');
select throws_ok(
  format($$select public.shift_roster(%L, %L::date, %L::date + 60)$$, (select branch_a from ctx), (select monday from ctx), (select monday from ctx)),
  '22023', 'date range is longer than 42 days', 'the roster range is limited');

-- Settings: a manager saves, the staff reads.
select is((public.save_attendance_settings((select branch_a from ctx), '{"late_grace_minutes":10}') ->> 'late_grace_minutes')::int, 10, 'settings are saved');
select throws_ok(
  format($$select public.save_attendance_settings(%L, '{"late_grace_minutes":600}')$$, (select branch_a from ctx)),
  '22023', 'settings out of range', 'out of range settings are refused');
reset role;

-- The same person at another branch cannot be double booked across branches.
select tests.login(hr_b) from ctx;
set local role authenticated;
select throws_ok(
  format($$select public.assign_shift(%L, %L, %L::date, null, '21:00'::time, '23:00'::time)$$, (select branch_b from ctx), (select s1 from ctx), (select monday from ctx)),
  'P0001', 'this person already has a shift at that time', 'a person cannot be booked at two branches at once');
reset role;

-- Plain staff read their own branch but cannot manage.
select tests.login(s1) from ctx;
set local role authenticated;
select is((select count(*)::int from public.list_shift_templates((select branch_a from ctx))), 2, 'staff of the branch read the templates');
select is((public.attendance_rules((select branch_a from ctx)) ->> 'late_grace_minutes')::int, 10, 'staff read the branch rules');
select throws_ok(
  format($$select public.shift_roster(%L, current_date, current_date)$$, (select branch_a from ctx)),
  '42501', 'not allowed', 'staff without the permission cannot read the whole roster');
select throws_ok(
  format($$select public.save_shift_template(%L, '{"name":"X","start_time":"09:00","end_time":"10:00"}')$$, (select branch_a from ctx)),
  '42501', 'not allowed', 'staff cannot create templates');

select * from finish();
rollback;
