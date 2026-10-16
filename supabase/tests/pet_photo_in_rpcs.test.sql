-- The pet's photo reaches the staff screens: boarding returns it for real, and every other function
-- that lists pets by name (spa, medical, POS) carries the pet_photo_url key.
begin;
\ir _helpers/setup.psql
select plan(3);

create temp table ctx as
select tests.create_branch('PR') as branch;
alter table ctx
  add column cashier uuid, add column customer uuid, add column pet uuid, add column kennel_type uuid,
  add column arrive timestamptz, add column leave timestamptz;
update ctx set
  cashier  = tests.create_cashier('photo-desk@test.local', branch),
  customer = tests.create_patient('0920000001', 'Bo'),
  arrive = (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '1 day 9 hours')
           at time zone 'Asia/Ho_Chi_Minh',
  leave  = (date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') + interval '4 days 9 hours')
           at time zone 'Asia/Ho_Chi_Minh';
update ctx set pet = tests.pet_of(customer);
update public.pets set photo_url = 'https://x.test/p.webp' where id = (select pet from ctx);

insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Photo room', '{}', 'boarding', 1);
update ctx set kennel_type = (select id from public.kennel_types where name = 'Photo room');
insert into public.kennel_type_prices (kennel_type_id, night_price) select kennel_type, 100000 from ctx;
insert into public.kennels (branch_id, kennel_type_id, code) select branch, kennel_type, 'P1' from ctx;
grant select, update on ctx to authenticated;

select tests.login(cashier) from ctx;
set local role authenticated;

select public.save_boarding_stay(jsonb_build_object(
  'branch_id', branch, 'customer_id', customer, 'planned_in_at', arrive, 'planned_out_at', leave,
  'pets', jsonb_build_array(jsonb_build_object('pet_id', pet, 'kennel_type_id', kennel_type))
), null) from ctx;

select is(
  (select public.list_boarding_stays(branch) -> 'rows' -> 0 -> 'pets' -> 0 ->> 'pet_photo_url' from ctx),
  'https://x.test/p.webp',
  'a stay lists the photo of its pet'
);
select ok(
  (select public.boarding_board(branch, (arrive at time zone 'Asia/Ho_Chi_Minh')::date)::text
          like '%"pet_photo_url": "https://x.test/p.webp"%' from ctx),
  'the kennel board shows the photo of an arriving pet'
);
reset role;

select is(
  (select count(*)::int from pg_proc
   where pronamespace = 'public'::regnamespace and prosrc like '%pet_photo_url%'
     and proname in ('boarding_stay_json', 'boarding_board', 'inpatient_ward', 'spa_day_board', 'list_appointments',
                     'medical_visit_json', 'billable_appointment_items', 'billable_boarding_charges',
                     'billable_medical_items')),
  9,
  'all nine staff functions carry pet_photo_url'
);
select * from finish();
rollback;
