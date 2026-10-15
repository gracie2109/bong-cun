-- The medical visit: who may do each step, one open visit per pet, signing locks the record,
-- a re-check books the next visit, and the vet's branch limits what they can touch.
begin;
\ir _helpers/setup.psql
select plan(15);

create temp table ctx as
select a as branch_a, b as branch_b
from tests.create_branch('MA') as a, tests.create_branch('MB') as b;
alter table ctx
  add column cashier uuid, add column vet uuid, add column vet_b uuid, add column admin uuid,
  add column customer uuid, add column other_customer uuid, add column pet uuid,
  add column visit uuid, add column visit2 uuid;
update ctx set
  cashier        = tests.create_cashier('desk@test.local', branch_a),
  vet            = tests.create_staff('vet-a@test.local', branch_a, 'vet'),
  vet_b          = tests.create_staff('vet-b@test.local', branch_b, 'vet'),
  admin          = tests.create_user('admin@test.local', 'admin'),
  customer       = tests.create_patient('0900000001', 'Mimi'),
  other_customer = tests.create_patient('0900000002', 'Lulu');
update ctx set pet = tests.pet_of(customer);
grant select, update on ctx to authenticated;

-- Front desk checks the pet in.
select tests.login(cashier) from ctx;
set local role authenticated;
update ctx set visit = (public.check_in_medical_visit(jsonb_build_object(
  'branch_id', branch_a, 'customer_id', customer, 'pet_id', pet, 'reason', 'cough'
)) ->> 'id')::uuid;
select isnt((select visit from ctx), null, 'the front desk (medical CREATE) checks a pet in');

select throws_ok(
  format($q$select public.check_in_medical_visit(jsonb_build_object(
     'branch_id', %L::uuid, 'customer_id', %L::uuid, 'pet_id', %L::uuid))$q$,
     (select branch_a from ctx), (select customer from ctx), (select pet from ctx)),
  'P0001', null, 'a pet with an open visit cannot be checked in again'
);
select throws_ok(
  format($q$select public.check_in_medical_visit(jsonb_build_object(
     'branch_id', %L::uuid, 'customer_id', %L::uuid, 'pet_id', %L::uuid))$q$,
     (select branch_a from ctx), (select other_customer from ctx), (select pet from ctx)),
  'P0002', null, 'a customer cannot check in a pet they do not own'
);
select throws_ok(
  format('select public.start_medical_visit(%L::uuid)', (select visit from ctx)),
  '42501', null, 'the front desk (no medical UPDATE) cannot take the case'
);
reset role;

-- A vet of another branch has no say here.
select tests.login(vet_b) from ctx;
set local role authenticated;
select throws_ok(
  format('select public.start_medical_visit(%L::uuid)', (select visit from ctx)),
  '42501', null, 'a vet of another branch cannot take the case'
);
reset role;

-- The vet takes the case and writes the record.
select tests.login(vet) from ctx;
set local role authenticated;
select lives_ok(
  format('select public.start_medical_visit(%L::uuid)', (select visit from ctx)),
  'the vet takes the case'
);
select throws_ok(
  format('select public.sign_medical_visit(%L::uuid)', (select visit from ctx)),
  '22023', null, 'a visit cannot be signed without an outcome'
);
select lives_ok(
  format($q$select public.save_medical_record(%L::uuid, jsonb_build_object(
     'assessment', 'Mild bronchitis', 'outcome', 'recheck', 'recheck_on', (public.business_date() + 7)::text))$q$,
     (select visit from ctx)),
  'the vet saves the record'
);
select is(
  (select (public.sign_medical_visit(visit) ->> 'recheck_visit_id') is not null from ctx),
  true,
  'signing a re-check outcome books the next visit'
);

-- Signed: the record is locked, for the vet and for the database itself.
select throws_ok(
  format($q$select public.save_medical_record(%L::uuid, jsonb_build_object('assessment', 'changed'))$q$, (select visit from ctx)),
  'P0001', null, 'a signed visit cannot be edited through the API'
);
reset role;
select throws_ok(
  format($q$update public.medical_visits set assessment = 'changed' where id = %L::uuid$q$, (select visit from ctx)),
  'P0001', null, 'a signed visit cannot be edited even by a direct update'
);
select is(
  (select count(*) from public.medical_visits where follow_up_of = (select visit from ctx) and status = 'scheduled'),
  1::bigint,
  'the re-check visit is booked once, as scheduled'
);

-- Cancelling needs medical DELETE: the vet role does not have it, an admin does.
update ctx set visit2 = (
  select id from public.medical_visits where follow_up_of = ctx.visit
);
select tests.login(vet) from ctx;
set local role authenticated;
select throws_ok(
  format('select public.cancel_medical_visit(%L::uuid, %L)', (select visit2 from ctx), 'no show'),
  '42501', null, 'a vet (no medical DELETE) cannot cancel a visit'
);
reset role;
select tests.login(admin) from ctx;
set local role authenticated;
select lives_ok(
  format('select public.cancel_medical_visit(%L::uuid, %L)', (select visit2 from ctx), 'no show'),
  'an admin cancels a booked visit'
);
select throws_ok(
  format('select public.cancel_medical_visit(%L::uuid, %L)', (select visit from ctx), 'late'),
  'P0001', null, 'a signed visit cannot be cancelled'
);
reset role;

select * from finish();
rollback;
