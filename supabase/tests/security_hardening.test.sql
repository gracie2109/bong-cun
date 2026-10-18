-- Anti-clone hardening (20261026010000): order throttle, no anonymous bookings,
-- staff-only uploads to the public images bucket, stray grants removed.
begin;
\ir _helpers/setup.psql
select plan(9);

create temp table ctx as
select tests.create_branch('SH') as branch,
       tests.create_user('shopper@test.local', 'customer') as shopper,
       tests.create_user('shopper2@test.local', 'customer') as shopper2;
alter table ctx add column customer uuid, add column staff uuid;
update ctx set customer = tests.create_patient('0920000009', 'Mit');
update ctx set staff = tests.create_staff('staff@test.local', (select branch from ctx), 'cashier');
grant select on ctx to authenticated, anon;

create function pg_temp.make_order(p_user uuid, p_code text, p_status text, p_age interval) returns uuid
language sql as $$
  insert into public.shop_orders (code, branch_id, user_id, customer_id, status, delivery_method, payment_method,
                                  receiver_name, receiver_phone, subtotal, total, placed_at)
  select p_code, branch, p_user, customer, p_status, 'pickup', 'pay_at_store', 'Khach', '0920000009', 100000, 100000,
         now() - p_age
  from ctx
  returning id;
$$;

-- Five orders waiting for confirmation is the cap.
select pg_temp.make_order((select shopper from ctx), 'SH-P' || n, 'pending', interval '2 days') from generate_series(1, 5) n;
select throws_like(
  $$select pg_temp.make_order((select shopper from ctx), 'SH-P6', 'pending', interval '0')$$,
  'too many online orders%', 'a sixth waiting order is refused');

-- Ten orders in an hour is the cap, whatever their status.
select pg_temp.make_order((select shopper2 from ctx), 'SH-C' || n, 'confirmed', interval '10 minutes') from generate_series(1, 10) n;
select throws_like(
  $$select pg_temp.make_order((select shopper2 from ctx), 'SH-C11', 'confirmed', interval '0')$$,
  'too many online orders%', 'an eleventh order within an hour is refused');
update public.shop_orders set placed_at = now() - interval '2 hours' where user_id = (select shopper2 from ctx);
select lives_ok(
  $$select pg_temp.make_order((select shopper2 from ctx), 'SH-C12', 'confirmed', interval '0')$$,
  'older orders no longer count');

-- Anonymous visitors cannot write bookings any more.
set local role anon;
select throws_ok(
  $$insert into public.bookings (name, email, phone_number, scheduled_at) values ('X', 'x@x.vn', '0900000000', now())$$,
  '42501', null, 'anonymous booking inserts are refused');
reset role;

-- Customers cannot upload into the public images bucket; staff still can.
select tests.login(shopper) from ctx;
set local role authenticated;
select throws_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('images', %L)$q$, (select shopper || '/avatar/a.png' from ctx)),
  '42501', null, 'a customer cannot upload into the images bucket');
reset role;

select tests.login(staff) from ctx;
set local role authenticated;
select lives_ok(
  format($q$insert into storage.objects (bucket_id, name) values ('images', %L)$q$, (select staff || '/customers/a.png' from ctx)),
  'staff can upload into their own folder');
reset role;

-- Stray grants are gone.
select ok(not has_function_privilege('anon', 'public.pets_deceased_before()', 'execute'), 'anon cannot execute the trigger function');
select ok(not has_table_privilege('anon', 'public.pet_overview', 'select'), 'anon cannot select pet_overview');
select ok(not has_function_privilege('authenticated', 'public.shop_orders_throttle()', 'execute'), 'the throttle is not callable');

select * from finish();
rollback;
