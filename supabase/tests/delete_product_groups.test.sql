-- Deleting product groups: only groups never sold and never stocked go; the rest are kept with a reason.
begin;
\ir _helpers/setup.psql
select plan(8);

create temp table ctx as
select b as branch,
       tests.create_product('Unused', 10000) as unused,
       tests.create_product('Stocked', 10000) as stocked,
       tests.create_product('Sold', 25000) as sold
from tests.create_branch('DG') as b;
alter table ctx
  add column admin uuid, add column cashier uuid, add column customer uuid, add column result jsonb;
update ctx set
  admin    = tests.create_staff('dg-admin@test.local', branch, 'admin'),
  cashier  = tests.create_cashier('dg-cashier@test.local', branch),
  customer = tests.create_user('dg-buyer@test.local');
select tests.add_lot(branch, stocked, 5, current_date + 30, 'DG-S') from ctx;
select tests.add_lot(branch, sold, 5, current_date + 30, 'DG-SOLD') from ctx;
grant select, update on ctx to authenticated;

-- A sale of the "Sold" product.
select tests.login(cashier) from ctx;
set local role authenticated;
select lives_ok(
  $q$select public.create_invoice(jsonb_build_object(
    'branch_id', (select branch from ctx),
    'client_ref', gen_random_uuid(),
    'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', (select sold from ctx), 'qty', 1, 'unit_price', 25000)),
    'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 25000))
  ))$q$,
  'the sold product has a sale'
);

-- A customer may not delete.
select tests.login(customer) from ctx;
select throws_ok(
  $q$select public.delete_product_groups(array[(select group_id from public.products where id = (select unused from ctx))])$q$,
  '42501', null, 'a customer cannot delete products'
);

-- An admin deletes all three at once.
select tests.login(admin) from ctx;
update ctx set result = public.delete_product_groups(array[
  (select group_id from public.products where id = unused),
  (select group_id from public.products where id = stocked),
  (select group_id from public.products where id = sold)
]);

select is((select jsonb_array_length(result -> 'deleted') from ctx), 1, 'only the unused group is deleted');
select is(
  (select result -> 'blocked' ->> 0 from ctx)::jsonb ->> 'reason',
  'stocked', 'the group with a stock lot is kept as stocked'
);
select ok(
  exists (select 1 from ctx, jsonb_array_elements(result -> 'blocked') b where b ->> 'reason' = 'sold'),
  'the group with a sale is kept as sold'
);

reset role;
select is((select count(*)::int from public.products where id = (select unused from ctx)), 0, 'the unused product row is gone');
select is((select count(*)::int from public.products where id = (select sold from ctx)), 1, 'the sold product row is still there');
select is(
  (select count(*)::int from public.product_groups where id in (select group_id from public.products where id in (select stocked from ctx))),
  1, 'the stocked group is still there'
);

select * from finish();
rollback;
