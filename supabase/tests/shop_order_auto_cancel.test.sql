-- The nightly clean-up cancels online orders left pending too long and leaves everything else alone.
begin;
\ir _helpers/setup.psql
select plan(8);

create temp table ctx as
select tests.create_branch('SO') as branch, tests.create_user('shopper@test.local', 'customer') as shopper;
alter table ctx add column customer uuid, add column old_pending uuid, add column new_pending uuid,
  add column old_confirmed uuid;
update ctx set customer = (tests.create_patient('0920000001', 'Nho'));
grant select, update on ctx to authenticated;

create function pg_temp.make_order(p_code text, p_status text, p_age interval) returns uuid
language sql as $$
  insert into public.shop_orders (code, branch_id, user_id, customer_id, status, delivery_method, payment_method,
                                  receiver_name, receiver_phone, subtotal, total, placed_at)
  select p_code, branch, shopper, customer, p_status, 'pickup', 'pay_at_store', 'Khach', '0920000001', 100000, 100000,
         now() - p_age
  from ctx
  returning id;
$$;

update ctx set
  old_pending   = pg_temp.make_order('SO-OLD-P', 'pending', interval '3 days'),
  new_pending   = pg_temp.make_order('SO-NEW-P', 'pending', interval '1 day'),
  old_confirmed = pg_temp.make_order('SO-OLD-C', 'confirmed', interval '30 days');

select is(public.auto_cancel_stale_shop_orders(48), 1, 'one stale pending order is cancelled');
select is((select status from public.shop_orders where id = (select old_pending from ctx)), 'cancelled', 'the stale order is cancelled');
select ok((select cancel_reason like 'Tự hủy%' and cancelled_at is not null
           from public.shop_orders where id = (select old_pending from ctx)), 'it carries a reason and a time');
select is((select status from public.shop_orders where id = (select new_pending from ctx)), 'pending', 'a recent pending order stays');
select is((select status from public.shop_orders where id = (select old_confirmed from ctx)), 'confirmed', 'a confirmed order is never touched');
select is((select count(*)::int from public.shop_order_events
           where order_id = (select old_pending from ctx) and status = 'cancelled' and actor_name = 'Hệ thống'),
          1, 'the order log records the system cancel');
select is(public.auto_cancel_stale_shop_orders(48), 0, 'running again changes nothing');

select tests.login(shopper) from ctx;
set local role authenticated;
select throws_ok('select public.auto_cancel_stale_shop_orders(48)', '42501', null, 'signed-in users cannot run the clean-up');
reset role;

select * from finish();
rollback;
