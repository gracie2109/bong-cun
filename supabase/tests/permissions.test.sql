-- Who may do what: branch scoping of the POS, method checks, and what customers and
-- signed-out visitors can reach.
begin;
\ir _helpers/setup.psql
select plan(10);

create temp table ctx as
select a as branch_a, b as branch_b, tests.create_product('Collar', 50000) as product
from tests.create_branch('PA') as a, tests.create_branch('PB') as b;
alter table ctx add column cashier uuid, add column vet uuid, add column customer uuid, add column invoice uuid;
update ctx set
  cashier  = tests.create_cashier('cashier-a@test.local', branch_a),
  vet      = tests.create_cashier('vet-a@test.local', branch_a, 'vet'),
  customer = tests.create_user('buyer@test.local');
select tests.add_lot(branch_a, product, 20, null, 'L1') from ctx;
select tests.add_lot(branch_b, product, 20, null, 'L1') from ctx;
grant select, update on ctx to anon, authenticated;

-- Signed out: staff functions are not even callable.
set local role anon;
select throws_ok(
  format($q$select public.create_invoice(jsonb_build_object('branch_id', %L::uuid))$q$, (select branch_a from ctx)),
  '42501', null, 'a signed-out visitor cannot call create_invoice'
);
reset role;

-- A cashier of branch A sells at A, not at B.
select tests.login(cashier) from ctx;
set local role authenticated;
update ctx set invoice = (public.create_invoice(jsonb_build_object(
  'branch_id', branch_a,
  'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', product, 'qty', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 50000))
)) ->> 'id')::uuid;
select isnt((select invoice from ctx), null, 'a cashier sells at their own branch');
select throws_ok(
  format($q$select public.create_invoice(jsonb_build_object(
     'branch_id', %L::uuid,
     'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', %L::uuid, 'qty', 1)),
     'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 50000))))$q$,
     (select branch_b from ctx), (select product from ctx)),
  '42501', null, 'a cashier cannot sell at another branch'
);
select throws_ok(
  format($q$select public.create_invoice(jsonb_build_object(
     'branch_id', %L::uuid, 'discount_amount', 10000,
     'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', %L::uuid, 'qty', 1)),
     'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 40000))))$q$,
     (select branch_a from ctx), (select product from ctx)),
  '42501', null, 'a discount above 10% needs a manager'
);
select throws_ok(
  format('select public.cancel_invoice(%L::uuid, %L)', (select invoice from ctx), 'test'),
  '42501', null, 'the cashier role (no pos DELETE) cannot cancel an invoice'
);
reset role;

-- A vet at the same branch has no pos permission.
select tests.login(vet) from ctx;
set local role authenticated;
select throws_ok(
  format($q$select public.create_invoice(jsonb_build_object(
     'branch_id', %L::uuid,
     'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', %L::uuid, 'qty', 1)),
     'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 50000))))$q$,
     (select branch_a from ctx), (select product from ctx)),
  '42501', null, 'a vet without pos permission cannot sell'
);
reset role;

-- A customer account sees no shop data and no records of other people.
select tests.login(customer) from ctx;
set local role authenticated;
select is((select count(*) from public.invoices), 0::bigint, 'a customer reads no invoices');
select is((select count(*) from public.medical_visits), 0::bigint, 'a customer reads no medical visits');
select is((select count(*) from public.customers), 0::bigint, 'a customer reads no customer records');
select is(
  (select count(*) from public.search_customers('cashier', 5)),
  0::bigint,
  'a customer cannot search customers'
);
reset role;

select * from finish();
rollback;
