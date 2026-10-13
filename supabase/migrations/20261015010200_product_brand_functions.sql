-- Product brands (docs/module-san-pham.md, step 1): save, delete and list.
-- Every function checks the "products" permission itself. Safe to run more than once.

-- p: { id?, name, image_url?, is_active? }; returns the id.
create or replace function public.save_product_brand(p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id    uuid := nullif(p ->> 'id', '')::uuid;
  v_name  text := btrim(coalesce(p ->> 'name', ''));
  v_old   public.product_brands;
  v_slug  text;
  v_base  text;
  v_n     int := 1;
begin
  if not public.can_products(case when v_id is null then 'CREATE' else 'UPDATE' end) then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if v_name = '' then
    raise exception 'a brand needs a name' using errcode = '22023', hint = 'name_required';
  end if;
  if exists (
    select 1 from public.product_brands
    where lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_name))
      and id is distinct from v_id
  ) then
    raise exception 'brand % already exists', v_name using errcode = '23505', hint = 'duplicate_name', detail = v_name;
  end if;

  if v_id is not null then
    select * into v_old from public.product_brands where id = v_id;
    if not found then
      raise exception 'brand % not found', v_id using errcode = 'P0002';
    end if;
  end if;

  if v_old.id is null or v_old.name is distinct from v_name then
    v_base := public.slugify(v_name);
    v_slug := v_base;
    while exists (select 1 from public.product_brands where slug = v_slug and id is distinct from v_id) loop
      v_n := v_n + 1;
      v_slug := v_base || '-' || v_n;
    end loop;
  else
    v_slug := v_old.slug;
  end if;

  if v_id is null then
    insert into public.product_brands (name, slug, image_url, is_active)
    values (v_name, v_slug, nullif(btrim(p ->> 'image_url'), ''), coalesce((p ->> 'is_active')::boolean, true))
    returning id into v_id;
  else
    update public.product_brands
    set name = v_name,
        slug = v_slug,
        image_url = nullif(btrim(p ->> 'image_url'), ''),
        is_active = coalesce((p ->> 'is_active')::boolean, is_active)
    where id = v_id;
  end if;
  return v_id;
end;
$$;

revoke execute on function public.save_product_brand(jsonb) from public, anon;
grant execute on function public.save_product_brand(jsonb) to authenticated;

-- A brand with products is only switched off, so this refuses it.
create or replace function public.delete_product_brand(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_products('DELETE') then
    raise exception 'not allowed to delete products' using errcode = '42501';
  end if;
  begin
    delete from public.product_brands where id = p_id;
  exception when foreign_key_violation then
    raise exception 'brand is in use' using errcode = '23503', hint = 'in_use';
  end;
  if not found then
    raise exception 'brand % not found', p_id using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.delete_product_brand(uuid) from public, anon;
grant execute on function public.delete_product_brand(uuid) to authenticated;

-- One page: { total, rows: [{ id, name, slug, image_url, is_active, product_count }] } by name.
-- Search matches the name (accents ignored).
create or replace function public.list_product_brands(
  p_search           text default null,
  p_include_inactive boolean default false,
  p_limit            int default 20,
  p_offset           int default 0
) returns jsonb
language sql
stable
set search_path = ''
as $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term
  ), matched as (
    select b.* from public.product_brands b, params
    where (p_include_inactive or b.is_active)
      and (params.term is null or lower(public.immutable_unaccent(b.name)) like '%' || params.term || '%')
  ), page as (
    select * from matched order by lower(name), id limit greatest(p_limit, 1) offset greatest(p_offset, 0)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', page.id,
        'name', page.name,
        'slug', page.slug,
        'image_url', page.image_url,
        'is_active', page.is_active,
        'product_count', (select count(*) from public.product_groups g where g.brand_id = page.id)
      ) order by lower(page.name), page.id)
      from page
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.list_product_brands(text, boolean, int, int) from public;
grant execute on function public.list_product_brands(text, boolean, int, int) to anon, authenticated;

notify pgrst, 'reload schema';
