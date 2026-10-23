-- Revenue is counted on the day the money is taken: an online invoice made (packed) days ago and paid
-- today is today's revenue, not the packing day's. Unpaid cash on delivery is shown apart, and an order
-- returned from delivery is a return, not a cancellation.
begin;
\ir _helpers/setup.psql
select plan(10);

create temp table ctx as
select tests.create_branch('PD') as branch, tests.create_user('boss-pd@test.local', 'admin') as boss,
       tests.create_user('shopper-pd@test.local', 'customer') as shopper,
       (now() at time zone 'Asia/Ho_Chi_Minh')::date as today,
       (now() at time zone 'Asia/Ho_Chi_Minh')::date - 2 as packed_day;
alter table ctx add column customer uuid, add column delivered uuid, add column pending uuid,
  add column returned uuid, add column cancelled uuid, add column counter uuid;
update ctx set customer = tests.create_patient('0930000001', 'Mun');
grant select, update on ctx to authenticated;

create function pg_temp.make_invoice(p_code text, p_status text, p_created interval, p_total numeric) returns uuid
language sql as $$
  insert into public.invoices (code, branch_id, status, subtotal, total, created_by, channel, created_at,
                               cancelled_at)
  select p_code, branch, p_status, p_total, p_total, boss, 'online', now() - p_created,
         case when p_status = 'cancelled' then now() end
  from ctx
  returning id;
$$;

create function pg_temp.make_order(p_code text, p_status text, p_invoice uuid) returns uuid
language sql as $$
  insert into public.shop_orders (code, branch_id, user_id, customer_id, status, delivery_method, payment_method,
                                  receiver_name, receiver_phone, ship_street, ghn_district_id, ghn_ward_code,
                                  subtotal, total, invoice_id)
  select p_code, branch, shopper, customer, p_status, 'delivery', 'cod', 'Khach', '0930000001', '1 Duong A',
         1, '1', 100000, 100000, p_invoice
  from ctx
  returning id;
$$;

-- Packed two days ago, delivered (paid) today.
update ctx set delivered = pg_temp.make_invoice('PD-1', 'unpaid', interval '2 days', 100000);
update public.invoices set status = 'paid' where id = (select delivered from ctx);

-- Packed yesterday, still on its way: cash on delivery to come.
update ctx set pending = pg_temp.make_invoice('PD-2', 'unpaid', interval '1 day', 80000);
select pg_temp.make_order('PD-O2', 'shipping', (select pending from ctx));

-- Came back from delivery, and a cancelled one that never left.
update ctx set returned = pg_temp.make_invoice('PD-3', 'cancelled', interval '3 days', 50000);
select pg_temp.make_order('PD-O3', 'returned', (select returned from ctx));
update ctx set cancelled = pg_temp.make_invoice('PD-4', 'cancelled', interval '1 day', 30000);
select pg_temp.make_order('PD-O4', 'cancelled', (select cancelled from ctx));

-- Paid when made: the paid time is the creation time.
update ctx set counter = pg_temp.make_invoice('PD-5', 'paid', interval '3 days', 20000);

select is((select paid_at from public.invoices where id = (select delivered from ctx)), now(),
          'an invoice that turns paid gets the payment time');
select is((select paid_at from public.invoices where id = (select counter from ctx)),
          (select created_at from public.invoices where id = (select counter from ctx)),
          'an invoice inserted as paid is paid when made');
select is((select paid_at from public.invoices where id = (select pending from ctx)), null,
          'an unpaid invoice has no payment time');

select tests.login(boss) from ctx;
set local role authenticated;

select is((select (public.report_overview(branch, today, today) ->> 'invoice_count')::int from ctx), 1,
          'the order delivered today is today''s revenue');
select is((select (public.report_overview(branch, today, today) ->> 'net_revenue')::numeric from ctx), 100000::numeric,
          'with its full amount');
select is((select (public.report_overview(branch, packed_day, packed_day) ->> 'invoice_count')::int from ctx), 0,
          'and not the packing day''s');
select is((select (public.report_overview(branch, today, today) -> 'pending_cod' ->> 'amount')::numeric from ctx), 80000::numeric,
          'cash on delivery still to come is reported apart');
select is((select (public.report_overview(branch, today, today) ->> 'cancelled_count')::int from ctx), 1,
          'a cancelled order counts as cancelled');
select is((select (public.report_overview(branch, today, today) ->> 'returned_online_count')::int from ctx), 1,
          'an order returned from delivery counts as returned');
select is((select invoice_count from public.report_revenue_series((select branch from ctx), (select today from ctx), (select today from ctx))),
          1, 'the daily series uses the payment day too');
reset role;

select * from finish();
rollback;
