-- Shift registration step 2: the window, sending requests (partial success), limits, warnings,
-- cancelling and who can see what.
begin;
\ir _helpers/setup.psql
select plan(24);

insert into public.roles (name) values ('t_mgr');
insert into public.role_permissions (role, permission, methods)
values ('t_mgr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('sr_mgr@test.local', b.ba, 't_mgr') as mgr,
  tests.create_staff('sr1@test.local', b.ba, 'cashier') as s1,
  tests.create_staff('sr2@test.local', b.ba, 'cashier') as s2,
  tests.create_staff('sr_out@test.local', b.bb, 'cashier') as outsider,
  (date_trunc('week', current_date)::date + 14) as next_monday,
  (date_trunc('week', current_date)::date + 35) as far_monday,
  gen_random_uuid() as morning, gen_random_uuid() as evening, gen_random_uuid() as retired
from (select tests.create_branch('SRA') as ba, tests.create_branch('SRB') as bb) b;
alter table ctx add column res jsonb;
grant select, update on ctx to authenticated;

insert into public.shift_templates (id, branch_id, name, start_time, end_time, break_minutes)
select morning, ba, 'Morning', time '08:00', time '12:00', 0 from ctx
union all select evening, ba, 'Evening', time '16:00', time '22:00', 0 from ctx
union all select retired, ba, 'Retired', time '12:00', time '16:00', 0 from ctx;
update public.shift_templates set is_active = false where id = (select retired from ctx);

-- Registration is off until a manager opens it.
select tests.login(s1) from ctx;
set local role authenticated;
select throws_ok(format('select public.submit_shift_requests(%L, %L, %L::jsonb)', (select ba from ctx), (select next_monday from ctx),
  format('[{"work_date":"%s","template_id":"%s"}]', (select next_monday from ctx), (select morning from ctx))),
  'P0001', 'registration is closed (closed)', 'a closed branch takes no requests');
select throws_ok(format('select public.save_shift_registration_settings(%L, %L::jsonb)', (select ba from ctx), '{"is_open":true}'),
  '42501', 'not allowed', 'staff cannot change the window');
reset role;

select tests.login(mgr) from ctx;
set local role authenticated;
update ctx set res = public.save_shift_registration_settings(ba, '{"is_open":true,"weeks_ahead":3,"close_days_before":2,"max_shifts_per_week":3,"staff_note":"Weekends need 2"}'::jsonb);
select is((select res ->> 'staff_note' from ctx), 'Weekends need 2', 'a manager opens the window');
select throws_ok(format('select public.save_shift_registration_settings(%L, %L::jsonb)', (select ba from ctx), '{"weeks_ahead":9}'),
  '22023', 'invalid settings', 'settings are range checked');
reset role;

-- The window: open next week, too far, the running week, and the deadline.
select is((select public.shift_registration_window(ba, next_monday) ->> 'open' from ctx), 'true', 'next week is open');
select is((select public.shift_registration_window(ba, far_monday) ->> 'reason' from ctx), 'too_far', 'a week beyond weeks_ahead is too far');
select is((select public.shift_registration_window(ba, date_trunc('week', current_date)::date) ->> 'reason' from ctx), 'past_deadline', 'the running week has passed its deadline');
select is((select (public.shift_registration_window(ba, next_monday) ->> 'closes_at')::timestamptz from ctx),
  (select ((next_monday - 2)::timestamp at time zone 'Asia/Ho_Chi_Minh') from ctx), 'the deadline is midnight Vietnam time, two days before Monday');

-- Several cells at once: the good ones are created, a bad one is reported.
select tests.login(s1) from ctx;
set local role authenticated;
update ctx set res = public.submit_shift_requests(ba, next_monday, format(
  '[{"work_date":"%s","template_id":"%s"},{"work_date":"%s","template_id":"%s"},{"work_date":"%s","template_id":"%s"},{"work_date":"%s","template_id":"%s"}]',
  next_monday, morning, next_monday + 1, evening, next_monday + 2, retired, next_monday + 9, morning)::jsonb, 'please');
select is((select jsonb_array_length(res -> 'created') from ctx), 2, 'valid cells are created');
select is((select array_agg(e ->> 'hint' order by e ->> 'hint') from ctx, jsonb_array_elements(res -> 'skipped') e),
  array['bad_input', 'not_found'], 'a retired template and a date outside the week are skipped with reasons');
select is((select count(*)::int from public.shift_requests where user_id = (select s1 from ctx) and note = 'please'), 2, 'the note is kept');

-- The same cell twice; the weekly limit (3 including the pending ones).
update ctx set res = public.submit_shift_requests(ba, next_monday,
  format('[{"work_date":"%s","template_id":"%s"}]', next_monday, morning)::jsonb);
select is((select res -> 'skipped' -> 0 ->> 'hint' from ctx), 'duplicate', 'the same cell is requested once');
update ctx set res = public.submit_shift_requests(ba, next_monday, format(
  '[{"work_date":"%s","template_id":"%s"},{"work_date":"%s","template_id":"%s"}]', next_monday + 3, morning, next_monday + 4, morning)::jsonb);
select is((select jsonb_array_length(res -> 'created') || '/' || (res -> 'skipped' -> 0 ->> 'hint') from ctx), '1/over_weekly_limit', 'the weekly limit stops the extra cell');

-- Overlap with a shift already on the roster, at any branch.
reset role;
insert into public.shift_assignments (branch_id, user_id, work_date, name, start_at, end_at)
select bb, s2, next_monday + 5, 'Elsewhere', public.shift_start_at(next_monday + 5, time '07:00'), public.shift_end_at(next_monday + 5, time '07:00', time '11:00') from ctx;
select tests.login(outsider) from ctx;
set local role authenticated;
select throws_ok(format('select public.submit_shift_requests(%L, %L, %L::jsonb)', (select ba from ctx), (select next_monday from ctx), '[]'),
  'P0001', 'you do not work at this branch', 'staff of only another branch cannot send here');
reset role;
select tests.login(s2) from ctx;
set local role authenticated;
update ctx set res = public.submit_shift_requests(ba, next_monday,
  format('[{"work_date":"%s","template_id":"%s"}]', next_monday + 5, morning)::jsonb);
select is((select res -> 'skipped' -> 0 ->> 'hint' from ctx), 'shift_overlap', 'a request overlapping a shift at another branch is skipped');

-- Warnings: unavailable and on leave.
select public.save_my_availability('[{"weekday":2,"kind":"unavailable"}]'::jsonb);
update ctx set res = public.submit_shift_requests(ba, next_monday,
  format('[{"work_date":"%s","template_id":"%s"}]', next_monday + 1, morning)::jsonb);
select is((select res -> 'created' -> 0 ->> 'warning' from ctx), 'unavailable', 'a day the person blocked comes with a warning');
reset role;
insert into public.leave_requests (user_id, user_name, branch_id, leave_type, from_date, to_date, days, reason, status)
select s2, 's2', ba, 'annual', next_monday + 2, next_monday + 2, 1, 'x', 'approved' from ctx;
select tests.login(s2) from ctx;
set local role authenticated;
update ctx set res = public.submit_shift_requests(ba, next_monday,
  format('[{"work_date":"%s","template_id":"%s"}]', next_monday + 2, morning)::jsonb);
select is((select res -> 'created' -> 0 ->> 'warning' from ctx), 'on_leave', 'a day of approved leave comes with a warning');

-- The board and my requests.
select is((select jsonb_array_length(public.shift_registration_board((select ba from ctx), (select next_monday from ctx)) -> 'requests')), 2,
  'the board lists my own requests only');
select is((select jsonb_array_length(public.my_shift_requests((select next_monday from ctx), (select next_monday + 6 from ctx)))), 2, 'my_shift_requests lists them across branches');
select throws_ok(format('select public.my_shift_requests(%L, %L)', (select next_monday from ctx), (select next_monday + 120 from ctx)),
  '22023', 'date range is longer than 93 days', 'the range is capped');

-- Cancelling: own pending request only.
create temp table mine as select id from public.shift_requests where user_id = (select s2 from ctx) limit 1;
grant select on mine to authenticated;
select lives_ok(format('select public.cancel_shift_request(%L)', (select id from mine)), 'a pending request is cancelled');
select throws_ok(format('select public.cancel_shift_request(%L)', (select id from mine)), 'P0001', 'the request was already decided', 'a cancelled request cannot be cancelled again');
reset role;

-- Who sees what through the table.
select tests.login(s1) from ctx;
set local role authenticated;
select is((select count(*)::int from public.shift_requests where user_id = (select s2 from ctx)), 0, 'a colleague does not see my requests');
reset role;
select tests.login(mgr) from ctx;
set local role authenticated;
select ok((select count(*)::int from public.shift_requests where user_id = (select s2 from ctx)) > 0, 'a manager of the branch sees them');

select * from finish();
rollback;
