-- Marking a pet deceased: what is still booked for it is cancelled (a booking shared with another pet
-- keeps the other pet), work already started is left alone, a pet in a kennel is refused, the date is
-- checked, a second mark is refused, and restore undoes it.
begin;
\ir _helpers/setup.psql
select plan(19);

create temp table ctx as
select a as branch from tests.create_branch('PD') as a;
alter table ctx
  add column admin uuid, add column cashier uuid, add column vet uuid, add column customer uuid,
  add column pet uuid, add column pet2 uuid, add column service uuid,
  add column appt_shared uuid, add column appt_solo uuid, add column appt_busy uuid,
  add column stay uuid, add column visit uuid, add column kennel_type uuid, add column r jsonb;
update ctx set
  admin    = tests.create_user('admin-pd@test.local', 'admin'),
  cashier  = tests.create_cashier('desk-pd@test.local', branch),
  vet      = tests.create_staff('vet-pd@test.local', branch, 'vet'),
  customer = tests.create_patient('0940000001', 'Bu');
update ctx set pet = tests.pet_of(customer);
insert into public.pets (species_id, name) select species_id, 'Bi' from public.pets where id = (select pet from ctx);
insert into public.pet_owners (pet_id, customer_id)
  select id, (select customer from ctx) from public.pets where name = 'Bi';
update ctx set pet2 = (select id from public.pets where name = 'Bi');
insert into public.pet_services (name) values ('PD wash');
update ctx set service = (select id from public.pet_services where name = 'PD wash');

-- Spa: one booking shared by both pets, one for the pet alone, one already checked in.
create or replace function pg_temp.book(p_status text, p_pets uuid[]) returns uuid language plpgsql as $$
declare
  v_start timestamptz := now() + interval '2 days';
  v_id uuid;
  v_pet uuid;
  v_n int := 0;
begin
  insert into public.appointments (code, branch_id, customer_id, customer_name, customer_phone, start_at, end_at, status)
  select 'PD-' || substr(gen_random_uuid()::text, 1, 6), branch, customer, 'Owner', '0940000001', v_start, v_start + interval '1 hour', p_status
  from ctx returning id into v_id;
  foreach v_pet in array p_pets loop
    v_n := v_n + 1;
    insert into public.appointment_items (appointment_id, branch_id, line_no, pet_id, item_type, service_id, name, duration_minutes, start_at, end_at, status)
    select v_id, branch, v_n, v_pet, 'service', service, 'PD wash', 60, v_start, v_start + interval '1 hour',
           case when p_status = 'booked' then 'waiting' else 'in_progress' end
    from ctx;
  end loop;
  return v_id;
end;
$$;
update ctx set
  appt_shared = pg_temp.book('booked', array[pet, pet2]),
  appt_solo   = pg_temp.book('booked', array[pet]),
  appt_busy   = pg_temp.book('checked_in', array[pet]);

-- Hotel: a booked stay for the pet alone; a visit booked ahead.
insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('PD room', '{}', 'boarding', 1);
insert into public.kennel_type_prices (kennel_type_id, night_price) select id, 100000 from public.kennel_types where name = 'PD room';
insert into public.kennels (branch_id, kennel_type_id, code) select c.branch, t.id, 'PD1' from ctx c, public.kennel_types t where t.name = 'PD room';
update ctx set kennel_type = (select id from public.kennel_types where name = 'PD room');
grant select, update on ctx to authenticated;

select tests.login(cashier) from ctx;
set local role authenticated;
update ctx set stay = (public.save_boarding_stay(jsonb_build_object(
  'branch_id', branch, 'customer_id', customer,
  'planned_in_at', now() + interval '3 days', 'planned_out_at', now() + interval '5 days',
  'pets', jsonb_build_array(jsonb_build_object('pet_id', pet, 'kennel_type_id', kennel_type))
), null) ->> 'id')::uuid;
reset role;
insert into public.medical_visits (code, branch_id, pet_id, customer_id, pet_name, customer_name, customer_phone, status, scheduled_at)
  select 'KB-PD1', branch, pet, customer, 'Bu', 'Owner', '0940000001', 'scheduled', now() + interval '7 days' from ctx;
update ctx set visit = (select id from public.medical_visits where code = 'KB-PD1');

