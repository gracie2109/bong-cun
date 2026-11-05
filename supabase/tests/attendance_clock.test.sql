-- Attendance step 2: clock in/out, the early window, unscheduled entries, automatic closing, manager
-- corrections (reason, change log, never your own entry), branch scope and the attendance rows.
begin;
\ir _helpers/setup.psql
select plan(31);

insert into public.roles (name) values ('t_hr');
insert into public.role_permissions (role, permission, methods)
values ('t_hr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('hr-a@test.local', b.ba, 't_hr') as hr_a,
  tests.create_staff('hr-b@test.local', b.bb, 't_hr') as hr_b,
  tests.create_staff('c1@test.local', b.ba, 'cashier') as s1,
  tests.create_staff('c2@test.local', b.ba, 'cashier') as s2,
  tests.create_staff('c3@test.local', b.ba, 'cashier') as s3,
  tests.create_staff('c4@test.local', b.ba, 'cashier') as s4,
  tests.create_staff('c5@test.local', b.ba, 'cashier') as s5,
  tests.create_staff('c6@test.local', b.ba, 'cashier') as s6,
  tests.create_staff('c7@test.local', b.ba, 'cashier') as s7,
  tests.create_staff('c8@test.local', b.ba, 'cashier') as s8
from (select tests.create_branch('CA') as ba, tests.create_branch('CB') as bb) b;
alter table ctx add column res jsonb, add column entry uuid, add column shift uuid;
grant select, update on ctx to authenticated;

-- Fixtures written as the owner so the times are exact:
--  s1 started 30 minutes ago, s3 starts in 40 minutes (inside the 60 minute window),
--  s4 starts in 90 minutes (outside it), s6 ended an hour ago and never clocked in.
create function pg_temp.shift(p_user uuid, p_branch uuid, p_start timestamptz, p_end timestamptz)
returns uuid language sql as $$
  insert into public.shift_assignments (branch_id, user_id, work_date, name, start_at, end_at)
  values (p_branch, p_user, public.boarding_local_date(p_start), 'Test', p_start, p_end) returning id;
$$;
select pg_temp.shift(s1, ba, now() - interval '30 minutes', now() + interval '5 hours') from ctx;
select pg_temp.shift(s3, ba, now() + interval '40 minutes', now() + interval '5 hours') from ctx;
select pg_temp.shift(s4, ba, now() + interval '90 minutes', now() + interval '5 hours') from ctx;
select pg_temp.shift(s6, ba, now() - interval '5 hours', now() - interval '1 hour') from ctx;

-- A person with a scheduled shift clocks in and joins it, 30+ minutes late.
select tests.login(s1) from ctx;
set local role authenticated;
update ctx set res = public.clock_in(ba);
select ok((select (res ->> 'late_minutes')::int >= 30 from ctx), 'clocking in 30 minutes after the start is late');
select isnt((select res ->> 'assignment_id' from ctx), null, 'the entry is attached to the scheduled shift');
select throws_ok(format('select public.clock_in(%L)', (select ba from ctx)),
  'P0001', 'already clocked in', 'a second clock-in is refused');
select is((public.clock_status() -> 'open_entry' ->> 'shift_name'), 'Test', 'the clock status shows the open entry and its shift');
update ctx set res = public.clock_out();
select ok((select (res ->> 'worked_minutes')::int >= 0 from ctx), 'clocking out reports the minutes worked');
select throws_ok('select public.clock_out()', 'P0001', 'not clocked in', 'clocking out twice is refused');
reset role;

-- A shift inside the early window is joined; one outside it is treated as unscheduled.
select tests.login(s3) from ctx;
set local role authenticated;
select isnt((public.clock_in((select ba from ctx)) ->> 'assignment_id'), null, 'a shift starting in 40 minutes is joined');
reset role;
select tests.login(s4) from ctx;
set local role authenticated;
select throws_ok(format('select public.clock_in(%L)', (select ba from ctx)),
  'P0001', 'no shift is scheduled now', 'a shift 90 minutes away does not count and needs confirmation');
select is((public.clock_in((select ba from ctx), null, true) ->> 'assignment_id'), null, 'confirmed unscheduled clock-in has no shift');
select is((select review_reason from public.time_entries where user_id = (select s4 from ctx)), 'unscheduled', 'an unscheduled entry is flagged for review');
reset role;

-- With unscheduled work switched off, nobody without a shift can clock in.
insert into public.attendance_settings (branch_id, allow_unscheduled) select ba, false from ctx;
select tests.login(s2) from ctx;
set local role authenticated;
select throws_ok(format('select public.clock_in(%L, null, true)', (select ba from ctx)),
  'P0001', 'no shift is scheduled now', 'unscheduled clock-in can be switched off');
reset role;
delete from public.attendance_settings;

-- Somebody at another branch cannot clock in here.
select tests.login(hr_b) from ctx;
set local role authenticated;
select throws_ok(format('select public.clock_in(%L, null, true)', (select ba from ctx)),
  'P0001', 'you do not work at this branch', 'clocking in needs a row in staff_branches');
reset role;

-- An entry left open for 20 hours is closed by the next clock status with 0 minutes and a flag.
insert into public.time_entries (branch_id, user_id, user_name, check_in_at)
select ba, s5, 'c5', now() - interval '20 hours' from ctx;
select tests.login(s5) from ctx;
set local role authenticated;
select is(jsonb_typeof(public.clock_status() -> 'open_entry'), 'null', 'a stale entry is no longer open');
reset role;
select is((select review_reason || '/' || out_source || '/' || (check_out_at = check_in_at)::text from public.time_entries where user_id = (select s5 from ctx)),
  'missing_checkout/auto/true', 'it is closed at its own check-in time and flagged');
select is((select count(*)::int from public.time_entry_changes where user_id = (select s5 from ctx) and action = 'auto_close'), 1, 'the automatic close is logged');

-- Manager corrections.
select tests.login(hr_a) from ctx;
set local role authenticated;
update ctx set entry = (select id from public.time_entries where user_id = s5);
select throws_ok(
  format('select public.edit_time_entry(%L, now() - interval ''5 hours'', now() - interval ''1 hour'', null, %L)', (select entry from ctx), '  '),
  '22023', 'a reason is required', 'a correction needs a reason');
select throws_ok(
  format('select public.edit_time_entry(%L, now() - interval ''5 hours'', now() + interval ''1 hour'', null, %L)', (select entry from ctx), 'fix'),
  '22023', 'times must be in the past and in order', 'a correction cannot be in the future');
select lives_ok(
  format('select public.edit_time_entry(%L, now() - interval ''5 hours'', now() - interval ''1 hour'', null, %L)', (select entry from ctx), 'Forgot to clock out'),
  'a manager corrects the hours with a reason');
select is((select review_reason from public.time_entries where id = (select entry from ctx)), null, 'a corrected entry loses its review flag');
select is((select count(*)::int from public.time_entry_history((select entry from ctx))), 2, 'the history lists the automatic close and the correction');

-- A manager cannot edit their own entry, nor can a manager of another branch edit this one.
select public.clock_in((select ba from ctx), null, true);
select throws_ok(
  format('select public.edit_time_entry(%L, now() - interval ''2 hours'', null, null, %L)',
    (select id from public.time_entries where user_id = (select hr_a from ctx)), 'sneaky'),
  'P0001', 'you cannot change your own time entry', 'nobody edits their own entry');
reset role;
select tests.login(hr_b) from ctx;
set local role authenticated;
select throws_ok(
  format('select public.edit_time_entry(%L, now() - interval ''5 hours'', now() - interval ''1 hour'', null, %L)', (select entry from ctx), 'x'),
  '42501', 'not allowed', 'a manager of another branch cannot edit it');
select throws_ok(format('select public.attendance_today(%L)', (select ba from ctx)), '42501', 'not allowed', 'nor read the board of this branch');
reset role;

-- History: the owner reads their own, a colleague reads nothing.
select tests.login(s5) from ctx;
set local role authenticated;
select is((select count(*)::int from public.time_entry_history((select entry from ctx))), 2, 'the owner reads the history of their entry');
reset role;
select tests.login(s2) from ctx;
set local role authenticated;
select is((select count(*)::int from public.time_entry_history((select entry from ctx))), 0, 'a colleague reads nothing');
reset role;

-- The numbers in the attendance rows: grace, lateness, overtime and absence.
select pg_temp.shift(s7, ba, now() - interval '12 hours', now() - interval '8 hours') from ctx;
select pg_temp.shift(s8, ba, now() - interval '24 hours', now() - interval '20 hours') from ctx;
insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, check_out_at)
select ba, s7, 'c7', (select id from public.shift_assignments where user_id = s7), now() - interval '12 hours' + interval '10 minutes', now() - interval '8 hours' + interval '40 minutes' from ctx;
insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, check_out_at)
select ba, s8, 'c8', (select id from public.shift_assignments where user_id = s8), now() - interval '24 hours' + interval '3 minutes', now() - interval '20 hours' from ctx;

create temp table rows as
select * from public.attendance_rows(array[(select ba from ctx)], current_date - 3, current_date + 1);
select is((select late_minutes from rows where user_id = (select s7 from ctx)), 10, 'ten minutes late is late');
select is((select overtime_minutes from rows where user_id = (select s7 from ctx)), 40, '40 minutes after the end is overtime');
select is((select worked_minutes from rows where user_id = (select s7 from ctx)), 270, 'worked minutes are out minus in');
select is((select late_minutes || '/' || status from rows where user_id = (select s8 from ctx)), '0/present', 'three minutes late is inside the grace');
select is((select status from rows where user_id = (select s6 from ctx)), 'absent', 'a finished shift without an entry is absent');
select is((select count(*)::int from cron.job where jobname = 'close-stale-time-entries'), 1, 'the hourly closing job is scheduled');

select * from finish();
rollback;
