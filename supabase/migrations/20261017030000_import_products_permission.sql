-- Data import/export, step 3 (docs/nhap-xuat-du-lieu.md, sections 4 and 6.1): import_products also
-- accepts the "products: IMPORT" method. The body is the one from 20261015050200_import_products.sql;
-- only the permission check changed (IMPORT, or CREATE and UPDATE as before, so existing roles keep
-- working). import_products_run is untouched. Safe to run more than once.

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
  if not (public.can_products('IMPORT') or (public.can_products('CREATE') and public.can_products('UPDATE'))) then
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

revoke execute on function public.import_products(jsonb, boolean, text) from public, anon;
grant execute on function public.import_products(jsonb, boolean, text) to authenticated;

notify pgrst, 'reload schema';
