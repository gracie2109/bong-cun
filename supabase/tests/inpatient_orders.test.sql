-- In-patient orders: editing hours, dates and quantity only touches doses that are not yet due and not
-- yet recorded, the medicine cannot be edited (replace it), every change is logged, the vet's branch
-- limits who may edit, and a signed visit locks its orders and doses in the database itself.
begin;
\ir _helpers/setup.psql
select plan(18);

create temp table ctx as
select a as branch_a, b as branch_b
from tests.create_branch('OA') as a, tests.create_branch('OB') as b;
alter table ctx
  add column vet uuid, add column vet_b uuid, add column cashier uuid, add column customer uuid, add column pet uuid,
  add column visit uuid, add column kennel uuid, add column stay uuid, add column stay_pet uuid, add column product uuid,
  add column care_order uuid, add column med_order uuid, add column new_order uuid, add column r jsonb;
update ctx set
  vet      = tests.create_staff('vet-oa@test.local', branch_a, 'vet'),
  vet_b    = tests.create_staff('vet-ob@test.local', branch_b, 'vet'),
  cashier  = tests.create_cashier('desk-oa@test.local', branch_a),
  customer = tests.create_patient('0930000001', 'Miu'),
  product  = tests.create_product('Test antibiotic', 20000);
update ctx set pet = tests.pet_of(customer);

insert into public.kennel_types (name, species_ids, purpose, max_pets) values ('Ward O', '{}', 'medical', 1);
insert into public.kennel_type_prices (kennel_type_id, night_price) select id, 50000 from public.kennel_types where name = 'Ward O';
insert into public.kennels (branch_id, kennel_type_id, code)
  select c.branch_a, t.id, 'WO1' from ctx c, public.kennel_types t where t.name = 'Ward O';
update ctx set kennel = (select id from public.kennels where code = 'WO1');
grant select, update on ctx to authenticated;

select tests.login(vet) from ctx;
set local role authenticated;
update ctx set visit = (public.check_in_medical_visit(jsonb_build_object(
  'branch_id', branch_a, 'customer_id', customer, 'pet_id', pet, 'reason', 'infection'
)) ->> 'id')::uuid;
select public.start_medical_visit(visit) from ctx;
update ctx set stay = (public.admit_inpatient(visit, jsonb_build_object('kennel_id', kennel)) ->> 'stay_id')::uuid;
reset role;
update ctx set stay_pet = (select id from public.boarding_stay_pets where stay_id = ctx.stay);
select tests.login(vet) from ctx;
set local role authenticated;

-- A care order today to the day after tomorrow at 00:01 and 23:59: six doses.
update ctx set care_order = public.save_inpatient_order(jsonb_build_object(
  'stay_pet_id', stay_pet, 'kind', 'care', 'name', 'Check the drip', 'times', jsonb_build_array('00:01', '23:59'),
  'start_on', public.business_date(), 'end_on', public.business_date() + 2));
select is((select count(*) from public.inpatient_doses where order_id = (select care_order from ctx)), 6::bigint,
  'an order makes one dose per day and hour');

-- Today's 00:01 dose is recorded, then the hours change to 23:58.
select public.give_inpatient_dose(id) from public.inpatient_doses
  where order_id = (select care_order from ctx) and due_at = (public.business_date()::timestamp + time '00:01') at time zone 'Asia/Ho_Chi_Minh';
update ctx set r = public.update_inpatient_order(care_order, jsonb_build_object('times', jsonb_build_array('23:58'), 'reason', 'new schedule'));
select is((select r ->> 'doses_removed' from ctx), '5', 'editing the hours drops the doses that are not yet due');
select is((select r ->> 'doses_added' from ctx), '3', 'and adds the new hours from today on');
select is((select count(*) from public.inpatient_doses where order_id = (select care_order from ctx)), 4::bigint,
  'the recorded dose stays next to the three new ones');
select is((select count(*) from public.inpatient_doses where order_id = (select care_order from ctx) and given_at is not null), 1::bigint,
  'the dose that was given is untouched');

-- Shorter end date: later doses go.
select public.update_inpatient_order(care_order, jsonb_build_object('end_on', public.business_date())) from ctx;
select is((select count(*) from public.inpatient_doses where order_id = (select care_order from ctx)), 2::bigint,
  'a shorter end date removes the later doses');

