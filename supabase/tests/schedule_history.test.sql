-- Schedule history: every assignment and request change is logged by a trigger, with who, why and
-- from which RPC; the log is append-only; the branch scope holds; calls without a reason still work.
begin;
\ir _helpers/setup.psql
select plan(20);

insert into public.roles (name) values ('t_hist');
insert into public.role_permissions (role, permission, methods)
values ('t_hist', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('hi_mgr_a@test.local', b.ba, 't_hist') as mgr_a,
  tests.create_staff('hi_mgr_b@test.local', b.bb, 't_hist') as mgr_b,
  tests.create_staff('hi_s1@test.local', b.ba, 'cashier') as s1,
  tests.create_staff('hi_sb@test.local', b.bb, 'cashier') as sb,
  (date_trunc('week', current_date)::date + 14) as monday,
  gen_random_uuid() as tpl_a, gen_random_uuid() as tpl_b
from (select tests.create_branch('HIA') as ba, tests.create_branch('HIB') as bb) b;
alter table ctx add column res jsonb, add column shift_id uuid, add column req_id uuid;
grant select, update on ctx to authenticated;

insert into public.shift_templates (id, branch_id, name, start_time, end_time)
select tpl_a, ba, 'Morning', time '08:00', time '12:00' from ctx
union all select tpl_b, bb, 'Morning', time '08:00', time '12:00' from ctx;
insert into public.shift_registration_settings (branch_id, is_open, weeks_ahead) select ba, true, 4 from ctx;

select tests.login(mgr_a) from ctx;
set local role authenticated;

-- Assign with a reason.
update ctx set res = public.assign_shift(ba, s1, monday, tpl_a, null, null, null, 'note 1', 'covering for Lan');
update ctx set shift_id = (res ->> 'id')::uuid;
select is((select count(*)::int from public.schedule_history where entity = 'assignment' and action = 'insert' and entity_id = (select shift_id::text from ctx)), 1, 'assigning logs an insert');
select is((select reason from public.schedule_history where action = 'insert' and entity_id = (select shift_id::text from ctx)), 'covering for Lan', 'the reason is kept');
select is((select actor_name from public.schedule_history where action = 'insert' and entity_id = (select shift_id::text from ctx)), 'hi_mgr_a', 'the actor name is saved');
select is((select source from public.schedule_history where action = 'insert' and entity_id = (select shift_id::text from ctx)), 'assign_shift', 'the RPC name is saved');
select is((select week_monday from public.schedule_history where action = 'insert' and entity_id = (select shift_id::text from ctx)), (select monday from ctx), 'the week is the Monday of the work date');

-- Update: changed fields, and a no-op writes nothing.
select public.update_shift_assignment((select shift_id from ctx), '{"note":"note 2"}'::jsonb, 'typo');
select is((select changed_fields from public.schedule_history where action = 'update' and entity_id = (select shift_id::text from ctx)), array['note'], 'update lists the changed columns');
select public.update_shift_assignment((select shift_id from ctx), '{"note":"note 2"}'::jsonb);
select is((select count(*)::int from public.schedule_history where action = 'update' and entity_id = (select shift_id::text from ctx)), 1, 'an update that changes nothing is not logged');

-- Remove (old call style, no reason).
select public.remove_shift_assignment((select shift_id from ctx));
select is((select count(*)::int from public.schedule_history where action = 'delete' and entity_id = (select shift_id::text from ctx)), 1, 'removing logs a delete');
select is((select reason from public.schedule_history where action = 'delete' and entity_id = (select shift_id::text from ctx)), null, 'a call without a reason stores none');

-- Copy a week over an existing one.
select public.assign_shift((select ba from ctx), (select s1 from ctx), (select monday + 21 from ctx), (select tpl_a from ctx));
select public.copy_roster_week((select ba from ctx), (select monday + 21 from ctx), (select monday from ctx), false, 'copy');
select is((select count(*)::int from public.schedule_history where source = 'copy_roster_week' and action = 'insert'), 1, 'copying a week logs the new shift with the RPC name');
select public.copy_roster_week((select ba from ctx), (select monday + 21 from ctx), (select monday from ctx), true, 'again');
select is((select count(*)::int from public.schedule_history where source = 'copy_roster_week' and action = 'delete'), 1, 'overwriting logs the delete');

-- Requests: submit, approve, cancel.
reset role;
select tests.login(s1) from ctx;
set local role authenticated;
update ctx set res = public.submit_shift_requests(ba, monday + 7, format('[{"work_date":"%s","template_id":"%s"}]', monday + 7, tpl_a)::jsonb);
reset role;
update ctx set req_id = (select id from public.shift_requests where user_id = s1 and work_date = monday + 7);
select is((select count(*)::int from public.schedule_history where entity = 'request' and action = 'submit' and entity_id = (select req_id::text from ctx)), 1, 'submitting a request is logged');
select tests.login(mgr_a) from ctx;
set local role authenticated;
select public.decide_shift_requests(array[(select req_id from ctx)], true, 'ok', 'fits');
select is((select reason from public.schedule_history where entity = 'request' and action = 'approve'), 'fits', 'approving logs the reason');
select is((select count(*)::int from public.schedule_history where entity = 'assignment' and source = 'decide_shift_requests'), 1, 'the shift made by approving is logged too');

-- Availability: one line per save.
select public.save_staff_availability((select s1 from ctx), '[{"weekday":2,"kind":"unavailable"},{"weekday":3,"kind":"unavailable"}]'::jsonb);
select is((select count(*)::int from public.schedule_history where entity = 'availability' and action = 'replace'), 1, 'saving availability writes one line');
reset role;

-- Append-only, even for the owner.
select throws_ok($$update public.schedule_history set reason = 'x'$$, '42501', 'schedule_history is append-only', 'an update is refused');
select throws_ok($$delete from public.schedule_history$$, '42501', 'schedule_history is append-only', 'a delete is refused');

-- Scope.
select tests.login(mgr_b) from ctx;
set local role authenticated;
select throws_ok(format('select public.schedule_history_list(%L)', (select ba from ctx)), '42501', 'not allowed at this branch', 'another branch is refused');
select ok(not exists (select 1 from public.schedule_history where branch_id = (select ba from ctx)), 'row level security hides the other branch');
select is((select (public.schedule_history_list(null) ->> 'total')::int), 0, 'a null branch lists only branches I may view');
reset role;

select * from finish();
rollback;
