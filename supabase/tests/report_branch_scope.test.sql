-- Branch scoping of the dashboard data sources: report_* with p_branch null only adds up the
-- branches the caller may see, and the per-branch operational RPCs never leak another branch.
-- has_permission(..., null) means "at any branch", so every RPC taking a nullable branch must
-- expand it to an explicit list (report_branch_ids) instead of trusting a null check.
begin;
\ir _helpers/setup.psql
select plan(11);

insert into public.roles (name) values ('t_reporter'), ('t_blank');
insert into public.role_permissions (role, permission, methods) values ('t_reporter', 'reports', array['VIEW']);

create temp table ctx as
select a as branch_a, b as branch_b, tests.create_product('Collar', 50000) as product,
       (now() at time zone 'Asia/Ho_Chi_Minh')::date as today
from tests.create_branch('RA') as a, tests.create_branch('RB') as b;
alter table ctx
  add column cashier_b uuid, add column reporter_a uuid, add column reporter_b uuid,
  add column blank_a uuid, add column boss uuid, add column invoice jsonb;
update ctx set
  cashier_b  = tests.create_cashier('cashier-b@test.local', branch_b),
  reporter_a = tests.create_staff('reporter-a@test.local', branch_a, 't_reporter'),
  reporter_b = tests.create_staff('reporter-b@test.local', branch_b, 't_reporter'),
  blank_a    = tests.create_staff('blank-a@test.local', branch_a, 't_blank'),
  boss       = tests.create_user('boss@test.local', 'admin');
select tests.add_lot(branch_b, product, 20, current_date - 1, 'OLD') from ctx;
select tests.add_lot(branch_b, product, 20, null, 'OK') from ctx;
grant select, update on ctx to authenticated;

-- One paid sale at branch B.
select tests.login(cashier_b) from ctx;
set local role authenticated;
update ctx set invoice = public.create_invoice(jsonb_build_object(
  'branch_id', branch_b,
  'lines', jsonb_build_array(jsonb_build_object('type', 'product', 'id', product, 'qty', 1)),
  'payments', jsonb_build_array(jsonb_build_object('method', 'cash', 'amount', 50000))
));
reset role;

-- A reporter at A only: "all branches" adds up A alone, B is refused.
select tests.login(reporter_a) from ctx;
set local role authenticated;
select is(
  (select (public.report_overview(null, today, today) ->> 'invoice_count')::int from ctx), 0,
  'p_branch null does not include a branch the reporter has no access to'
);
select throws_ok(
  format('select public.report_overview(%L::uuid, current_date, current_date)', (select branch_b from ctx)),
  '42501', null, 'a reporter at A cannot ask for branch B'
);
select lives_ok(
  format('select public.report_overview(%L::uuid, current_date, current_date)', (select branch_a from ctx)),
  'a reporter can read their own branch'
);
select is(
  (select count(*)::int from public.report_revenue_series(null, (select today from ctx), (select today from ctx))
   where invoice_count > 0), 0,
  'the revenue series with p_branch null stays inside the allowed branches'
);
reset role;

-- A reporter at B sees the sale.
select tests.login(reporter_b) from ctx;
set local role authenticated;
select is(
  (select (public.report_overview(null, today, today) ->> 'invoice_count')::int from ctx), 1,
  'a reporter at B sees the branch B sale through p_branch null'
);
reset role;

-- An admin account sees every branch.
select tests.login(boss) from ctx;
set local role authenticated;
select is(
  (select (public.report_overview(null, today, today) ->> 'invoice_count')::int from ctx), 1,
  'an admin account sees every branch through p_branch null'
);
reset role;

-- Staff without the reports permission are refused, with or without a branch.
select tests.login(blank_a) from ctx;
set local role authenticated;
select throws_ok(
  'select public.report_overview(null, current_date, current_date)',
  '42501', null, 'staff without reports are refused for p_branch null'
);
reset role;

-- Operational RPCs: wrong branch is refused; a null branch shows no stock of another branch.
select tests.login(blank_a) from ctx;
set local role authenticated;
select throws_ok(
  format('select public.boarding_board(%L::uuid)', (select branch_b from ctx)),
  '42501', null, 'boarding_board refuses a branch the caller has no role at'
);
select throws_ok(
  format('select public.medical_queue(%L::uuid)', (select branch_b from ctx)),
  '42501', null, 'medical_queue refuses a branch the caller has no role at'
);
select throws_ok(
  format('select public.spa_day_board(%L::uuid, current_date)', (select branch_b from ctx)),
  '42501', null, 'spa_day_board refuses a branch the caller has no role at'
);
reset role;

select tests.login(boss) from ctx;
set local role authenticated;
select is(
  (select (public.stock_alert_counts(null) ->> 'expired')::int), 0,
  'stock_alert_counts with p_branch null does not report the expired lot of one branch'
);
reset role;

select * from finish();
rollback;
