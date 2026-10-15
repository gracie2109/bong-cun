-- Boarding bookings: who may book, one kennel per stay, a pet is never in two places,
-- and bad dates or the wrong customer are refused.
begin;
\ir _helpers/setup.psql
select plan(9);

create temp table ctx as
select a as branch_a, b as branch_b
from tests.create_branch('BA') as a, tests.create_branch('BB') as b;
alter table ctx
  add column cashier uuid, add column cashier_b uuid, add column admin uuid, add column customer uuid,
  add column other_customer uuid, add column pet uuid, add column other_pet uuid,
  add column kennel_type uuid, add column stay uuid,
  add column arrive timestamptz, add column leave timestamptz;
update ctx set
  cashier        = tests.create_cashier('desk-a@test.local', branch_a),
  cashier_b      = tests.create_cashier('desk-b@test.local', branch_b),
  admin          = tests.create_user('admin@test.local', 'admin'),
  customer       = tests.create_patient('0910000001', 'Bo'),
  other_customer = tests.create_patient('0910000002', 'Kem'),
  arrive = (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day 9 hours')
           at time zone 'Asia/Ho_Chi_Minh',
  leave  = (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '4 days 9 hours')
           at time zone 'Asia/Ho_Chi_Minh';
update ctx set pet = tests.pet_of(customer), other_pet = tests.pet_of(other_customer);

-- One kennel type open to every species, one kennel in branch A.
insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Test room', '{}', 'boarding', 1);
update ctx set kennel_type = (select id from public.kennel_types where name = 'Test room');
insert into public.kennel_type_prices (kennel_type_id, night_price) select kennel_type, 100000 from ctx;
insert into public.kennels (branch_id, kennel_type_id, code) select branch_a, kennel_type, 'K1' from ctx;
grant select, update on ctx to authenticated;

select tests.login(cashier) from ctx;
set local role authenticated;

update ctx set stay = (public.save_boarding_stay(jsonb_build_object(
  'branch_id', branch_a, 'customer_id', customer,
  'planned_in_at', arrive, 'planned_out_at', leave,
  'pets', jsonb_build_array(jsonb_build_object('pet_id', pet, 'kennel_type_id', kennel_type))
), null) ->> 'id')::uuid;
select isnt((select stay from ctx), null, 'the front desk books a stay when a kennel is free');

select throws_ok(
  format($q$select public.save_boarding_stay(jsonb_build_object(
    'branch_id', %L::uuid, 'customer_id', %L::uuid, 'planned_in_at', %L::timestamptz, 'planned_out_at', %L::timestamptz,
    'pets', jsonb_build_array(jsonb_build_object('pet_id', %L::uuid, 'kennel_type_id', %L::uuid))), null)$q$,
    (select branch_a from ctx), (select customer from ctx), (select arrive from ctx),
    (select leave from ctx), (select pet from ctx), (select kennel_type from ctx)),
  'P0001', null, 'the same pet cannot be booked twice for overlapping nights'
);

select throws_ok(
  format($q$select public.save_boarding_stay(jsonb_build_object(
    'branch_id', %L::uuid, 'customer_id', %L::uuid, 'planned_in_at', %L::timestamptz, 'planned_out_at', %L::timestamptz,
    'pets', jsonb_build_array(jsonb_build_object('pet_id', %L::uuid, 'kennel_type_id', %L::uuid))), null)$q$,
    (select branch_a from ctx), (select other_customer from ctx), (select arrive from ctx),
    (select leave from ctx), (select other_pet from ctx), (select kennel_type from ctx)),
  'P0001', null, 'a second pet gets no kennel when the only one is taken'
);

select throws_ok(
  format($q$select public.save_boarding_stay(jsonb_build_object(
    'branch_id', %L::uuid, 'customer_id', %L::uuid, 'planned_in_at', %L::timestamptz, 'planned_out_at', %L::timestamptz,
    'pets', jsonb_build_array(jsonb_build_object('pet_id', %L::uuid, 'kennel_type_id', %L::uuid))), null)$q$,
    (select branch_a from ctx), (select customer from ctx), (select arrive from ctx),
    (select leave from ctx), (select other_pet from ctx), (select kennel_type from ctx)),
  '22023', null, 'a customer cannot book a pet they do not own'
);

select throws_ok(
  format($q$select public.save_boarding_stay(jsonb_build_object(
    'branch_id', %L::uuid, 'customer_id', %L::uuid, 'planned_in_at', %L::timestamptz, 'planned_out_at', %L::timestamptz,
    'pets', jsonb_build_array(jsonb_build_object('pet_id', %L::uuid, 'kennel_type_id', %L::uuid))), null)$q$,
    (select branch_a from ctx), (select other_customer from ctx), now() - interval '2 days',
    (select leave from ctx), (select other_pet from ctx), (select kennel_type from ctx)),
  'P0001', null, 'arrival in the past is refused'
);
reset role;

-- Staff of another branch cannot book into branch A.
select tests.login(cashier_b) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.save_boarding_stay(jsonb_build_object(
    'branch_id', %L::uuid, 'customer_id', %L::uuid, 'planned_in_at', %L::timestamptz, 'planned_out_at', %L::timestamptz,
    'pets', jsonb_build_array(jsonb_build_object('pet_id', %L::uuid, 'kennel_type_id', %L::uuid))), null)$q$,
    (select branch_a from ctx), (select other_customer from ctx), (select arrive from ctx),
    (select leave from ctx), (select other_pet from ctx), (select kennel_type from ctx)),
  '42501', null, 'staff of another branch cannot book here'
);
reset role;

-- Cancelling needs DELETE: the front desk cannot, an admin can, and the kennel is freed.
select tests.login(cashier) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.cancel_boarding_stay(%L::uuid, 'changed plans')$q$, (select stay from ctx)),
  '42501', null, 'the front desk (no boarding DELETE) cannot cancel a stay'
);
reset role;
select tests.login(admin) from ctx;
set local role authenticated;
select lives_ok(
  format($q$select public.cancel_boarding_stay(%L::uuid, 'changed plans')$q$, (select stay from ctx)),
  'an admin cancels a booked stay'
);
reset role;
select tests.login(cashier) from ctx;
set local role authenticated;
select lives_ok(
  format($q$select public.save_boarding_stay(jsonb_build_object(
    'branch_id', %L::uuid, 'customer_id', %L::uuid, 'planned_in_at', %L::timestamptz, 'planned_out_at', %L::timestamptz,
    'pets', jsonb_build_array(jsonb_build_object('pet_id', %L::uuid, 'kennel_type_id', %L::uuid))), null)$q$,
    (select branch_a from ctx), (select other_customer from ctx), (select arrive from ctx),
    (select leave from ctx), (select other_pet from ctx), (select kennel_type from ctx)),
  'the freed kennel can be booked again'
);
reset role;

select * from finish();
rollback;
