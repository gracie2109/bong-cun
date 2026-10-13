-- Product module, step 5 (3/4): import_products (docs/module-san-pham.md, 5.3).
--
--  p_rows: [{ row, group, category, brand, description, images[], attrs[{name,value}], sku, barcode,
--  unit, price, track_stock, is_active, units[...] }], one element per variant, at most 500.
--  Rows of one group are saved together; a group whose rows have an error is not saved. With
--  p_dry_run (default) everything is checked and rolled back; the result says what would happen.
--  A real run writes only when every row is fine. Needs the CREATE and UPDATE permission on
--  products. Never deletes. Safe to run more than once.

create or replace function public.import_products(
  p_rows jsonb,
  p_dry_run boolean default true,
  p_file_name text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not (public.can_products('CREATE') and public.can_products('UPDATE')) then
    raise exception 'not allowed to import products' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'rows must be a list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 500 then
    raise exception 'at most 500 rows per call' using errcode = '22023', hint = 'too_many_rows';
  end if;

  if p_dry_run then
    begin
      v_result := public.import_products_run(p_rows);
      raise exception 'dry run' using errcode = 'P0099';
    exception when sqlstate 'P0099' then
      return v_result;
    end;
  end if;

  v_result := public.import_products_run(p_rows);
  if not (v_result ->> 'ok')::boolean then
    raise exception 'the file has errors' using errcode = '22023', hint = 'import_invalid';
  end if;
  insert into public.product_imports (file_name, row_count, created_count, updated_count, created_by)
  values (
    nullif(btrim(p_file_name), ''),
    jsonb_array_length(p_rows),
    (v_result ->> 'created_variants')::int,
    (v_result ->> 'updated_variants')::int,
    (select auth.uid())
  );
  return v_result;
end;
$$;

-- The work: group the rows, save each group, collect a note per row.
create or replace function public.import_products_run(p_rows jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_keys    text[] := '{}';
  v_key     text;
  v_row     jsonb;
  v_group   jsonb;
  v_one     jsonb;
  v_notes   jsonb := '{}'::jsonb;
  v_actions jsonb := '{}'::jsonb;
  v_n       text;
  v_item    record;
  v_msg     text;
  v_hint    text;
  v_detail  text;
  v_c_groups int := 0;
  v_u_groups int := 0;
  v_c_vars   int := 0;
  v_u_vars   int := 0;
  v_cats     jsonb := '[]'::jsonb;
  v_brands   jsonb := '[]'::jsonb;
  v_out     jsonb := '[]'::jsonb;
  v_ok      boolean;
begin
  -- first-appearance order of the groups
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_n := v_row ->> 'row';
    v_key := lower(btrim(coalesce(v_row ->> 'group', '')));
    if v_key = '' then
      v_notes := public.import_add_error(v_notes, v_n, 'Thiếu tên nhóm');
    elsif not (v_key = any (v_keys)) then
      v_keys := v_keys || v_key;
    end if;
  end loop;

  foreach v_key in array v_keys loop
    select jsonb_agg(r order by ord) into v_group
    from jsonb_array_elements(p_rows) with ordinality as t(r, ord)
    where lower(btrim(coalesce(r ->> 'group', ''))) = v_key;

    begin
      v_one := public.import_one_group(v_group);
      for v_item in select key, value from jsonb_each(v_one -> 'errors') loop
        for v_n in select jsonb_array_elements_text(v_item.value) loop
          v_notes := public.import_add_error(v_notes, v_item.key, v_n);
        end loop;
      end loop;
      if v_one -> 'errors' = '{}'::jsonb then
        v_actions := v_actions || (v_one -> 'actions');
        if (v_one ->> 'created_group')::boolean then v_c_groups := v_c_groups + 1; else v_u_groups := v_u_groups + 1; end if;
        v_c_vars := v_c_vars + (v_one ->> 'created_variants')::int;
        v_u_vars := v_u_vars + (v_one ->> 'updated_variants')::int;
        if v_one ->> 'new_category' is not null then v_cats := v_cats || to_jsonb(v_one ->> 'new_category'); end if;
        if v_one ->> 'new_brand' is not null then v_brands := v_brands || to_jsonb(v_one ->> 'new_brand'); end if;
      end if;
    exception when others then
      if sqlstate = '42501' then raise; end if;
      get stacked diagnostics v_msg = message_text, v_hint = pg_exception_hint, v_detail = pg_exception_detail;
      for v_n in select r ->> 'row' from jsonb_array_elements(v_group) as t(r) loop
        v_notes := public.import_add_error(v_notes, v_n, public.import_error_text(v_hint, v_msg, v_detail));
      end loop;
    end;
  end loop;

  v_ok := v_notes = '{}'::jsonb;
  select coalesce(jsonb_agg(jsonb_build_object(
    'row', r ->> 'row',
    'action', case when v_notes ? (r ->> 'row') then 'skip' else coalesce(v_actions ->> (r ->> 'row'), 'skip') end,
    'errors', coalesce(v_notes -> (r ->> 'row'), '[]'::jsonb)
  ) order by ord), '[]'::jsonb) into v_out
  from jsonb_array_elements(p_rows) with ordinality as t(r, ord);

  return jsonb_build_object(
    'ok', v_ok,
    'created_groups', v_c_groups,
    'updated_groups', v_u_groups,
    'created_variants', v_c_vars,
    'updated_variants', v_u_vars,
    'new_categories', v_cats,
    'new_brands', v_brands,
    'rows', v_out
  );
end;
$$;

revoke execute on function public.import_products_run(jsonb) from public, anon, authenticated;
revoke execute on function public.import_products(jsonb, boolean, text) from public, anon;
grant execute on function public.import_products(jsonb, boolean, text) to authenticated;

notify pgrst, 'reload schema';
