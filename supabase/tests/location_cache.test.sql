-- The location cache: read-only tables, and the RPCs the address pickers read.
-- The units below are made-up fixtures for this test only, not real administrative data.
begin;
\ir _helpers/setup.psql
select plan(20);

select has_table('public', 'location_catalogs', 'catalog table exists');
select has_table('public', 'location_units', 'units table exists');
select has_table('public', 'location_provider_codes', 'provider codes table exists');

-- Empty cache: no current catalog.
select is(public.location_catalog(), null::jsonb, 'no catalog before the first sync');

insert into public.location_catalogs (id, source, effective_on, is_current, record_counts)
values ('test-catalog', 'test fixture', '2025-07-01', true, '{"provinces": 2}');

insert into public.location_units (code, level, unit_type, official_code, name, full_name, parent_code, status, effective_from, catalog_id)
values
  ('vn_aaaaaaaaaaaaaaaaaaaa', 'province', 'municipality', '79', 'Hồ Chí Minh', 'Thành phố Hồ Chí Minh', null, 'active', '2025-07-01', 'test-catalog'),
  ('vn_eeeeeeeeeeeeeeeeeeee', 'province', 'province', '99', 'Tỉnh Thử', 'Tỉnh Thử', null, 'retired', '2025-07-01', 'test-catalog'),
  ('vn_bbbbbbbbbbbbbbbbbbbb', 'commune', 'ward', '26740', 'Bến Thành', 'Phường Bến Thành', 'vn_aaaaaaaaaaaaaaaaaaaa', 'active', '2025-07-01', 'test-catalog'),
  ('vn_cccccccccccccccccccc', 'commune', 'ward', '26741', 'Đa Kao', 'Phường Đa Kao', 'vn_aaaaaaaaaaaaaaaaaaaa', 'retired', '2025-07-01', 'test-catalog'),
  ('vn_dddddddddddddddddddd', 'commune', 'ward', '26742', 'Bến Nghé', 'Phường Bến Nghé', 'vn_aaaaaaaaaaaaaaaaaaaa', 'active', '2025-07-01', 'test-catalog');

-- A plain customer, the same as any signed-in reader.
create temp table ctx as select tests.create_user('loc-reader@test.local') as reader;
grant select on ctx to authenticated;
select tests.login(reader) from ctx;
set local role authenticated;

select throws_ok('select * from public.location_units', '42501', null, 'the units table cannot be read directly');
select throws_ok('select * from public.location_provider_codes', '42501', null, 'the provider codes cannot be read directly');

select is(jsonb_array_length(public.location_provinces()), 1, 'provinces: only the active one');
select is(
  (public.location_communes('vn_aaaaaaaaaaaaaaaaaaaa') ->> 'total')::int, 2, 'communes: the active ones of the province'
);
select is(
  public.location_communes('vn_aaaaaaaaaaaaaaaaaaaa', 'ben thanh') -> 'items' -> 0 ->> 'full_name',
  'Phường Bến Thành', 'search without accents'
);
select is(
  public.location_communes('vn_aaaaaaaaaaaaaaaaaaaa', 'BẾN THÀNH') -> 'items' -> 0 ->> 'full_name',
  'Phường Bến Thành', 'search with accents and capitals'
);
select is(
  public.location_communes('vn_aaaaaaaaaaaaaaaaaaaa', 'phuong ben thanh') -> 'items' -> 0 ->> 'full_name',
  'Phường Bến Thành', 'search with the type word'
);
select is(
  jsonb_array_length(public.location_communes('vn_aaaaaaaaaaaaaaaaaaaa', null, 2, 1) -> 'items'), 1, 'paging'
);
select throws_ok(
  $q$select public.location_communes('vn_aaaaaaaaaaaaaaaaaaaa', null, 1, 501)$q$, '22023', null, 'page size over 500'
);
select throws_ok(
  $q$select public.location_communes('vn_bbbbbbbbbbbbbbbbbbbb')$q$, '22023', null, 'a commune is not a province'
);

select is(public.location_unit('vn_cccccccccccccccccccc') ->> 'status', 'retired', 'a retired unit can still be read');
select is(public.location_unit('vn_bbbbbbbbbbbbbbbbbbbb') -> 'province' ->> 'full_name', 'Thành phố Hồ Chí Minh', 'unit carries its province');
select throws_ok($q$select public.location_unit('vn_zzzzzzzzzzzzzzzzzzzz')$q$, 'P0002', null, 'unknown code');

select is(
  public.location_search('ben') -> 'items' -> 0 ->> 'code', 'vn_dddddddddddddddddddd',
  'search across provinces lists active communes only, same rank by name'
);
select throws_ok($q$select public.location_search('b')$q$, '22023', null, 'search text of one character');
select is(public.location_catalog() ->> 'id', 'test-catalog', 'the current catalog');

select * from finish();
rollback;
