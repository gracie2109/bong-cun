-- Shift registration step 1: weekly availability (save, validation, scope, conflicts).
begin;
\ir _helpers/setup.psql
select plan(14);

insert into public.roles (name) values ('t_mgr');
insert into public.role_permissions (role, permission, methods)
values ('t_mgr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('av_mgr_a@test.local', b.ba, 't_mgr') as mgr_a,
  tests.create_staff('av1@test.local', b.ba, 'cashier') as s1,
  tests.create_staff('av2@test.local', b.ba, 'cashier') as s2,
  tests.create_staff('av_b@test.local', b.bb, 'cashier') as only_b,
  (date_trunc('week', current_date)::date + 14) as monday
from (select tests.create_branch('AVA') as ba, tests.create_branch('AVB') as bb) b;
alter table ctx add column res jsonb;
grant select, update on ctx to authenticated;

-- A person saves their own pattern and reads it back, sorted.
select tests.login(s1) from ctx;
set local role authenticated;
update ctx set res = public.save_my_availability(
  '[{"weekday":6,"kind":"preferred","start_time":"08:00","end_time":"14:00"},
    {"weekday":2,"kind":"unavailable"},
    {"weekday":5,"kind":"unavailable","start_time":"20:00","end_time":"08:00","note":"night class"}]'::jsonb);
select is((select jsonb_array_length(res) from ctx), 3, 'saving returns the new list');
select is((select res -> 0 ->> 'weekday' from ctx), '2', 'rows are sorted by weekday');
select is((select jsonb_array_length(public.my_availability())), 3, 'my_availability reads it back');
update ctx set res = public.save_my_availability('[{"weekday":3,"kind":"unavailable"}]'::jsonb);
select is((select jsonb_array_length(public.my_availability())), 1, 'saving replaces every old row');

-- Validation.
select throws_ok($$select public.save_my_availability('[{"weekday":8,"kind":"unavailable"}]'::jsonb)$$,
  '22023', 'invalid availability row', 'weekday must be 1 to 7');
select throws_ok($$select public.save_my_availability('[{"weekday":1,"kind":"unavailable","start_time":"09:00"}]'::jsonb)$$,
  '22023', 'invalid time range', 'a range needs both ends');
select throws_ok($$select public.save_my_availability('[{"weekday":1,"kind":"preferred","start_time":"09:00","end_time":"09:00"}]'::jsonb)$$,
  '22023', 'invalid time range', 'start and end differ');
select throws_ok(
  $$select public.save_my_availability((select jsonb_agg(jsonb_build_object('weekday', 1, 'kind', 'unavailable')) from generate_series(1, 22)))$$,
  'P0001', 'too many availability rows', 'at most 21 rows');
reset role;

-- Visibility: a colleague cannot read it, a manager of the branch can.
select tests.login(s2) from ctx;
set local role authenticated;
select throws_ok(format('select public.staff_availability_of(%L)', (select s1 from ctx)), '42501', 'not allowed', 'a colleague cannot read it');
reset role;
select tests.login(mgr_a) from ctx;
set local role authenticated;
select is((select jsonb_array_length(public.staff_availability_of((select s1 from ctx)))), 1, 'a manager of the branch reads it');
update ctx set res = public.save_staff_availability(s1, '[{"weekday":4,"kind":"unavailable"}]'::jsonb);
select is((select updated_by from public.staff_availability where user_id = (select s1 from ctx)), (select mgr_a from ctx), 'a manager edits for staff and is recorded');
select throws_ok(format('select public.save_staff_availability(%L, %L::jsonb)', (select only_b from ctx), '[]'),
  '42501', 'not allowed', 'a manager of branch A cannot edit somebody who works only at B');
reset role;

-- Conflicts: whole day, overnight range, preferred.
select tests.login(s1) from ctx;
set local role authenticated;
select public.save_my_availability(
  '[{"weekday":2,"kind":"unavailable"},
    {"weekday":5,"kind":"unavailable","start_time":"20:00","end_time":"08:00"},
    {"weekday":6,"kind":"preferred","start_time":"08:00","end_time":"14:00"}]'::jsonb);
reset role;
select is((select array[
    public.availability_conflict(s1, public.shift_start_at(monday + 1, time '09:00'), public.shift_end_at(monday + 1, time '09:00', time '17:00')),
    public.availability_conflict(s1, public.shift_start_at(monday + 4, time '21:00'), public.shift_end_at(monday + 4, time '21:00', time '23:00')),
    coalesce(public.availability_conflict(s1, public.shift_start_at(monday + 4, time '09:00'), public.shift_end_at(monday + 4, time '09:00', time '17:00')), 'none'),
    public.availability_conflict(s1, public.shift_start_at(monday + 5, time '08:00'), public.shift_end_at(monday + 5, time '08:00', time '12:00'))
  ] from ctx),
  array['unavailable', 'unavailable', 'none', 'preferred'],
  'a blocked day, a night range, a free slot and a preferred slot');
select is((select jsonb_array_length(public.roster_availability(ba)) from ctx), 3, 'the roster helper lists the branch staff rows');

select * from finish();
rollback;
