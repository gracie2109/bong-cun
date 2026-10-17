-- A deceased pet cannot be booked for spa (staff or web), and the customer still sees it, muted:
-- my_pets returns it last with status and date of death, no next vaccine and no open booking, and
-- the health book still opens without a next dose.
begin;
\ir _helpers/setup.psql
select plan(9);

create temp table ctx as
select tests.create_user('dc-owner@test.local') as account, tests.create_branch('DC') as branch;
alter table ctx
  add column cashier uuid, add column owner uuid, add column pet uuid, add column pet2 uuid,
  add column service uuid, add column vaccine uuid, add column start_at timestamptz;
update ctx set
  cashier  = tests.create_cashier('dc-desk@test.local', branch),
  owner    = tests.create_patient('0950000001', 'Zed'),
  start_at = (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '2 days 10 hours')
             at time zone 'Asia/Ho_Chi_Minh';
update ctx set pet = tests.pet_of(owner);
update public.customers set user_id = (select account from ctx) where id = (select owner from ctx);
insert into public.pets (species_id, name, status, deceased_on)
  select species_id, 'Amy', 'deceased', public.business_date() - 3 from public.pets where id = (select pet from ctx);
insert into public.pet_owners (pet_id, customer_id)
  select id, (select owner from ctx) from public.pets where name = 'Amy';
update ctx set pet2 = (select id from public.pets where name = 'Amy');
insert into public.pet_services (name) values ('DC wash');
update ctx set service = (select id from public.pet_services where name = 'DC wash');
-- Both pets have a vaccination with a next dose; only the active pet may show it.
insert into public.vaccine_types (name, kind) values ('DC rabies', 'vaccine');
update ctx set vaccine = (select id from public.vaccine_types where name = 'DC rabies');
insert into public.vaccinations (pet_id, vaccine_type_id, dose_no, given_on, next_due_on, is_external, external_place)
  select p, vaccine, 1, public.business_date() - 30, public.business_date() + 20, true, 'DC clinic'
  from ctx, unnest(array[pet, pet2]) p;
grant select on ctx to authenticated;

-- Staff booking.
select tests.login(cashier) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.save_appointment(jsonb_build_object('branch_id', %L::uuid, 'customer_id', %L::uuid,
    'items', jsonb_build_array(jsonb_build_object('type', 'service', 'id', %L::uuid, 'pet_id', %L::uuid, 'start_at', %L::timestamptz))), null)$q$,
    (select branch from ctx), (select owner from ctx), (select service from ctx), (select pet2 from ctx), (select start_at from ctx)),
  '22023', null, 'staff cannot book a deceased pet');
reset role;

-- Customer side.
select tests.login(account) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.book_my_appointment(jsonb_build_object('branch_id', %L::uuid, 'start_at', %L::timestamptz,
    'items', jsonb_build_array(jsonb_build_object('type', 'service', 'id', %L::uuid, 'pet_id', %L::uuid))))$q$,
    (select branch from ctx), (select start_at from ctx), (select service from ctx), (select pet2 from ctx)),
  'P0001', 'the pet is not active', 'the customer cannot book a deceased pet online');

select is((select jsonb_array_length(public.my_pets())), 2, 'my_pets returns the deceased pet too');
select is((select public.my_pets() -> 0 ->> 'status'), 'active', 'the active pet comes first');
select is((select public.my_pets() -> 1 ->> 'status'), 'deceased', 'the deceased pet comes last');
select is(
  (select public.my_pets() -> 1 ->> 'deceased_on'), (public.business_date() - 3)::text, 'with its date of death');
select is(
  (select public.my_pets() -> 1 -> 'next_vaccine' ->> 'name'), null, 'and no next vaccine');
select is(
  (select public.my_pets() -> 0 -> 'next_vaccine' ->> 'name'), 'DC rabies', 'while the active pet keeps its next vaccine');
select is(
  (select public.my_pet_health(pet2) -> 'vaccines' -> 0 ->> 'next_due_on' from ctx), null,
  'the health book of a deceased pet opens without a next dose');
reset role;

select * from finish();
rollback;
