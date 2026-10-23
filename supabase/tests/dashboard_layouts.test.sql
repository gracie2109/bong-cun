-- Personal dashboard layouts: own-row reads, writes only through the RPCs, shape and size limits,
-- optimistic version check.
begin;
\ir _helpers/setup.psql
select plan(17);

create temp table ctx as
select tests.create_branch('DL') as branch,
       tests.create_user('guest@test.local', 'customer') as guest;
alter table ctx add column a uuid, add column b uuid;
update ctx set a = tests.create_staff('dl-a@test.local', branch, 'cashier'),
               b = tests.create_staff('dl-b@test.local', branch, 'cashier');
grant select on ctx to authenticated, anon;

create function pg_temp.item(p_id text, p_x numeric, p_w numeric, p_extra jsonb default '{}')
returns jsonb language sql as $$
  select jsonb_build_object('v', 1, 'items', jsonb_build_array(
    jsonb_build_object('id', p_id, 'type', 'kpi', 'x', p_x, 'y', 0, 'w', p_w, 'h', 2) || p_extra));
$$;
grant execute on function pg_temp.item(text, numeric, numeric, jsonb) to authenticated;

select tests.login(a) from ctx;
set local role authenticated;

select is(public.save_dashboard_layout('today', pg_temp.item('aaaaaaaa', 0, 2), 0), 1, 'first save returns version 1');
select is(public.save_dashboard_layout('today', pg_temp.item('aaaaaaaa', 1, 2), 1), 2, 'saving with the current version returns 2');
select throws_ok(
  $$select public.save_dashboard_layout('today', '{"v":1,"items":[]}'::jsonb, 1)$$,
  'P0001', 'the layout was changed somewhere else', 'a stale version is a conflict');
select is((select count(*)::int from public.dashboard_layouts), 1, 'a person reads their own row');
select lives_ok(
  $$select public.save_dashboard_layout('today', pg_temp.item('aaaaaaaa', 0, 1, '{"config":{"metric":"revenue.net"}}'), 2)$$,
  'a small config is accepted');

select throws_ok($$select public.save_dashboard_layout('t2', '{"v":2,"items":[]}'::jsonb, 0)$$,
  '22023', 'invalid dashboard layout: shape', 'v other than 1 is refused');
select throws_ok($$select public.save_dashboard_layout('t2', pg_temp.item('bbbbbbbb', 3, 2), 0)$$,
  '22023', 'invalid dashboard layout: item', 'x + w over 4 is refused');
select throws_ok($$select public.save_dashboard_layout('t2', pg_temp.item('bbbbbbbb', 0, 0), 0)$$,
  '22023', 'invalid dashboard layout: item', 'w = 0 is refused');
select throws_ok($$select public.save_dashboard_layout('t2', pg_temp.item('bbbbbbbb', 1.5, 1), 0)$$,
  '22023', 'invalid dashboard layout: item', 'a fractional cell is refused');
select throws_ok(
  $$select public.save_dashboard_layout('t2', pg_temp.item('bbbbbbbb', 0, 1, jsonb_build_object('config', jsonb_build_object('s', repeat('x', 3000)))), 0)$$,
  '22023', 'invalid dashboard layout: item', 'a config over 2 KB is refused');
select throws_ok(
  $$select public.save_dashboard_layout('t2', (select jsonb_set(pg_temp.item('bbbbbbbb', 0, 1), '{items,0,type}', '"k;pi"')), 0)$$,
  '22023', 'invalid dashboard layout: item', 'odd characters in the type are refused');
select throws_ok(
  $$select public.save_dashboard_layout('t2', jsonb_build_object('v', 1, 'items', (select jsonb_agg(pg_temp.item('bbbbbbbb', 0, 1) -> 'items' -> 0) from generate_series(1, 2))), 0)$$,
  '22023', 'invalid dashboard layout: duplicate_id', 'duplicate ids are refused');
select throws_ok($$insert into public.dashboard_layouts (user_id, dashboard_key, layout) select a, 'x', '{}' from ctx$$,
  '42501', null, 'no direct insert into the table');
reset role;

-- Person B cannot see or reset A's layout.
select tests.login(b) from ctx;
set local role authenticated;
select is((select count(*)::int from public.dashboard_layouts), 0, 'another person sees no rows of A');
select public.reset_dashboard_layout('today');
reset role;
select is((select count(*)::int from public.dashboard_layouts), 1, 'resetting does not delete another person''s row');

-- A customer account and anon cannot save.
select tests.login(guest) from ctx;
set local role authenticated;
select throws_ok($$select public.save_dashboard_layout('today', '{"v":1,"items":[]}'::jsonb, 0)$$,
  '42501', null, 'a non-staff account cannot save a layout');
reset role;
set local role anon;
select throws_ok($$select public.save_dashboard_layout('today', '{"v":1,"items":[]}'::jsonb, 0)$$,
  '42501', null, 'anon cannot call the RPC');

select * from finish();
rollback;
