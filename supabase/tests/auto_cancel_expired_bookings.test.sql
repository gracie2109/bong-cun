-- Bookings nobody showed up for are cancelled by the system after a grace hour, with a fixed reason,
-- and the customer's pages report them as expired. Started work and bookings ahead are left alone.
begin;
\ir _helpers/setup.psql
select plan(12);

create temp table ctx as
select tests.create_user('expired@test.local') as account, tests.create_branch('EB') as branch;
alter table ctx add column customer uuid;
update ctx set customer = tests.create_patient('0950000001', 'Mit');
update public.customers set user_id = (select account from ctx) where id = (select customer from ctx);

insert into public.appointments (code, branch_id, customer_id, customer_name, customer_phone, start_at, end_at, status)
select code, branch, customer, 'Owner', '0950000001', now() + s, now() + s + interval '1 hour', st
from ctx, (values
  ('EB-OLD',     interval '-5 hours',  'booked'),
  ('EB-RECENT',  interval '-90 minutes', 'booked'),
  ('EB-STARTED', interval '-5 hours',  'checked_in'),
  ('EB-NEXT',    interval '1 day',     'booked')
) v(code, s, st);
insert into public.boarding_stays (code, branch_id, customer_id, customer_name, customer_phone, planned_in_at, planned_out_at, status)
select code, branch, customer, 'Owner', '0950000001', now() + a, now() + b, st
from ctx, (values
  ('EB-STAY-OLD',  interval '-4 days', interval '-2 hours', 'booked'),
  ('EB-STAY-RECENT', interval '-2 days', interval '-20 minutes', 'booked'),
  ('EB-STAY-IN',   interval '-4 days', interval '-2 hours', 'checked_in'),
  ('EB-STAY-NEXT', interval '1 day',   interval '3 days',   'booked')
) v(code, a, b, st);
grant select on ctx to authenticated;

select tests.login(account) from ctx;
set local role authenticated;
select throws_ok($q$select public.auto_cancel_expired_bookings()$q$, '42501', null, 'a signed-in user cannot run the cleanup');
reset role;

select is(public.auto_cancel_expired_bookings(), '{"appointments": 1, "stays": 1}'::jsonb, 'one visit and one stay are expired (the ones past the grace hour)');
select is(
  (select array_agg(code order by code) from public.appointments where status = 'cancelled' and cancel_reason = public.expired_booking_reason()),
  array['EB-OLD'], 'only the long-past booked visit is cancelled with the expired reason'
);
select is(
  (select array_agg(code order by code) from public.appointments where status <> 'cancelled'),
  array['EB-NEXT', 'EB-RECENT', 'EB-STARTED'], 'recent, started and upcoming visits are untouched'
);
select is(
  (select array_agg(code order by code) from public.boarding_stays where status = 'cancelled'),
  array['EB-STAY-OLD'], 'only the long-past booked stay is cancelled'
);
select is(public.auto_cancel_expired_bookings(), '{"appointments": 0, "stays": 0}'::jsonb, 'running it again changes nothing');

select tests.login(account) from ctx;
set local role authenticated;
select is(
  (select jsonb_path_query_array(public.my_appointments('cancelled') -> 'rows', '$[*] ? (@.expired == true).code')),
  '["EB-OLD"]'::jsonb, 'the customer sees the cancelled visit as expired'
);
select is(
  (select jsonb_path_query_array(public.my_appointments('past') -> 'rows', '$[*] ? (@.overdue == true).code')),
  '["EB-RECENT"]'::jsonb, 'a visit inside the grace hour is still only overdue'
);
select is(
  (select jsonb_path_query_array(public.my_boarding_stays('cancelled') -> 'rows', '$[*] ? (@.expired == true).code')),
  '["EB-STAY-OLD"]'::jsonb, 'the customer sees the cancelled stay as expired'
);
select is(
  (select jsonb_path_query_array(public.my_boarding_stays('upcoming') -> 'rows', '$[*].code')),
  '["EB-STAY-NEXT"]'::jsonb, 'upcoming stays keep only the one ahead'
);

select is(
  (select jsonb_path_query_array(public.my_appointments('cancelled') -> 'rows', '$[*].code')),
  '["EB-OLD"]'::jsonb, 'the cancelled tab lists only the cancelled visit'
);
select is(
  (select jsonb_path_query_array(public.my_appointments('past') -> 'rows', '$[*].code')),
  '["EB-RECENT"]'::jsonb, 'the past tab no longer lists cancelled visits'
);

select * from finish();
rollback;
