-- Attendance step 4: the timesheet numbers. Late and early with and without grace, overtime under and
-- over the threshold, absence, a half day of leave, a shift across midnight, an unscheduled entry, the
-- monthly grid codes and the caller's own timesheet.
begin;
\ir _helpers/setup.psql
select plan(22);

insert into public.roles (name) values ('t_hr');
insert into public.role_permissions (role, permission, methods)
values ('t_hr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'EXPORT', 'SETTING']);

create temp table ctx as
select b.ba,
  tests.create_staff('rhr@test.local', b.ba, 't_hr') as hr,
  tests.create_staff('r1@test.local', b.ba, 'cashier') as s1,
  tests.create_staff('r2@test.local', b.ba, 'cashier') as s2,
  tests.create_staff('r3@test.local', b.ba, 'cashier') as s3,
  tests.create_staff('r4@test.local', b.ba, 'cashier') as s4,
  tests.create_staff('r5@test.local', b.ba, 'cashier') as s5,
  tests.create_staff('r6@test.local', b.ba, 'cashier') as s6,
  tests.create_staff('r7@test.local', b.ba, 'cashier') as s7,
  (date_trunc('week', current_date)::date - 14) as d
from (select tests.create_branch('RA') as ba) b;
alter table ctx add column res jsonb;
grant select, update on ctx to authenticated;

-- Times are Vietnam time on a Monday two weeks back.
create function pg_temp.at(p_day date, p_time time) returns timestamptz language sql as
$$ select (p_day + p_time) at time zone 'Asia/Ho_Chi_Minh' $$;
create function pg_temp.shift(p_user uuid, p_branch uuid, p_day date, p_from time, p_to time, p_to_day date default null)
returns uuid language sql as $$
  insert into public.shift_assignments (branch_id, user_id, work_date, name, start_at, end_at)
  values (p_branch, p_user, p_day, 'Day', pg_temp.at(p_day, p_from), pg_temp.at(coalesce(p_to_day, p_day), p_to)) returning id;
$$;
create function pg_temp.entry(p_user uuid, p_branch uuid, p_assignment uuid, p_in timestamptz, p_out timestamptz)
returns void language sql as $$
  insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, check_out_at, in_source, out_source)
  values (p_branch, p_user, 'x', p_assignment, p_in, p_out, 'manager', 'manager');
$$;

-- s1 on time within grace; s2 late 20 and 10 early; s3 overtime 45 (and 20 on day two, below 30);
-- s4 never came; s5 worked without a shift; s6 worked a night shift; s7 had a morning of leave.
select pg_temp.entry(s1, ba, pg_temp.shift(s1, ba, d, '08:00', '14:00'), pg_temp.at(d, '08:03'), pg_temp.at(d, '14:00')) from ctx;
select pg_temp.entry(s2, ba, pg_temp.shift(s2, ba, d, '08:00', '14:00'), pg_temp.at(d, '08:20'), pg_temp.at(d, '13:50')) from ctx;
select pg_temp.entry(s3, ba, pg_temp.shift(s3, ba, d, '08:00', '14:00'), pg_temp.at(d, '08:00'), pg_temp.at(d, '14:45')) from ctx;
select pg_temp.entry(s3, ba, pg_temp.shift(s3, ba, d + 1, '08:00', '14:00'), pg_temp.at(d + 1, '08:00'), pg_temp.at(d + 1, '14:20')) from ctx;
select pg_temp.shift(s4, ba, d, '08:00', '14:00') from ctx;
select pg_temp.entry(s5, ba, null, pg_temp.at(d, '09:00'), pg_temp.at(d, '11:00')) from ctx;
select pg_temp.entry(s6, ba, pg_temp.shift(s6, ba, d, '22:00', '06:00', d + 1), pg_temp.at(d, '22:00'), pg_temp.at(d + 1, '06:00')) from ctx;
select pg_temp.shift(s7, ba, d, '08:00', '14:00') from ctx;
insert into public.leave_requests (user_id, user_name, branch_id, leave_type, from_date, to_date, part, days, reason, status)
select s7, 'r7', ba, 'annual', d, d, 'am', 0.5, 'Morning off', 'approved' from ctx;

