-- The attendance permission can only be given to admin roles through save_role.
begin;
\ir _helpers/setup.psql
select plan(4);

select throws_ok(
  $$select public.save_role('{"name":"t_hr","permissions":[{"id":"attendance","methods":["VIEW"]}]}'::jsonb)$$,
  '42501', 'attendance permission is only for admin roles',
  'a non-admin role cannot be granted attendance');

select lives_ok(
  $$select public.save_role('{"name":"t_hr","permissions":[{"id":"products","methods":["VIEW"]}]}'::jsonb)$$,
  'the same role can be saved without attendance');

select is((select count(*)::int from public.role_permissions where role = 't_hr' and permission = 'attendance'), 0,
  'no attendance row was written');

select lives_ok(
  $$select public.save_role('{"name":"admin","permissions":[{"id":"attendance","methods":["VIEW","UPDATE"]}]}'::jsonb, 'admin')$$,
  'the admin role keeps attendance');

select * from finish();
rollback;
