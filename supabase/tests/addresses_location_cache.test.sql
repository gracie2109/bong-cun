-- Two-level addresses: save_my_address, place_shop_order and the shop settings with the location cache.
-- The units below are made-up fixtures for this test only, not real administrative data.
begin;
\ir _helpers/setup.psql
select plan(21);

-- The real cache may already be filled by the sync; the fixtures below need it empty (rolled back with the test).
delete from public.location_provider_codes;
delete from public.location_units;
delete from public.location_catalogs;

insert into public.location_catalogs (id, source, effective_on, is_current)
values ('addr-test-catalog', 'test fixture', '2025-07-01', true);
insert into public.location_units (code, level, unit_type, official_code, name, full_name, parent_code, status, effective_from, catalog_id)
values
  ('vn_aaaaaaaaaaaaaaaaaaaa', 'province', 'municipality', '79', 'Thành Thử', 'Thành phố Thành Thử', null, 'active', '2025-07-01', 'addr-test-catalog'),
  ('vn_bbbbbbbbbbbbbbbbbbbb', 'commune', 'ward', '26740', 'Bến Thử', 'Phường Bến Thử', 'vn_aaaaaaaaaaaaaaaaaaaa', 'active', '2025-07-01', 'addr-test-catalog'),
  ('vn_cccccccccccccccccccc', 'commune', 'ward', '26741', 'Đã Cũ', 'Phường Đã Cũ', 'vn_aaaaaaaaaaaaaaaaaaaa', 'retired', '2025-07-01', 'addr-test-catalog');

create temp table ctx as
select tests.create_branch('AL') as branch,
       tests.create_user('addr-customer@test.local') as customer;
alter table ctx add column product uuid, add column staff uuid, add column new_addr jsonb, add column old_addr jsonb,
  add column order_new jsonb, add column order_old jsonb;
update ctx set product = tests.create_product('Address kibble', 40000);
select tests.add_lot(branch, product, 50, current_date + 90, 'AL-1') from ctx;
update ctx set staff = tests.create_staff('addr-admin@test.local', branch, 'admin');
insert into public.shop_settings (online_branch_id, allow_cod, allow_pickup, flat_shipping_fee)
select branch, true, true, 30000 from ctx
on conflict (id) do update set online_branch_id = excluded.online_branch_id, allow_cod = true, allow_pickup = true;
grant select, update on ctx to authenticated;

-- ------------------------------------------------------------ save_my_address
select tests.login(customer) from ctx;
set local role authenticated;

update ctx set new_addr = public.save_my_address(jsonb_build_object(
  'receiver_name', 'An', 'phone', '0901234567', 'street', '12 Lê Lợi', 'ward_location_code', 'vn_bbbbbbbbbbbbbbbbbbbb'));
select is(new_addr ->> 'location_model', 'vn_2025', 'a ward code saves a two-level address') from ctx;
select is(new_addr ->> 'province_location_code', 'vn_aaaaaaaaaaaaaaaaaaaa', 'the province comes from the ward') from ctx;
select is(new_addr ->> 'province_name', 'Thành phố Thành Thử', 'names are copied from the cache') from ctx;
select is(new_addr ->> 'ward_official_code', '26740', 'the state code is kept') from ctx;
select is(new_addr -> 'ghn_district_id', 'null'::jsonb, 'no GHN ids on a two-level address') from ctx;
select is((new_addr ->> 'is_default')::boolean, true, 'the first address is the default') from ctx;

select throws_ok(
  $q$select public.save_my_address(jsonb_build_object('receiver_name', 'An', 'phone', '0901234567', 'street', 'x', 'ward_location_code', 'vn_cccccccccccccccccccc'))$q$,
  '22023', null, 'a retired ward is refused');
select throws_ok(
  $q$select public.save_my_address(jsonb_build_object('receiver_name', 'An', 'phone', '0901234567', 'street', 'x', 'ward_location_code', 'vn_zzzzzzzzzzzzzzzzzzzz'))$q$,
  'P0002', null, 'an unknown ward is refused');