select tests.login(hr) from ctx;
set local role authenticated;
update ctx set res = public.report_timesheet(ba, d, d + 6, null, 50, 0);

create function pg_temp.row_of(p_res jsonb, p_user uuid) returns jsonb language sql as
$$ select r from jsonb_array_elements(p_res -> 'rows') r where (r ->> 'user_id')::uuid = p_user $$;

select is((select (res ->> 'total')::int from ctx), 8, 'the summary lists every staff member of the branch');
select is((select (pg_temp.row_of(res, s1) ->> 'late_count')::int from ctx), 0, 'three minutes late is inside the grace');
select is((select (pg_temp.row_of(res, s1) ->> 'worked_minutes')::int from ctx), 357, 'worked minutes are out minus in');
select is((select (pg_temp.row_of(res, s2) ->> 'late_minutes')::int from ctx), 20, 'twenty minutes late is counted');
select is((select (pg_temp.row_of(res, s2) ->> 'early_minutes')::int from ctx), 10, 'ten minutes early is counted');
select is((select (pg_temp.row_of(res, s3) ->> 'overtime_minutes')::int from ctx), 45, 'overtime counts only above the threshold');
select is((select (pg_temp.row_of(res, s3) ->> 'shifts_worked')::int from ctx), 2, 'two worked shifts');
select is((select (pg_temp.row_of(res, s4) ->> 'absent_count')::int from ctx), 1, 'a shift nobody clocked into is an absence');
select is((select (pg_temp.row_of(res, s5) ->> 'unscheduled_count')::int from ctx), 1, 'an entry without a shift is unscheduled');
select is((select (pg_temp.row_of(res, s6) ->> 'worked_minutes')::int from ctx), 480, 'a night shift across midnight counts whole');
select is((select (pg_temp.row_of(res, s7) ->> 'leave_annual')::numeric from ctx), 0.5, 'half a day of leave is 0.5');
select is((select (pg_temp.row_of(res, s7) ->> 'absent_count')::int from ctx), 0, 'a shift covered by leave is no absence');

-- Search and paging.
select is((select (public.report_timesheet(ba, d, d + 6, 'r3', 10, 0) ->> 'total')::int from ctx), 1, 'the summary searches by name');
select is((select jsonb_array_length(public.report_timesheet(ba, d, d + 6, null, 3, 0) -> 'rows') from ctx), 3, 'the summary pages');
select throws_ok(format('select public.report_timesheet(%L, %L, %L)', (select ba from ctx), (select d from ctx), (select d + 120 from ctx)),
  '22023', 'date range is longer than 93 days', 'a range over 93 days is refused');

-- The monthly grid.
update ctx set res = public.report_timesheet_grid(ba, d);
create function pg_temp.code_of(p_res jsonb, p_user uuid, p_day date) returns text language sql as
$$ select c ->> 'code' from jsonb_array_elements(p_res -> 'staff') s, jsonb_array_elements(s -> 'cells') c
   where (s ->> 'user_id')::uuid = p_user and (c ->> 'date')::date = p_day $$;
select is((select pg_temp.code_of(res, s1, d) from ctx), 'X', 'worked on time is X');
select is((select pg_temp.code_of(res, s2, d) from ctx), 'M', 'late and early shows as M');
select is((select pg_temp.code_of(res, s4, d) from ctx), 'V', 'absent is V');
select is((select pg_temp.code_of(res, s5, d) from ctx), 'X+', 'worked without a shift is X+');
select is((select pg_temp.code_of(res, s6, d) from ctx), 'X', 'the night shift sits on the day it started');
select is((select pg_temp.code_of(res, s7, d) from ctx), 'P', 'annual leave is P');
select throws_ok(format('select public.report_timesheet_grid(null, %L)', (select d from ctx)), '22023', 'a branch and a month are required', 'the grid needs one branch');
reset role;

select * from finish();
rollback;
