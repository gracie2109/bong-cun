-- "Out of stock" only counts products that once had a lot at the branch: a product that never received
-- stock is not out of stock. The dashboard count and the stock screen's "out" filter agree.
begin;
\ir _helpers/setup.psql
select plan(5);

create temp table ctx as
select tests.create_branch('SO') as branch,
       tests.create_product('Sold out', 10000) as sold_out,
       tests.create_product('Never stocked', 10000) as never_stocked,
       tests.create_product('In stock', 10000) as in_stock,
       tests.create_user('boss@test.local', 'admin') as boss;
select tests.add_lot(branch, sold_out, 0, null, 'EMPTY') from ctx;
select tests.add_lot(branch, in_stock, 5, null, 'FULL') from ctx;
grant select on ctx to authenticated;

select tests.login(boss) from ctx;
set local role authenticated;

select is((select (public.stock_alert_counts(branch, 60) ->> 'out')::int from ctx), 1,
          'only the product that had a lot counts as out of stock');
select is((select count(*)::int from ctx, public.stock_summary(branch, null, 'out', 60, 50, 0)), 1,
          'the out filter lists the same single product');
select is((select s.name from ctx, public.stock_summary(branch, null, 'out', 60, 50, 0) s), 'Sold out',
          'and it is the sold-out one');
select is((select count(*)::int from ctx, public.stock_summary(branch, 'Never', 'all', 60, 50, 0)), 1,
          'the never-stocked product is still listed on the stock screen');
select is((select (public.stock_alert_counts(branch, 60) ->> 'low')::int from ctx), 0,
          'the other counts are untouched');

reset role;
select * from finish();
rollback;
