-- Product module, step 5 (2/4): the import of one product group (docs/module-san-pham.md, 5.3).
-- Takes every file row of one group, checks them, and builds the JSON save_product_group takes:
-- the group's current variants (and units) are kept as they are unless a row names their SKU, so an
-- import never removes anything. Returns { errors, actions, ... } and saves nothing when a row is
-- wrong. Internal: called by import_products_run. Safe to run more than once.

create or replace function public.import_one_group(p_rows jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name      text := btrim(coalesce(p_rows -> 0 ->> 'group', ''));
  v_errs      jsonb := '{}'::jsonb;
  v_acts      jsonb := '{}'::jsonb;
  v_row       jsonb;
  v_n         text;
  v_sku       text;
  v_skus      text[] := '{}';
  v_barcodes  text[] := '{}';
  v_text      text;
  v_num       numeric;
  v_other     uuid;
  v_gid       uuid;
  v_g         jsonb;
  v_names     text[] := '{}';
  v_row_names text[];
  v_a         jsonb;
  v_i         int;
  v_values    jsonb[];
  v_attrs     jsonb := '[]'::jsonb;
  v_value     text;
  v_variants  jsonb := '[]'::jsonb;
  v_options   jsonb;
  v_ev        jsonb;
  v_match     jsonb;
  v_built     jsonb;
  v_units     jsonb;
  v_unit      jsonb;
  v_old_unit  jsonb;
  v_desc      text;
  v_images    jsonb;
  v_category  record;
  v_brand     record;
  v_cat_id    uuid;
  v_brand_id  uuid;
  v_payload   jsonb;
  v_created   int := 0;
  v_updated   int := 0;
begin
  -- ---------------------------------------------------------------- each row on its own
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_n := v_row ->> 'row';
    v_sku := nullif(btrim(coalesce(v_row ->> 'sku', '')), '');
    if v_sku is null then
      v_errs := public.import_add_error(v_errs, v_n, 'Thiếu SKU');
    elsif v_sku = any (v_skus) then
      v_errs := public.import_add_error(v_errs, v_n, 'SKU lặp lại trong file: ' || v_sku);
    else
      v_skus := v_skus || v_sku;
    end if;

    v_text := nullif(btrim(coalesce(v_row ->> 'barcode', '')), '');
    if v_text is not null then
      if v_text = any (v_barcodes) then
        v_errs := public.import_add_error(v_errs, v_n, 'Mã vạch lặp lại trong file: ' || v_text);
      end if;
      v_barcodes := v_barcodes || v_text;
    end if;

    begin
      v_num := nullif(btrim(coalesce(v_row ->> 'price', '')), '')::numeric;
    exception when others then
      v_num := -1;
    end;
    if v_num is null then
      v_errs := public.import_add_error(v_errs, v_n, 'Thiếu giá');
    elsif v_num < 0 then
      v_errs := public.import_add_error(v_errs, v_n, 'Giá không hợp lệ');
    end if;

    if jsonb_typeof(v_row -> 'attrs') = 'array' then
      if jsonb_array_length(v_row -> 'attrs') > 3 then
        v_errs := public.import_add_error(v_errs, v_n, 'Tối đa 3 thuộc tính');
      end if;
      for v_a in select * from jsonb_array_elements(v_row -> 'attrs') loop
        if btrim(coalesce(v_a ->> 'name', '')) = '' or btrim(coalesce(v_a ->> 'value', '')) = '' then
          v_errs := public.import_add_error(v_errs, v_n, 'Mỗi thuộc tính cần cả tên và giá trị');
        end if;
      end loop;
    end if;

    if jsonb_typeof(v_row -> 'units') = 'array' then
      for v_unit in select * from jsonb_array_elements(v_row -> 'units') loop
        begin
          v_num := nullif(btrim(coalesce(v_unit ->> 'factor', '')), '')::numeric;
        exception when others then
          v_num := null;
        end;
        if btrim(coalesce(v_unit ->> 'name', '')) = '' then
          v_errs := public.import_add_error(v_errs, v_n, 'Đơn vị quy đổi cần có tên');
        elsif v_num is null or v_num <= 1 then
          v_errs := public.import_add_error(v_errs, v_n, 'Hệ số đơn vị "' || (v_unit ->> 'name') || '" phải lớn hơn 1');
        end if;
      end loop;
    end if;
  end loop;

  -- ------------------------------------------------------------ the group and its SKUs
  select id into v_gid from public.product_groups where lower(btrim(name)) = lower(v_name);
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_sku := nullif(btrim(coalesce(v_row ->> 'sku', '')), '');
    continue when v_sku is null;
    select group_id into v_other from public.products where sku = v_sku;
    if found and v_other is distinct from v_gid then
      v_errs := public.import_add_error(
        v_errs, v_row ->> 'row',
        'SKU ' || v_sku || ' đã thuộc nhóm "' || (select name from public.product_groups where id = v_other) || '"'
      );
    end if;
  end loop;

  -- ------------------------------------------------------------------- attributes
  if v_gid is not null then
    v_g := public.product_group_json(v_gid, true);
    select coalesce(array_agg(a ->> 'name' order by ord), '{}') into v_names
    from jsonb_array_elements(v_g -> 'attributes') with ordinality as t(a, ord);
  else
    select coalesce(array_agg(a ->> 'name' order by ord), '{}') into v_names
    from jsonb_array_elements(coalesce(p_rows -> 0 -> 'attrs', '[]'::jsonb)) with ordinality as t(a, ord);
  end if;

  for v_row in select * from jsonb_array_elements(p_rows) loop
    select coalesce(array_agg(lower(btrim(a ->> 'name')) order by lower(btrim(a ->> 'name'))), '{}') into v_row_names
    from jsonb_array_elements(coalesce(v_row -> 'attrs', '[]'::jsonb)) as t(a);
    if v_row_names is distinct from (select coalesce(array_agg(lower(btrim(x)) order by lower(btrim(x))), '{}') from unnest(v_names) as x) then
      v_errs := public.import_add_error(
        v_errs, v_row ->> 'row',
        'Thuộc tính không khớp với nhóm' || case when array_length(v_names, 1) > 0 then ': ' || array_to_string(v_names, ', ') else ' (nhóm không có thuộc tính)' end
      );
    end if;
  end loop;

  if v_errs <> '{}'::jsonb then
    return jsonb_build_object('errors', v_errs, 'actions', v_acts);
  end if;

  -- Values of each attribute: the group's own first, then the new ones from the file.
  for v_i in 1 .. coalesce(array_length(v_names, 1), 0) loop
    v_values := '{}';
    if v_gid is not null then
      select coalesce(array_agg(to_jsonb(x) order by ord), '{}') into v_values
      from jsonb_array_elements_text(v_g -> 'attributes' -> (v_i - 1) -> 'values') with ordinality as t(x, ord);
    end if;
    for v_row in select * from jsonb_array_elements(p_rows) loop
      select btrim(a ->> 'value') into v_value
      from jsonb_array_elements(v_row -> 'attrs') as t(a)
      where lower(btrim(a ->> 'name')) = lower(btrim(v_names[v_i])) limit 1;
      if not exists (select 1 from unnest(v_values) as e where lower(e #>> '{}') = lower(v_value)) then
        v_values := v_values || to_jsonb(v_value);
      end if;
    end loop;
    v_attrs := v_attrs || jsonb_build_object('name', v_names[v_i], 'values', to_jsonb(v_values));
  end loop;

  -- ----------------------------------------------------------------------- variants
  -- Existing variants first (kept as they are unless a row names their SKU), then new ones.
  if v_gid is not null then
    for v_ev in select * from jsonb_array_elements(v_g -> 'variants') loop
      v_match := null;
      select r into v_match from jsonb_array_elements(p_rows) as t(r) where btrim(r ->> 'sku') = (v_ev ->> 'sku') limit 1;
      if v_match is null then
        v_variants := v_variants || jsonb_build_object(
          'id', v_ev -> 'id', 'options', v_ev -> 'options', 'sku', v_ev -> 'sku', 'barcode', v_ev -> 'barcode',
          'unit', v_ev -> 'unit', 'price', v_ev -> 'price', 'track_stock', v_ev -> 'track_stock',
          'is_active', v_ev -> 'is_active', 'image_url', v_ev -> 'image_url'
        );
      end if;
    end loop;
  end if;

  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_sku := btrim(v_row ->> 'sku');
    v_ev := null;
    if v_gid is not null then
      select e into v_ev from jsonb_array_elements(v_g -> 'variants') as t(e) where e ->> 'sku' = v_sku limit 1;
    end if;

    v_options := '[]'::jsonb;
    for v_i in 1 .. coalesce(array_length(v_names, 1), 0) loop
      select btrim(a ->> 'value') into v_value
      from jsonb_array_elements(v_row -> 'attrs') as t(a)
      where lower(btrim(a ->> 'name')) = lower(btrim(v_names[v_i])) limit 1;
      -- the stored spelling of a value that differs only in case
      v_options := v_options || to_jsonb(coalesce(
        (select x from jsonb_array_elements_text(v_attrs -> (v_i - 1) -> 'values') as t(x) where lower(x) = lower(v_value) limit 1),
        v_value
      ));
    end loop;

    v_built := jsonb_build_object(
      'id', v_ev -> 'id',
      'options', v_options,
      'sku', v_sku,
      'barcode', nullif(btrim(coalesce(v_row ->> 'barcode', '')), ''),
      'unit', coalesce(nullif(btrim(coalesce(v_row ->> 'unit', '')), ''), v_ev ->> 'unit', 'cái'),
      'price', (v_row ->> 'price')::numeric,
      'track_stock', coalesce((v_row ->> 'track_stock')::boolean, (v_ev ->> 'track_stock')::boolean, true),
      'is_active', coalesce((v_row ->> 'is_active')::boolean, true),
      'image_url', v_ev -> 'image_url'
    );

    -- Units named in the file replace the ones with the same name; the others stay.
    if jsonb_typeof(v_row -> 'units') = 'array' then
      v_units := coalesce((
        select jsonb_agg(u) from jsonb_array_elements(coalesce(v_ev -> 'units', '[]'::jsonb)) as t(u)
        where not exists (
          select 1 from jsonb_array_elements(v_row -> 'units') as f(x)
          where lower(btrim(x ->> 'name')) = lower(u ->> 'name')
        )
      ), '[]'::jsonb);
      for v_unit in select * from jsonb_array_elements(v_row -> 'units') loop
        select u into v_old_unit from jsonb_array_elements(coalesce(v_ev -> 'units', '[]'::jsonb)) as t(u)
        where lower(u ->> 'name') = lower(btrim(v_unit ->> 'name')) limit 1;
        v_units := v_units || jsonb_build_object(
          'id', v_old_unit -> 'id',
          'name', btrim(v_unit ->> 'name'),
          'factor', (v_unit ->> 'factor')::numeric,
          'barcode', nullif(btrim(coalesce(v_unit ->> 'barcode', '')), ''),
          'price', nullif(btrim(coalesce(v_unit ->> 'price', '')), '')::numeric,
          'for_sale', coalesce((v_unit ->> 'for_sale')::boolean, true),
          'for_purchase', coalesce((v_unit ->> 'for_purchase')::boolean, false),
          'is_active', coalesce((v_unit ->> 'is_active')::boolean, true)
        );
      end loop;
      v_built := v_built || jsonb_build_object('units', v_units);
    end if;

    v_variants := v_variants || v_built;
    if v_ev is null then
      v_created := v_created + 1;
      v_acts := jsonb_set(v_acts, array[v_row ->> 'row'], '"create"');
    else
      v_updated := v_updated + 1;
      v_acts := jsonb_set(v_acts, array[v_row ->> 'row'], '"update"');
    end if;
  end loop;

  -- ------------------------------------------------------------------- the group
  select r ->> 'description' into v_desc
  from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'description', '')), '') is not null limit 1;

  select r -> 'images' into v_images
  from jsonb_array_elements(p_rows) as t(r)
  where jsonb_typeof(r -> 'images') = 'array' and jsonb_array_length(r -> 'images') > 0 limit 1;
  if v_images is not null then
    -- keep the storage path of a picture the group already has
    select jsonb_agg(jsonb_build_object(
      'url', btrim(x),
      'storage_path', (select i ->> 'storage_path' from jsonb_array_elements(coalesce(v_g -> 'images', '[]'::jsonb)) as e(i) where i ->> 'url' = btrim(x) limit 1)
    ) order by ord) into v_images
    from jsonb_array_elements_text(v_images) with ordinality as t(x, ord)
    where btrim(x) <> '';
  end if;

  select * into v_category from public.import_resolve_category(
    (select r ->> 'category' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'category', '')), '') is not null limit 1)
  );
  select * into v_brand from public.import_resolve_brand(
    (select r ->> 'brand' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'brand', '')), '') is not null limit 1)
  );
  v_cat_id := coalesce(v_category.o_id, (v_g ->> 'category_id')::uuid);
  v_brand_id := coalesce(v_brand.o_id, (v_g ->> 'brand_id')::uuid);

  v_payload := jsonb_build_object(
    'id', v_gid,
    'name', coalesce(v_g ->> 'name', v_name),
    'description', coalesce(v_desc, v_g ->> 'description'),
    'image_url', v_g ->> 'image_url',
    'is_active', coalesce((v_g ->> 'is_active')::boolean, true),
    'category_id', v_cat_id,
    'brand_id', v_brand_id,
    'attributes', v_attrs,
    'variants', v_variants
  );
  if v_images is not null then
    v_payload := v_payload || jsonb_build_object('images', v_images);
  end if;

  perform public.save_product_group(v_payload);

  return jsonb_build_object(
    'errors', v_errs,
    'actions', v_acts,
    'created_group', v_gid is null,
    'created_variants', v_created,
    'updated_variants', v_updated,
    'new_category', case when v_category.o_created then (select r ->> 'category' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'category', '')), '') is not null limit 1) end,
    'new_brand', case when v_brand.o_created then (select r ->> 'brand' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'brand', '')), '') is not null limit 1) end
  );
end;
$$;

revoke execute on function public.import_one_group(jsonb) from public, anon, authenticated;

-- Adds one note to a row's list of errors in { "<row>": [notes] }.
create or replace function public.import_add_error(p_errors jsonb, p_row text, p_note text) returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_set(
    coalesce(p_errors, '{}'::jsonb),
    array[p_row],
    coalesce(p_errors -> p_row, '[]'::jsonb) || to_jsonb(p_note)
  );
$$;

revoke execute on function public.import_add_error(jsonb, text, text) from public, anon, authenticated;

notify pgrst, 'reload schema';
