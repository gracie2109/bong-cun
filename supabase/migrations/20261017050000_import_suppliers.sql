-- Data import/export, step 5: import_suppliers (docs/nhap-xuat-du-lieu.md, 6.3). Safe to run more than once.
--
--  p_rows: [{ row, name, phone, email, address, tax_code, note, is_active (bool|null) }], at most 500.
--  A supplier is found by tax_code when the row has one, else by name (ignoring case and spaces at
--  the ends); a name shared by several suppliers is an error, use the tax code. An empty cell never
--  clears a value. With p_dry_run (default) everything is checked and rolled back; a real run writes
--  only when every row is fine. Needs the "inventory: IMPORT" method. Never deletes.

create or replace function public.import_suppliers(p_rows jsonb, p_dry_run boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not (coalesce((select public.is_admin()), false) or coalesce((select public.has_permission('inventory', 'IMPORT')), false)) then
    raise exception 'not allowed to import suppliers' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'rows must be a list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 500 then
    raise exception 'at most 500 rows per call' using errcode = '22023', hint = 'too_many_rows';
  end if;

  if p_dry_run then
    begin
      v_result := public.import_suppliers_run(p_rows);
      raise exception 'dry run' using errcode = 'P0099';
    exception when sqlstate 'P0099' then
      return v_result;
    end;
  end if;

  v_result := public.import_suppliers_run(p_rows);
  if not (v_result ->> 'ok')::boolean then
    raise exception 'the file has errors' using errcode = '22023', hint = 'import_invalid';
  end if;
  return v_result;
end;
$$;

-- The work for one row; returns 'create' or 'update', or raises.
create or replace function public.import_suppliers_row(p_row jsonb) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name    text := nullif(btrim(coalesce(p_row ->> 'name', '')), '');
  v_phone   text := nullif(btrim(coalesce(p_row ->> 'phone', '')), '');
  v_email   text := nullif(btrim(coalesce(p_row ->> 'email', '')), '');
  v_address text := nullif(btrim(coalesce(p_row ->> 'address', '')), '');
  v_tax     text := nullif(btrim(coalesce(p_row ->> 'tax_code', '')), '');
  v_note    text := nullif(btrim(coalesce(p_row ->> 'note', '')), '');
  v_active  boolean := case when p_row ->> 'is_active' is null then null else (p_row ->> 'is_active')::boolean end;
  v_ids     uuid[];
begin
  if v_name is null then
    raise exception 'Thiếu tên nhà cung cấp' using errcode = '22023';
  end if;

  if v_tax is not null then
    select array_agg(id order by created_at) into v_ids
    from public.suppliers where lower(btrim(tax_code)) = lower(v_tax);
  else
    select array_agg(id order by created_at) into v_ids
    from public.suppliers where lower(btrim(name)) = lower(v_name);
  end if;

  if coalesce(array_length(v_ids, 1), 0) > 1 then
    raise exception 'Có nhiều nhà cung cấp trùng, hãy kiểm tra lại mã số thuế hoặc tên' using errcode = '22023';
  end if;

  if v_ids is null then
    insert into public.suppliers (name, phone, email, address, tax_code, note, is_active)
    values (v_name, v_phone, v_email, v_address, v_tax, v_note, coalesce(v_active, true));
    return 'create';
  end if;

  update public.suppliers
  set name      = v_name,
      phone     = coalesce(v_phone, phone),
      email     = coalesce(v_email, email),
      address   = coalesce(v_address, address),
      tax_code  = coalesce(v_tax, tax_code),
      note      = coalesce(v_note, note),
      is_active = coalesce(v_active, is_active)
  where id = v_ids[1];
  return 'update';
end;
$$;

-- Runs every row in its own sub-transaction so a bad row leaves no trace, and collects the answer.
create or replace function public.import_suppliers_run(p_rows jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item    record;
  v_action  text;
  v_out     jsonb := '[]'::jsonb;
  v_ok      boolean := true;
  v_created int := 0;
  v_updated int := 0;
  v_msg     text;
begin
  for v_item in select r, ord from jsonb_array_elements(p_rows) with ordinality as t(r, ord) order by ord loop
    begin
      v_action := public.import_suppliers_row(v_item.r);
      if v_action = 'create' then v_created := v_created + 1; else v_updated := v_updated + 1; end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('row', v_item.r ->> 'row', 'action', v_action, 'errors', '[]'::jsonb));
    exception when others then
      get stacked diagnostics v_msg = message_text;
      v_ok := false;
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'row', v_item.r ->> 'row',
        'action', 'skip',
        'errors', jsonb_build_array(case sqlstate when '22P02' then 'Có ô không đúng định dạng' else v_msg end)
      ));
    end;
  end loop;

  return jsonb_build_object('ok', v_ok, 'created', v_created, 'updated', v_updated, 'rows', v_out);
end;
$$;

revoke execute on function public.import_suppliers_row(jsonb) from public, anon, authenticated;
revoke execute on function public.import_suppliers_run(jsonb) from public, anon, authenticated;
revoke execute on function public.import_suppliers(jsonb, boolean) from public, anon;
grant execute on function public.import_suppliers(jsonb, boolean) to authenticated;

notify pgrst, 'reload schema';