-- A pet that is in a kennel cannot be marked deceased.
insert into public.kennels (branch_id, kennel_type_id, code) select branch, kennel_type, 'PD2' from ctx;
select tests.login(cashier) from ctx;
set local role authenticated;
create temp table ctx2 as select (public.save_boarding_stay(jsonb_build_object(
  'branch_id', branch, 'customer_id', customer,
  'planned_in_at', now() + interval '1 day', 'planned_out_at', now() + interval '2 days',
  'pets', jsonb_build_array(jsonb_build_object('pet_id', pet2, 'kennel_type_id', kennel_type))
), null) ->> 'id')::uuid as stay from ctx;
reset role;
update public.boarding_stays set status = 'checked_in' where id = (select stay from ctx2);
update public.boarding_stay_pets set status = 'active' where stay_id = (select stay from ctx2);
select tests.login(admin) from ctx;
set local role authenticated;
select throws_ok(
  format('select public.mark_pet_deceased(%L::uuid)', (select pet2 from ctx)),
  'P0001', 'the pet is still in a kennel', 'a pet in a kennel cannot be marked deceased');
reset role;

-- Permission and preview.
select tests.login(cashier) from ctx;
set local role authenticated;
select throws_ok(
  format('select public.mark_pet_deceased(%L::uuid)', (select pet from ctx)),
  '42501', null, 'staff without the pets UPDATE permission cannot mark a pet deceased');
reset role;

select tests.login(admin) from ctx;
set local role authenticated;
update ctx set r = public.pet_deceased_preview(pet);
select is((select jsonb_array_length(r -> 'appointments') from ctx), 2, 'the preview lists the two booked spa appointments');
select is((select jsonb_array_length(r -> 'open') from ctx), 1, 'and the checked-in appointment as work to finish by hand');
select is((select (r -> 'appointments' -> 0 ->> 'whole')::boolean from ctx), false, 'a booking shared with another pet is not cancelled whole');

-- A date in the future or before the birth date is refused.
select throws_ok(
  format($q$select public.mark_pet_deceased(%L::uuid, jsonb_build_object('deceased_on', (public.business_date() + 1)::text))$q$, (select pet from ctx)),
  '22023', null, 'a date of death after today is refused');

update ctx set r = public.mark_pet_deceased(pet, jsonb_build_object('note', 'old age'));
select is((select r -> 'cancelled' ->> 'appointments' from ctx), '2', 'marking the pet deceased reports the cancelled appointments');
reset role;

select is((select status from public.pets where id = (select pet from ctx)), 'deceased', 'the pet is deceased');
select is((select deceased_on from public.pets where id = (select pet from ctx)), public.business_date(), 'the date of death defaults to today');
select is((select status from public.appointments where id = (select appt_solo from ctx)), 'cancelled', 'a booking for the pet alone is cancelled');
select is((select status from public.appointments where id = (select appt_shared from ctx)), 'booked', 'a shared booking stays for the other pet');
select is(
  (select array_agg(status order by pet_id = (select pet from ctx)) from public.appointment_items where appointment_id = (select appt_shared from ctx)),
  array['waiting', 'cancelled']::text[], 'only the deceased pet''s line of the shared booking is cancelled');
select is((select status from public.appointments where id = (select appt_busy from ctx)), 'checked_in', 'an appointment already checked in is left alone');
select is((select status from public.boarding_stays where id = (select stay from ctx)), 'cancelled', 'the booked hotel stay is cancelled');
select is((select status from public.medical_visits where id = (select visit from ctx)), 'cancelled', 'the visit booked ahead is cancelled');
select throws_ok(
  format('select public.mark_pet_deceased(%L::uuid)', (select pet from ctx)),
  'P0001', 'the pet is already marked deceased', 'a pet already marked deceased is refused');

-- Restore.
select tests.login(admin) from ctx;
set local role authenticated;
select lives_ok(format('select public.restore_pet(%L::uuid)', (select pet from ctx)), 'restoring a pet works');
reset role;
select is((select deceased_on from public.pets where id = (select pet from ctx)), null::date, 'restoring clears the date of death');
select is((select status from public.appointments where id = (select appt_solo from ctx)), 'cancelled', 'cancelled bookings stay cancelled');

select * from finish();
rollback;
