-- A booked visit or stay whose time has passed leaves "upcoming" and shows as overdue on the
-- customer's account pages; one still ahead stays upcoming.
begin;
\ir _helpers/setup.psql
select plan(8);

create temp table ctx as
select tests.create_user('late@test.local') as account, tests.create_branch('PB') as branch;
alter table ctx add column customer uuid;
update ctx set customer = tests.create_patient('0940000001', 'Mit');
update public.customers set user_id = (select account from ctx) where id = (select customer from ctx);

insert into public.appointments (code, branch_id, customer_id, customer_name, customer_phone, start_at, end_at, status)
select 'PB-PAST', branch, customer, 'Owner', '0940000001', now() - interval '1 day 2 hours', now() - interval '1 day', 'booked' from ctx
union all
select 'PB-NEXT', branch, customer, 'Owner', '0940000001', now() + interval '1 day', now() + interval '1 day 2 hours', 'booked' from ctx;

insert into public.boarding_stays (code, branch_id, customer_id, customer_name, customer_phone, planned_in_at, planned_out_at, status)
select 'PB-STAY-PAST', branch, customer, 'Owner', '0940000001', now() - interval '3 days', now() - interval '1 day', 'booked' from ctx
union all
select 'PB-STAY-NEXT', branch, customer, 'Owner', '0940000001', now() + interval '1 day', now() + interval '3 days', 'booked' from ctx;
grant select on ctx to authenticated;

select tests.login(account) from ctx;
set local role authenticated;

select is(
  (select jsonb_path_query_array(public.my_appointments('upcoming') -> 'rows', '$[*].code')),
  '["PB-NEXT"]'::jsonb,
  'a booked visit whose time has passed is no longer upcoming'
);
select is(
  (select jsonb_path_query_array(public.my_appointments('past') -> 'rows', '$[*].code')),
  '["PB-PAST"]'::jsonb,
  'it is listed under past instead'
);
select is(
  (select (public.my_appointments('past') -> 'rows' -> 0 ->> 'overdue')::boolean),
  true,
  'and flagged overdue'
);
select is(
  (select (public.my_appointments('upcoming') -> 'rows' -> 0 ->> 'overdue')::boolean),
  false,
  'a visit still ahead is not overdue'
);
select is(
  (select jsonb_path_query_array(public.my_boarding_stays('upcoming') -> 'rows', '$[*].code')),
  '["PB-STAY-NEXT"]'::jsonb,
  'a booked stay past its planned check-out is no longer upcoming'
);
select is(
  (select jsonb_path_query_array(public.my_boarding_stays('past') -> 'rows', '$[*].code')),
  '["PB-STAY-PAST"]'::jsonb,
  'it is listed under past instead'
);
select is(
  (select (public.my_boarding_stays('past') -> 'rows' -> 0 ->> 'overdue')::boolean),
  true,
  'and flagged overdue'
);
reset role;
select is(
  (select status from public.appointments where code = 'PB-PAST'),
  'booked',
  'the stored status is left for the staff to change'
);

select * from finish();
rollback;