select throws_ok(
  $q$select public.save_my_address(jsonb_build_object('receiver_name', 'An', 'phone', '0901234567', 'street', 'x', 'ward_location_code', 'vn_aaaaaaaaaaaaaaaaaaaa'))$q$,
  '22023', null, 'a province is not a ward');

update ctx set old_addr = public.save_my_address(jsonb_build_object(
  'receiver_name', 'Bình', 'phone', '0907654321', 'street', '3 Trần Hưng Đạo', 'province_name', 'Province', 'district_name', 'District',
  'ward_name', 'Ward', 'ghn_province_id', 1, 'ghn_district_id', 2, 'ghn_ward_code', '3'));
select is(old_addr ->> 'location_model', 'ghn_legacy', 'the old payload still saves a GHN address') from ctx;
select is((old_addr ->> 'ghn_district_id')::int, 2, 'and keeps its GHN ids') from ctx;
select is((old_addr ->> 'is_default')::boolean, false, 'a second address is not the default') from ctx;
select throws_ok(
  $q$select public.save_my_address(jsonb_build_object('receiver_name', 'An', 'phone', '0901234567', 'street', 'x'))$q$,
  '22023', null, 'neither form is complete');

-- ---------------------------------------------------------- place_shop_order
update ctx set order_new = public.place_shop_order(jsonb_build_object(
  'client_ref', '22222222-2222-4222-8222-222222222222', 'delivery_method', 'delivery', 'address_id', new_addr ->> 'id',
  'lines', jsonb_build_array(jsonb_build_object('product_id', product, 'qty', 1))));
update ctx set order_old = public.place_shop_order(jsonb_build_object(
  'client_ref', '33333333-3333-4333-8333-333333333333', 'delivery_method', 'delivery', 'address_id', old_addr ->> 'id',
  'lines', jsonb_build_array(jsonb_build_object('product_id', product, 'qty', 1))));
reset role;

select is(
  (select ship_location_model from public.shop_orders where id = (select (order_new ->> 'id')::uuid from ctx)),
  'vn_2025', 'an order to a two-level address keeps the model');
select is(
  (select ship_ward_location_code from public.shop_orders where id = (select (order_new ->> 'id')::uuid from ctx)),
  'vn_bbbbbbbbbbbbbbbbbbbb', 'and the ward code');
select is(
  (select ghn_ward_code from public.shop_orders where id = (select (order_new ->> 'id')::uuid from ctx)),
  null, 'and no GHN code');
select is(
  (select ship_location_model from public.shop_orders where id = (select (order_old ->> 'id')::uuid from ctx)),
  'ghn_legacy', 'an order to a GHN address is a legacy order');

-- ------------------------------------------------------------- shop settings
select tests.login(staff) from ctx;
set local role authenticated;
select is(
  public.save_shop_settings(jsonb_build_object('from_ward_location_code', 'vn_bbbbbbbbbbbbbbbbbbbb', 'from_street', '1 Kho'))
    ->> 'from_ward_location_code',
  'vn_bbbbbbbbbbbbbbbbbbbb', 'the sending ward is saved');
select throws_ok(
  $q$select public.save_shop_settings(jsonb_build_object('from_ward_location_code', 'vn_cccccccccccccccccccc'))$q$,
  '22023', null, 'a retired sending ward is refused');
select is(public.shop_public_settings() ->> 'from_ward_location_code', 'vn_bbbbbbbbbbbbbbbbbbbb', 'the public settings carry it');

-- --------------------------------------------------------------- constraints
reset role;
select throws_ok(
  $q$insert into public.customer_addresses (user_id, receiver_name, phone, street, province_name, ward_name, location_model)
     values ((select customer from ctx), 'X', '0901234567', 'x', 'P', 'W', 'vn_2025')$q$,
  '23514', null, 'a two-level address must name its ward');

select * from finish();
rollback;
