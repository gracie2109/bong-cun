-- An inpatient stay on the kennel board: the board says which pets are inpatient and which kennels
-- are medical, and the hotel check-out, extend and extras refuse an inpatient stay.
begin;
\ir _helpers/setup.psql
select plan(8);

create temp table ctx as
select a as branch from tests.create_branch('IB') as a;
alter table ctx
  add column visit_code text, add column vet uuid, add column admin uuid, add column customer uuid, add column pet uuid, add column visit uuid,
  add column kennel uuid, add column stay uuid, add column stay_pet uuid, add column service uuid;
update ctx set
  vet      = tests.create_staff('vet-ib@test.local', branch, 'vet'),
  admin    = tests.create_user('admin-ib@test.local', 'admin'),
  customer = tests.create_patient('0920000001', 'Mimi');
update ctx set pet = tests.pet_of(customer);

insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Ward', '{}', 'medical', 1);
insert into public.kennel_type_prices (kennel_type_id, night_price)
  select id, 50000 from public.kennel_types where name = 'Ward';
insert into public.kennels (branch_id, kennel_type_id, code)
  select c.branch, t.id, 'W1' from ctx c, public.kennel_types t where t.name = 'Ward';
update ctx set kennel = (select id from public.kennels where code = 'W1' and branch_id = ctx.branch);
insert into public.pet_services (name, category) values ('Test extra', 'other');
update ctx set service = (select id from public.pet_services where name = 'Test extra');
grant select, update on ctx to authenticated;

select tests.login(vet) from ctx;
set local role authenticated;
update ctx set visit = (public.check_in_medical_visit(jsonb_build_object(
  'branch_id', branch, 'customer_id', customer, 'pet_id', pet, 'reason', 'vomiting'
)) ->> 'id')::uuid;
select public.start_medical_visit(visit) from ctx;
update ctx set stay = (public.admit_inpatient(visit, jsonb_build_object('kennel_id', kennel)) ->> 'stay_id')::uuid;
reset role;
update ctx set stay_pet = (select id from public.boarding_stay_pets where stay_id = ctx.stay),
  visit_code = (select code from public.medical_visits where id = ctx.visit);
select tests.login(admin) from ctx;
set local role authenticated;

select is(
  (select p ->> 'kind' from ctx,
     jsonb_array_elements(public.boarding_board(branch) -> 'kennels') k,
     jsonb_array_elements(k -> 'pets') p),
  'inpatient', 'the board marks the pet in a medical kennel as inpatient');
select is(
  (select p ->> 'visit_code' from ctx,
     jsonb_array_elements(public.boarding_board(branch) -> 'kennels') k,
     jsonb_array_elements(k -> 'pets') p),
  (select visit_code from ctx),
  'the board carries the visit code');
select is(
  (select k ->> 'purpose' from ctx, jsonb_array_elements(public.boarding_board(branch) -> 'kennels') k limit 1),
  'medical', 'a kennel says what it is for');
select is(
  (public.boarding_board((select branch from ctx)) -> 'counts' ->> 'inpatient')::int, 1,
  'the board counts inpatient kennels');
select is(
  public.get_boarding_stay((select stay from ctx)) ->> 'kind', 'inpatient',
  'the stay detail says it is an inpatient stay');

select throws_ok(
  format('select public.check_out_boarding(%L::uuid)', (select stay from ctx)),
  'P0001', null, 'the hotel check-out refuses an inpatient stay');
select throws_ok(
  format('select public.extend_boarding_stay(%L::uuid, now() + interval ''3 days'')', (select stay from ctx)),
  'P0001', null, 'extending refuses an inpatient stay');
select throws_ok(
  format('select public.add_boarding_extra(%L::uuid, %L::uuid, 1)', (select stay_pet from ctx), (select service from ctx)),
  'P0001', null, 'an extra service refuses an inpatient stay');
reset role;

select * from finish();
rollback;
