-- Selling at the counter: server-side price, stock taken first-expiry-first-out, replays of
-- the same sale, cancelling puts stock back, returns cannot exceed what was sold.
begin;
\ir _helpers/setup.psql
select plan(17);

create temp table ctx as
select b as branch, tests.create_product('Pate', 25000) as product
from tests.create_branch('T1') as b;
alter table ctx
  add column cashier uuid, add column lot_late uuid, add column lot_early uuid,
  add column lot_expired uuid, add column invoice jsonb, add column ref uuid default gen_random_uuid();
update ctx set
  cashier     = tests.create_cashier('cashier@test.local', branch),
  lot_late    = tests.add_lot(branch, product, 10, current_date + 90, 'LATE'),
  lot_early   = tests.add_lot(branch, product, 3,  current_date + 10, 'EARLY'),
  lot_expired = tests.add_lot(branch, product, 50, current_date - 1,  'EXPIRED');
grant select, update on ctx to authenticated;

select tests.login(cashier) from ctx;
set local role authenticated;

-- The client sends a wrong price; the server uses its own.
update ctx set invoice = public.create_invoice(jsonb_build_object(
  'branch_id', branch,
  'client_ref', ref,
  'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', product, 'qty', 5, 'unit_price', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 130000))
));

select is((select (invoice ->> 'total')::numeric from ctx), 125000::numeric, 'total uses the server price, not the one sent');
select is((select (invoice ->> 'change_amount')::numeric from ctx), 5000::numeric, 'change is paid minus total');
-- src/repositories/pos/invoices.ts parses this result with zod: keep the keys in step.
select ok(
  (select invoice ?& array['id', 'code', 'total', 'change_amount', 'replayed'] from ctx),
  'create_invoice returns the keys the app reads'
);

reset role;
select is((select tests.lot_qty(lot_early) from ctx), 0::numeric, 'the lot expiring first is used up first');
select is((select tests.lot_qty(lot_late) from ctx), 8::numeric, 'the rest comes from the next lot');
select is((select tests.lot_qty(lot_expired) from ctx), 50::numeric, 'an expired lot is never sold');

set local role authenticated;
select is(
  (select public.create_invoice(jsonb_build_object(
     'branch_id', branch, 'client_ref', ref,
     'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', product, 'qty', 5)),
     'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 130000))
   )) ->> 'replayed' from ctx),
  'true',
  'sending the same sale again returns the first invoice'
);
reset role;
select is((select count(*) from public.invoices i join ctx on i.branch_id = ctx.branch), 1::bigint, 'the replay made no second invoice');
select is((select tests.lot_qty(lot_late) from ctx), 8::numeric, 'the replay took no stock');

set local role authenticated;
select throws_ok(
  format($q$select public.create_invoice(jsonb_build_object(
     'branch_id', %L::uuid,
     'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', %L::uuid, 'qty', 1)),
     'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 1000))))$q$,
     (select branch from ctx), (select product from ctx)),
  '22023', null, 'an underpaid sale is refused'
);
select throws_ok(
  format($q$select public.create_invoice(jsonb_build_object(
     'branch_id', %L::uuid,
     'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', %L::uuid, 'qty', 100)),
     'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 2500000))))$q$,
     (select branch from ctx), (select product from ctx)),
  'P0001', null, 'selling more than the sellable stock is refused'
);

-- A return of 2 units goes back into stock; returning more than is left is refused.
-- Returns need pos DELETE, which the default cashier role does not have: an admin takes it.
reset role;
select tests.logout();
update public.users set role = 'admin' where id = (select cashier from ctx);
select tests.login(cashier) from ctx;
set local role authenticated;

select lives_ok(
  format($q$select public.create_sales_return(jsonb_build_object(
     'invoice_id', %L::uuid, 'reason', 'damaged', 'refund_method', 'cash',
     'lines', jsonb_build_array(jsonb_build_object(
       'invoice_line_id', (select id from public.invoice_lines where invoice_id = %L::uuid), 'qty', 2))))$q$,
     (select (invoice ->> 'id') from ctx), (select (invoice ->> 'id') from ctx)),
  'a return of part of the line is accepted'
);
select throws_ok(
  format($q$select public.create_sales_return(jsonb_build_object(
     'invoice_id', %L::uuid, 'reason', 'again', 'refund_method', 'cash',
     'lines', jsonb_build_array(jsonb_build_object(
       'invoice_line_id', (select id from public.invoice_lines where invoice_id = %L::uuid), 'qty', 4))))$q$,
     (select (invoice ->> 'id') from ctx), (select (invoice ->> 'id') from ctx)),
  '22023', null, 'returning more than is left on the line is refused'
);

reset role;
select is(
  (select tests.lot_qty(lot_early) + tests.lot_qty(lot_late) from ctx),
  10::numeric,
  'the 2 returned units are back in stock'
);

-- An invoice with returns cannot be cancelled any more.
set local role authenticated;
select throws_ok(
  format('select public.cancel_invoice(%L::uuid, %L)', (select (invoice ->> 'id') from ctx), 'test'),
  'P0001', null, 'an invoice with returns cannot be cancelled'
);

-- Cancelling a sale puts its stock back into the lots it came from.
update ctx set invoice = public.create_invoice(jsonb_build_object(
  'branch_id', branch,
  'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', product, 'qty', 4)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'transfer', 'amount', 100000))
));
select lives_ok(
  format('select public.cancel_invoice(%L::uuid, %L)', (select (invoice ->> 'id') from ctx), 'test'),
  'a sale can be cancelled while its shift is open'
);
reset role;
select is(
  (select tests.lot_qty(lot_early) + tests.lot_qty(lot_late) from ctx),
  10::numeric,
  'the cancelled sale put its 4 units back'
);

select * from finish();
rollback;
