-- Product module, step 5 (1/4): helpers for the Excel import (docs/module-san-pham.md, 3.5 and 5.3).
-- A log of imports, plus internal functions that find or create a category / brand from a cell and
-- turn a database error into a short Vietnamese note on a row. Safe to run more than once.

create table if not exists public.product_imports (
  id            uuid primary key default gen_random_uuid(),
  file_name     text,
  row_count     int not null default 0,
  created_count int not null default 0,
  updated_count int not null default 0,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now()
);

alter table public.product_imports enable row level security;
drop policy if exists "products viewers read" on public.product_imports;
create policy "products viewers read" on public.product_imports
  for select to authenticated using ((select public.can_products('VIEW')));
revoke insert, update, delete on public.product_imports from anon, authenticated;
revoke select on public.product_imports from anon;

-- "Thức ăn > Hạt cho chó" -> the id of the last level, creating missing levels (two levels at
-- most). Blank path -> null. o_created says whether anything was created.
create or replace function public.import_resolve_category(p_path text, out o_id uuid, out o_created boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parts  text[];
  v_part   text;
  v_parent uuid;
  v_found  uuid;
begin
  o_created := false;
  select array_agg(btrim(x)) into v_parts
  from unnest(string_to_array(coalesce(p_path, ''), '>')) as x
  where btrim(x) <> '';
  if v_parts is null then
    return;
  end if;
  if array_length(v_parts, 1) > 2 then
    raise exception 'a category has two levels at most' using errcode = '22023', hint = 'category_depth';
  end if;
  foreach v_part in array v_parts loop
    v_found := null;
    select id into v_found from public.product_categories
    where parent_id is not distinct from v_parent
      and lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_part));
    if v_found is null then
      v_found := public.save_product_category(jsonb_build_object('name', v_part, 'parent_id', v_parent));
      o_created := true;
    end if;
    v_parent := v_found;
  end loop;
  o_id := v_parent;
end;
$$;

create or replace function public.import_resolve_brand(p_name text, out o_id uuid, out o_created boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
begin
  o_created := false;
  if v_name = '' then
    return;
  end if;
  select id into o_id from public.product_brands
  where lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_name));
  if o_id is null then
    o_id := public.save_product_brand(jsonb_build_object('name', v_name));
    o_created := true;
  end if;
end;
$$;

-- A short note for a row from the hint a save function raised.
create or replace function public.import_error_text(p_hint text, p_message text, p_detail text) returns text
language sql
immutable
set search_path = ''
as $$
  select case p_hint
    when 'duplicate_name'      then 'Tên nhóm đã có'
    when 'duplicate_sku'       then 'SKU đã được dùng: ' || coalesce(p_detail, '')
    when 'duplicate_barcode'   then 'Mã vạch đã được dùng: ' || coalesce(p_detail, '')
    when 'duplicate_variant'   then 'Hai biến thể có cùng giá trị thuộc tính'
    when 'duplicate_attribute' then 'Một thuộc tính bị lặp'
    when 'variant_options'     then 'Giá trị thuộc tính không hợp lệ'
    when 'invalid_category'    then 'Danh mục đang tắt'
    when 'invalid_brand'       then 'Thương hiệu đang tắt'
    when 'too_many_images'     then 'Tối đa 8 ảnh mỗi nhóm'
    when 'category_depth'      then 'Danh mục tối đa 2 cấp'
    when 'duplicate_unit'      then 'Tên đơn vị bị trùng: ' || coalesce(p_detail, '')
    when 'unit_factor'         then 'Hệ số đơn vị phải lớn hơn 1: ' || coalesce(p_detail, '')
    when 'unit_in_use'         then 'Đơn vị đã dùng nên không đổi hệ số: ' || coalesce(p_detail, '')
    when 'unit_name_required'  then 'Đơn vị cần có tên'
    else coalesce(p_message, 'Lỗi không rõ')
  end;
$$;

revoke execute on function public.import_resolve_category(text) from public, anon, authenticated;
revoke execute on function public.import_resolve_brand(text) from public, anon, authenticated;
revoke execute on function public.import_error_text(text, text, text) from public, anon, authenticated;

notify pgrst, 'reload schema';
