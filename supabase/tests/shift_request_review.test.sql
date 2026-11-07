-- Shift registration step 3: reviewing requests (approve creates the shift, partial failure,
-- own requests, branch scope, the badge) and the roster that carries requests and availability.
begin;
\ir _helpers/setup.psql
select plan(17);

insert into public.roles (name) values ('t_mgr');
insert into public.role_permissions (role, permission, methods)
values ('t_mgr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('rv_mgr_a@test.local', b.ba, 't_mgr') as mgr_a,
  tests.create_staff('rv_mgr_b@test.local', b.bb, 't_mgr') as mgr_b,
  tests.create_staff('rv1@test.local', b.ba, 'cashier') as s1,
  tests.create_staff('rv2@test.local', b.ba, 'cashier') as s2,
  tests.create_staff('rv_b@test.local', b.bb, 'cashier') as sb,
  (date_trunc('week', current_date)::date + 14) as monday,
  gen_random_uuid() as tpl_a, gen_random_uuid() as tpl_b
from (select tests.create_branch('RVA') as ba, tests.create_branch('RVB') as bb) b;
alter table ctx add column res jsonb, add column r1 uuid, add column r2 uuid, add column r3 uuid, add column rb uuid, add column rm uuid;
grant select, update on ctx to authenticated;

insert into public.shift_templates (id, branch_id, name, start_time, end_time)
select tpl_a, ba, 'Morning', time '08:00', time '12:00' from ctx
union all select tpl_b, bb, 'Morning', time '08:00', time '12:00' from ctx;

-- Requests inserted as the owner: s1 morning Monday and Tuesday, s2 morning Monday, sb at branch B,
-- the manager's own, and one already started.
create or replace function pg_temp.req(p_user uuid, p_branch uuid, p_date date, p_tpl uuid) returns uuid language sql as $$
  insert into public.shift_requests (branch_id, user_id, user_name, work_date, template_id, name, start_at, end_at)
  values (p_branch, p_user, 'u', p_date, p_tpl, 'Morning', public.shift_start_at(p_date, time '08:00'), public.shift_end_at(p_date, time '08:00', time '12:00'))
  returning id;
$$;
update ctx set
  r1 = pg_temp.req(s1, ba, monday, tpl_a),
  r2 = pg_temp.req(s1, ba, monday + 1, tpl_a),
  r3 = pg_temp.req(s2, ba, monday, tpl_a),
  rb = pg_temp.req(sb, bb, monday, tpl_b),
  rm = pg_temp.req(mgr_a, ba, monday + 2, tpl_a);

-- Staff cannot decide.
select tests.login(s2) from ctx;
set local role authenticated;
select is((select (public.decide_shift_requests(array[r1], true) -> 'failed' -> 0 ->> 'hint') from ctx), 'forbidden', 'staff cannot decide');
reset role;

-- A manager of A: the list and the badge only show A.
select tests.login(mgr_a) from ctx;
set local role authenticated;
select is((select (public.list_shift_requests(null, 'pending') ->> 'total')::int), 4, 'a null branch lists only the branches the manager may view');
select is((select public.pending_shift_request_count(null)), 3, 'the badge skips the manager''s own request and other branches');
select throws_ok(format('select public.list_shift_requests(%L)', (select bb from ctx)), '42501', 'not allowed at this branch', 'asking for another branch is refused');
select is((select public.list_shift_requests(ba, 'pending', null, null, 'u') -> 'rows' -> 0 ->> 'user_name' from ctx), 'u', 'search by name works');

-- Approve two: shifts appear on the roster.
update ctx set res = public.decide_shift_requests(array[r1, r3], true, 'ok');
select is((select res ->> 'approved' from ctx), '2', 'two requests are approved');
select is((select count(*)::int from public.shift_assignments where branch_id = (select ba from ctx) and name = 'Morning'), 2, 'approving creates shifts');
select is((select count(*)::int from public.shift_requests where assignment_id is not null and status = 'approved'), 2, 'the request points at its shift');
select is((select jsonb_array_length(public.shift_roster(ba, monday, monday + 6) -> 'assignments') from ctx), 2, 'the roster shows the new shifts');
select ok((select public.shift_roster(ba, monday, monday + 6) ?& array['staff', 'templates', 'assignments', 'leaves', 'requests', 'availability'] from ctx), 'the roster keeps its old keys and adds requests and availability');
select is((select jsonb_array_length(public.shift_roster(ba, monday, monday + 6) -> 'requests') from ctx), 2, 'pending requests remain on the roster');

-- Partial failure and the rules.
update ctx set res = public.decide_shift_requests(array[r1, r2, rb, rm], true);
select is((select array_agg(e ->> 'hint' order by e ->> 'hint') from ctx, jsonb_array_elements(res -> 'failed') e),
  array['forbidden', 'not_pending', 'own_request'], 'decided, other-branch and own requests fail with reasons');
select is((select res ->> 'approved' from ctx), '1', 'the valid one is still approved');

-- Overlap with a shift added by hand, then an expired request.
reset role;
update ctx set r1 = pg_temp.req(s2, ba, monday + 3, tpl_a);
insert into public.shift_assignments (branch_id, user_id, work_date, name, start_at, end_at)
select ba, s2, monday + 3, 'Elsewhere', public.shift_start_at(monday + 3, time '09:00'), public.shift_end_at(monday + 3, time '09:00', time '10:00') from ctx;
update ctx set r3 = pg_temp.req(s2, ba, current_date - 3, tpl_a);
select tests.login(mgr_a) from ctx;
set local role authenticated;
update ctx set res = public.decide_shift_requests(array[r1, r3], true);
select is((select array_agg(e ->> 'hint' order by e ->> 'hint') from ctx, jsonb_array_elements(res -> 'failed') e),
  array['shift_overlap', 'too_late'], 'a clash and a started shift cannot be approved');

-- Rejecting with a note; the manager's own request is the super admin's job.
update ctx set res = public.decide_shift_requests(array[r1], false, 'full');
select is((select decision_note from public.shift_requests where id = (select r1 from ctx)), 'full', 'a rejection keeps its note');
reset role;

-- A manager of B cannot decide A's requests.
select tests.login(mgr_b) from ctx;
set local role authenticated;
select is((select public.decide_shift_requests(array[r2], false) -> 'failed' -> 0 ->> 'hint' from ctx), 'forbidden', 'a manager of another branch cannot decide');
select is((select public.pending_shift_request_count(null)), 1, 'branch B sees only its own pending request');

select * from finish();
rollback;
