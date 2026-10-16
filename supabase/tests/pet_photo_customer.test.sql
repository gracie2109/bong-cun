-- A customer sees their pet's photo on the account pages, and still cannot change it.
begin;
\ir _helpers/setup.psql
select plan(4);

create temp table ctx as
select tests.create_user('photo-owner@test.local') as account;
alter table ctx add column owner uuid, add column pet uuid;
update ctx set owner = tests.create_patient('0930000001', 'Mun');
update ctx set pet = tests.pet_of(owner);
update public.customers set user_id = (select account from ctx) where id = (select owner from ctx);
update public.pets set photo_url = 'https://x.test/mun.webp' where id = (select pet from ctx);
grant select on ctx to authenticated;

select tests.login(account) from ctx;
set local role authenticated;

select is(
  (select public.my_pets() -> 0 ->> 'photo_url'),
  'https://x.test/mun.webp',
  'my_pets returns the photo of the customer''s pet'
);
select is(
  (select public.my_pet_health(pet) ->> 'pet_photo_url' from ctx),
  'https://x.test/mun.webp',
  'the health book returns the photo too'
);
select throws_ok(
  format($q$select public.set_pet_photo(%L::uuid, null, null)$q$, (select pet from ctx)),
  '42501', null, 'the customer cannot change the photo'
);
select is(
  (select count(*)::int from pg_proc
   where pronamespace = 'public'::regnamespace
     and proname in ('my_appointments', 'my_boarding_stay_json') and prosrc like '%pet_photo_url%'),
  2,
  'my_appointments and my_boarding_stay_json carry pet_photo_url'
);

select * from finish();
rollback;
