-- Attendance reports must never read has_permission(..., null): a null branch expands to the branches
-- the caller may view, and nothing else.
begin;
\ir _helpers/setup.psql
select plan(8);

insert into public.roles (name) values ('t_hr');
insert into public.role_permissions (role, permission, methods)
values ('t_hr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'EXPORT', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('bs-hr-a@test.local', b.ba, 't_hr') as hr_a,
  tests.create_staff('bs-hr-b@test.local', b.bb, 't_hr') as hr_b,
  tests.create_staff('bs-a@test.local', b.ba, 'cashier') as staff_a,
  tests.create_staff('bs-b@test.local', b.bb, 'cashier') as staff_b,
  (date_trunc('week', current_date)::date - 7) as d
from (select tests.create_branch('SA') as ba, tests.create_branch('SB') as bb) b;
alter table ctx add column res jsonb;
grant select, update on ctx to authenticated;

select tests.login(hr_a) from ctx;
set local role authenticated;
update ctx set res = public.report_timesheet(null, d, d + 6, null, 50, 0);
select ok((select (res ->> 'total')::int = 2 from ctx), 'a null branch lists only the staff of the branches the manager may view');
select ok(not exists (select 1 from ctx, jsonb_array_elements(res -> 'rows') r where (r ->> 'user_id')::uuid in (staff_b, hr_b)),
  'nobody of the other branch appears');
select throws_ok(format('select public.report_timesheet(%L, %L, %L)', (select bb from ctx), (select d from ctx), (select d + 6 from ctx)),
  '42501', 'not allowed at this branch', 'a named branch without the permission is refused');
select throws_ok(format('select public.report_timesheet_grid(%L, %L)', (select bb from ctx), (select d from ctx)),
  '42501', 'not allowed at this branch', 'the grid of another branch is refused');
select is((select count(*)::int from jsonb_array_elements(public.report_timesheet_grid((select ba from ctx), (select d from ctx)) -> 'staff')), 2,
  'the grid lists the staff of its own branch');
reset role;

-- Staff without the permission read only their own timesheet.
select tests.login(staff_a) from ctx;
set local role authenticated;
select throws_ok(format('select public.report_timesheet(null, %L, %L)', (select d from ctx), (select d + 6 from ctx)),
  '42501', 'not allowed', 'staff without the permission cannot read the summary');
select lives_ok(format('select public.my_timesheet(%L, %L)', (select d from ctx), (select d + 6 from ctx)), 'anyone reads their own timesheet');
select is((select jsonb_array_length(public.my_timesheet((select d from ctx), (select d + 6 from ctx)) -> 'rows')), 0, 'it holds only their own rows');
reset role;

select * from finish();
rollback;
