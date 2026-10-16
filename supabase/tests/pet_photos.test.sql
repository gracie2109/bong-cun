-- Pet photo: who may upload to the pet-photos bucket and call set_pet_photo.
begin;
\ir _helpers/setup.psql
select plan(14);

create temp table ctx as
select tests.create_branch('PH') as branch;
alter table ctx add column manager uuid, add column cashier uuid, add column customer uuid,
  add column owner uuid, add column pet uuid, add column other_pet uuid;
update ctx set
  manager  = tests.create_staff('photo-admin@test.local', branch, 'admin'),
  cashier  = tests.create_cashier('photo-cashier@test.local', branch),
  customer = tests.create_user('photo-buyer@test.local'),
  owner    = tests.create_patient('0900000001', 'Mimi');
update ctx set pet = tests.pet_of(owner);
update ctx set other_pet = tests.pet_of(tests.create_patient('0900000002', 'Lulu'));
grant select, update on ctx to anon, authenticated;

select is(
  (select array[public::text, file_size_limit::text] from storage.buckets where id = 'pet-photos'),
  array['true', '2097152'],
  'the bucket is public with a 2 MB limit'
);

-- A manager (pets permission) uploads and sets the photo.
select tests.login(manager) from ctx;
set local role authenticated;
select lives_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('pet-photos', %L)$q$, (select pet || '/a.webp' from ctx)),
  'a manager uploads into the pet folder'
);
select throws_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('pet-photos', %L)$q$, gen_random_uuid() || '/a.webp'),
  '42501', null, 'a folder that is not a real pet is refused'
);
select is(
  (select public.set_pet_photo(pet, pet || '/a.webp', 'https://x.test/storage/v1/object/public/pet-photos/' || pet || '/a.webp') from ctx),
  null,
  'the first photo has no old path to return'
);
select lives_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('pet-photos', %L)$q$, (select pet || '/b.webp' from ctx)),
  'a second file can be uploaded'
);
select is(
  (select public.set_pet_photo(pet, pet || '/b.webp', 'https://x.test/storage/v1/object/public/pet-photos/' || pet || '/b.webp') from ctx),
  (select pet || '/a.webp' from ctx),
  'changing the photo returns the old path'
);
select is(
  (select photo_url from public.pets where id = (select pet from ctx)),
  (select 'https://x.test/storage/v1/object/public/pet-photos/' || pet || '/b.webp' from ctx),
  'the public url is stored on the pet'
);
select throws_ok(
  format($q$select public.set_pet_photo(%L::uuid, %L, %L)$q$, (select pet from ctx),
    (select other_pet || '/a.webp' from ctx), 'https://x.test/storage/v1/object/public/pet-photos/' || (select other_pet from ctx) || '/a.webp'),
  '22023', null, 'a path from another pet is refused'
);
select throws_ok(
  format($q$select public.set_pet_photo(%L::uuid, %L, %L)$q$, (select pet from ctx),
    (select pet || '/c.webp' from ctx), 'https://x.test/elsewhere.webp'),
  '22023', null, 'a url that does not match the path is refused'
);
select is(
  (select public.set_pet_photo(pet, null, null) from ctx),
  (select pet || '/b.webp' from ctx),
  'clearing the photo returns the path to delete'
);
select is(
  (select photo_url || coalesce(photo_path, '') from public.pets where id = (select pet from ctx)),
  null,
  'clearing removes the url and the path'
);
reset role;

-- A cashier has no pets permission.
select tests.login(cashier) from ctx;
set local role authenticated;
select throws_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('pet-photos', %L)$q$, (select pet || '/z.webp' from ctx)),
  '42501', null, 'a cashier cannot upload a pet photo'
);
select throws_ok(
  format($q$select public.set_pet_photo(%L::uuid, null, null)$q$, (select pet from ctx)),
  '42501', null, 'a cashier cannot call set_pet_photo'
);
reset role;

-- A customer only looks.
select tests.login(customer) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.set_pet_photo(%L::uuid, null, null)$q$, (select pet from ctx)),
  '42501', null, 'a customer cannot call set_pet_photo'
);
reset role;

select * from finish();
rollback;
