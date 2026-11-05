-- Attendance step 3: leave requests, half days, closed days, overlaps, approval rules, allowance
-- warnings, balances, branch scope and the roster that shows approved leave.
begin;
\ir _helpers/setup.psql
select plan(32);

insert into public.roles (name) values ('t_hr');
insert into public.role_permissions (role, permission, methods)
values ('t_hr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('lhr@test.local', b.ba, 't_hr') as hr,
  tests.create_staff('l1@test.local', b.ba, 'cashier') as s1,
  tests.create_staff('l2@test.local', b.ba, 'cashier') as s2,
  tests.create_staff('l3@test.local', b.ba, 'cashier') as s3,
  tests.create_staff('l4@test.local', b.ba, 'cashier') as s4,
  tests.create_staff('lout@test.local', b.bb, 'cashier') as outsider,
  (date_trunc('week', current_date)::date + 7) as d0
from (select tests.create_branch('LA') as ba, tests.create_branch('LB') as bb) b;
alter table ctx add column res jsonb, add column id1 uuid, add column id2 uuid, add column id3 uuid;
grant select, update on ctx to authenticated;

-- Sundays are closed at branch A.
insert into public.branch_hours (branch_id, weekday, open_time, close_time, is_closed)
select ba, 7, time '08:00', time '20:00', true from ctx;

-- A full week asks for six days (Sunday is closed); a morning asks for half a day.
select tests.login(s1) from ctx;
set local role authenticated;
update ctx set res = public.request_leave(ba, 'annual', d0, d0 + 6, 'full', 'Family trip');
select is((select (res ->> 'days')::numeric from ctx), 6.0, 'a week counts only the days the branch is open');
update ctx set id1 = (res ->> 'id')::uuid;
update ctx set res = public.request_leave(ba, 'sick', d0 + 14, d0 + 14, 'am', 'Doctor');
select is((select (res ->> 'days')::numeric from ctx), 0.5, 'a half day counts 0.5');
select throws_ok(format('select public.request_leave(%L, %L, %L, %L, %L, %L)', (select ba from ctx), 'annual', (select d0 + 20 from ctx), (select d0 + 21 from ctx), 'am', 'x'),
  '22023', 'invalid leave request', 'a half day cannot span several days');
select throws_ok(format('select public.request_leave(%L, %L, %L, %L, %L, %L)', (select ba from ctx), 'annual', (select d0 + 2 from ctx), (select d0 + 3 from ctx), 'full', 'x'),
  'P0001', 'those days overlap another request', 'two live requests cannot share a day');
select throws_ok(format('select public.request_leave(%L, %L, %L, %L, %L, %L)', (select ba from ctx), 'sick', current_date - 10, current_date - 10, 'full', 'x'),
  '22023', 'that date is too far in the past', 'a request cannot start more than a week ago');
select throws_ok(format('select public.request_leave(%L, %L, %L, %L, %L, %L)', (select ba from ctx), 'other', (select d0 + 30 from ctx), (select d0 + 30 from ctx), 'full', '   '),
  '22023', 'invalid leave request', 'a reason is required');
select throws_ok(format('select public.request_leave(%L, %L, %L, %L, %L, %L)', (select ba from ctx), 'other', (select d0 + 6 from ctx), (select d0 + 6 from ctx), 'full', 'x'),
  '22023', 'the branch is closed on those days', 'a day the branch is closed takes no leave')
  ;
reset role;

-- Somebody who does not work at the branch cannot file there.
select tests.login(outsider) from ctx;
set local role authenticated;
select throws_ok(format('select public.request_leave(%L, %L, %L, %L, %L, %L)', (select ba from ctx), 'annual', (select d0 from ctx), (select d0 from ctx), 'full', 'x'),
  '42501', 'not allowed', 'staff of another branch cannot file here');
update ctx set res = public.request_leave(bb, 'annual', d0, d0, 'full', 'Own branch');
reset role;

-- Only a manager decides; staff cannot.
select tests.login(s2) from ctx;
set local role authenticated;
select throws_ok(format('select public.decide_leave(%L, true)', (select id1 from ctx)), '42501', 'not allowed', 'staff cannot decide a request');
select throws_ok(format('select public.request_leave_for(%L, %L, %L, %L, %L, %L, %L)', (select s3 from ctx), (select ba from ctx), 'annual', (select d0 from ctx), (select d0 from ctx), 'full', 'x'),
  '42501', 'not allowed', 'staff cannot file for somebody else');
reset role;

select tests.login(hr) from ctx;
set local role authenticated;
select is((select public.pending_leave_count((select ba from ctx))), 2, 'the badge counts the pending requests of the branch');
update ctx set res = public.decide_leave(id1, true, 'Enjoy', 'unpaid');
select is((select res ->> 'status' from ctx), 'approved', 'a manager approves');
select is((select leave_type from public.leave_requests where id = (select id1 from ctx)), 'unpaid', 'approving can change the type');
select throws_ok(format('select public.decide_leave(%L, false)', (select id1 from ctx)), 'P0001', 'the request was already decided', 'a request is decided once');
select is((select jsonb_array_length(public.shift_roster((select ba from ctx), (select d0 from ctx), (select d0 + 6 from ctx)) -> 'leaves')), 1,
  'the roster shows the approved leave');
reset role;
select is((select public.leave_type_on(s1, (d0 + 1)::timestamptz + interval '3 hours') from ctx), 'unpaid', 'a shift on a leave day is covered');

-- Managers never decide or file for themselves.
select tests.login(hr) from ctx;
set local role authenticated;
update ctx set res = public.request_leave(ba, 'annual', d0 + 40, d0 + 40, 'full', 'Mine');
update ctx set id2 = (res ->> 'id')::uuid;
select throws_ok(format('select public.decide_leave(%L, true)', (select id2 from ctx)), 'P0001', 'you cannot decide your own request', 'a manager cannot approve their own leave');
select throws_ok(format('select public.request_leave_for(%L, %L, %L, %L, %L, %L, %L)', (select hr from ctx), (select ba from ctx), 'annual', (select d0 + 41 from ctx), (select d0 + 41 from ctx), 'full', 'x'),
  'P0001', 'you cannot approve your own leave', 'a manager cannot file approved leave for themselves');

-- Filed for somebody else, a request is approved at once.
update ctx set res = public.request_leave_for(s2, ba, 'sick', d0 + 3, d0 + 3, 'full', 'Called in sick');
select ok((select (res ->> 'id') is not null from ctx), 'a manager files a request for staff');
select is((select status from public.leave_requests where user_id = (select s2 from ctx)), 'approved', 'it is approved at once');

-- Allowance: 12 days by default, set per person, only a warning when exceeded.
select is((select (public.leave_balance((select s3 from ctx), extract(year from (select d0 from ctx))::int) ->> 'allowance')::numeric), 12.0, 'the default allowance is 12 days');
select lives_ok(format('select public.save_leave_allowance(%L, %s, 1)', (select s3 from ctx), (select extract(year from d0)::int from ctx)), 'a manager sets the allowance');
reset role;

select tests.login(s3) from ctx;
set local role authenticated;
update ctx set res = public.request_leave(ba, 'annual', d0 + 21, d0 + 22, 'full', 'Short break');
select is((select res ->> 'warning' from ctx), 'over_allowance', 'going over the allowance only warns');
update ctx set id3 = (res ->> 'id')::uuid;
select throws_ok(format('select public.save_leave_allowance(%L, 2026, 30)', (select s3 from ctx)), '42501', 'not allowed', 'staff cannot change their own allowance');
select throws_ok(format('select public.leave_balance(%L, 2026)', (select s1 from ctx)), '42501', 'not allowed', 'staff cannot read the balance of others');
select is((select (public.my_leave_requests() -> 'requests' -> 0 ->> 'id')::uuid from ctx), (select id3 from ctx), 'my requests list the newest first');
select is((select public.pending_leave_count()), 0, 'staff without the permission see no badge');
-- Cancel: a pending request any time; an approved one only before it starts.
select lives_ok(format('select public.cancel_leave(%L)', (select id3 from ctx)), 'staff withdraw a pending request');
reset role;

select tests.login(hr) from ctx;
set local role authenticated;
update ctx set res = public.request_leave_for(s4, ba, 'sick', current_date - 3, current_date - 3, 'full', 'Was ill');
reset role;
select tests.login(s4) from ctx;
set local role authenticated;
select throws_ok(format('select public.cancel_leave(%L)', (select (res ->> 'id')::uuid from ctx)), 'P0001', 'this request can no longer be cancelled', 'an approved request in the past stays');
reset role;

-- Branch scope: a null branch lists only the branches the caller may view.
select tests.login(hr) from ctx;
set local role authenticated;
select ok(not exists (
  select 1 from jsonb_array_elements(public.list_leave_requests(null, 'all') -> 'rows') r where (r ->> 'branch_id')::uuid = (select bb from ctx)
), 'a manager of branch A does not see requests of branch B');
select ok((select (public.list_leave_requests((select ba from ctx), 'approved') ->> 'total')::int >= 2 from ctx), 'the list filters by status');
reset role;

select tests.login(outsider) from ctx;
set local role authenticated;
select throws_ok(format('select public.list_leave_requests(%L)', (select ba from ctx)), '42501', 'not allowed at this branch', 'staff of branch B cannot list branch A');
reset role;

select * from finish();
rollback;