select throws_ok(
  format($q$select public.update_inpatient_order(%L::uuid, jsonb_build_object('start_on', (public.business_date() + 1)::text, 'end_on', (public.business_date() + 2)::text))$q$, (select care_order from ctx)),
  '22023', null, 'the start date cannot move once a dose is recorded');
select throws_ok(
  format($q$select public.update_inpatient_order(%L::uuid, jsonb_build_object('name', 'Something else'))$q$, (select care_order from ctx)),
  '22023', null, 'the medicine or name cannot be edited (replace it)');

-- Quantity: each given dose adds the quantity it had when it was given.
update ctx set med_order = public.save_inpatient_order(jsonb_build_object(
  'stay_pet_id', stay_pet, 'kind', 'product', 'product_id', product, 'times', jsonb_build_array('00:01', '00:02'),
  'start_on', public.business_date(), 'end_on', public.business_date(), 'qty_per_dose', 1));
select public.give_inpatient_dose(id) from public.inpatient_doses
  where order_id = (select med_order from ctx) and due_at = (public.business_date()::timestamp + time '00:01') at time zone 'Asia/Ho_Chi_Minh';
select public.update_inpatient_order(med_order, jsonb_build_object('qty_per_dose', 2)) from ctx;
select public.give_inpatient_dose(id) from public.inpatient_doses
  where order_id = (select med_order from ctx) and due_at = (public.business_date()::timestamp + time '00:02') at time zone 'Asia/Ho_Chi_Minh';
reset role;
select is(
  (select sum(qty) from public.inpatient_doses where order_id = (select med_order from ctx) and given_at is not null),
  3::numeric, 'each given dose keeps its own quantity (1 then 2)');
select is(
  (select i.qty from public.medical_visit_items i join public.inpatient_orders o on o.item_id = i.id where o.id = (select med_order from ctx)),
  3::numeric, 'the line of the visit adds up the new quantity from then on');

-- Replace: the old order stops, a new one starts, both are logged.
select tests.login(vet) from ctx;
set local role authenticated;
update ctx set new_order = public.replace_inpatient_order(med_order, jsonb_build_object(
  'kind', 'care', 'name', 'Observe only', 'times', jsonb_build_array('23:57'),
  'start_on', public.business_date(), 'end_on', public.business_date()));
select isnt((select new_order from ctx), null, 'replacing an order returns the new order');
select isnt((select stopped_at from public.inpatient_orders where id = (select med_order from ctx)), null, 'the old order is stopped');
select is(
  (select array_agg(action order by action) from public.inpatient_order_changes where order_id in ((select med_order from ctx), (select new_order from ctx))),
  array['create', 'create', 'replace', 'update']::text[],
  'creates, the quantity edit and the replacement are all in the change log');
select is(
  (select jsonb_array_length(public.inpatient_order_history((select care_order from ctx)))),
  3, 'the history lists create and the two edits');

select is(
  (select (public.inpatient_ward(branch_a) -> 'rows' -> 0 -> 'orders' -> 0 ->> 'edited')::int from ctx),
  2, 'the ward counts how many times an order was edited');

-- Who may edit.
reset role;
select tests.login(vet_b) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.update_inpatient_order(%L::uuid, jsonb_build_object('note', 'x'))$q$, (select care_order from ctx)),
  '42501', null, 'a vet of another branch cannot edit the order');
reset role;
select tests.login(cashier) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.update_inpatient_order(%L::uuid, jsonb_build_object('note', 'x'))$q$, (select care_order from ctx)),
  '42501', null, 'the front desk (no medical UPDATE) cannot edit the order');
reset role;

-- Discharge and sign: the database refuses any later change, even to a superuser session.
select tests.login(vet) from ctx;
set local role authenticated;
select public.discharge_inpatient(stay) from ctx;
select public.save_medical_record(visit, jsonb_build_object('assessment', 'Recovered', 'outcome', 'home')) from ctx;
select public.sign_medical_visit(visit) from ctx;
reset role;
select throws_ok(
  format($q$update public.inpatient_orders set note = 'changed' where id = %L::uuid$q$, (select care_order from ctx)),
  'P0001', null, 'a signed visit locks its orders in the database');

select * from finish();
rollback;
