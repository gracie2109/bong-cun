-- Product groups with a category and a brand (docs/module-san-pham.md, step 1).
--
--  product_group_json now returns the category and brand names, and list_product_groups can
--  filter by category (a parent includes its sub-categories) and by brand. The new parameters have
--  defaults, so a caller that names its parameters keeps working. Safe to run more than once.

create or replace function public.product_group_json(p_group uuid, p_all boolean) returns jsonb
language sql
stable
set search_path = ''
as $$
  with variants as (
    select * from public.products where group_id = p_group and (p_all or is_active)
  )
  select jsonb_build_object(
    'id', g.id,
    'name', g.name,
    'description', g.description,
    'image_url', g.image_url,
    'is_active', g.is_active,
    'category_id', g.category_id,
    'category_name', (select c.name from public.product_categories c where c.id = g.category_id),
    'category_parent_name', (
      select par.name from public.product_categories c
      join public.product_categories par on par.id = c.parent_id
      where c.id = g.category_id
    ),
    'brand_id', g.brand_id,
    'brand_name', (select b.name from public.product_brands b where b.id = g.brand_id),
    'min_price', (select min(price) from variants),
    'max_price', (select max(price) from variants),
    'attributes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'name', a.name,
        'values', coalesce((
          select jsonb_agg(v.value order by v.sort_order, v.value)
          from public.product_attribute_values v
          where v.attribute_id = a.id
            and exists (
              select 1 from public.product_variant_values pv
              join variants p on p.id = pv.product_id
              where pv.value_id = v.id
            )
        ), '[]'::jsonb)
      ) order by ga.sort_order)
      from public.product_group_attributes ga
      join public.product_attributes a on a.id = ga.attribute_id
      where ga.group_id = g.id
    ), '[]'::jsonb),
    'variants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'options', coalesce((
          select jsonb_agg(v.value order by ga.sort_order)
          from public.product_group_attributes ga
          join public.product_variant_values pv on pv.attribute_id = ga.attribute_id and pv.product_id = p.id
          join public.product_attribute_values v on v.id = pv.value_id
          where ga.group_id = g.id
        ), '[]'::jsonb),
        'sku', p.sku,
        'barcode', p.barcode,
        'unit', p.unit,
        'price', p.price,
        'track_stock', p.track_stock,
        'is_active', p.is_active,
        'image_url', p.image_url
      ) order by p.sort_order, p.name)
      from variants p
    ), '[]'::jsonb)
  )
  from public.product_groups g
  where g.id = p_group;
$$;

revoke execute on function public.product_group_json(uuid, boolean) from public;
grant execute on function public.product_group_json(uuid, boolean) to anon, authenticated;

-- The old four-argument version would stay next to the new one and make calls ambiguous.
drop function if exists public.list_product_groups(text, boolean, int, int);

create or replace function public.list_product_groups(
  p_search           text default null,
  p_include_archived boolean default false,
  p_limit            int default 20,
  p_offset           int default 0,
  p_category         uuid default null,
  p_brand            uuid default null
) returns jsonb
language sql
stable
set search_path = ''
as $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term,
           nullif(btrim(coalesce(p_search, '')), '') as code
  ), matched as (
    select g.id, g.name
    from public.product_groups g, params
    where (p_include_archived or g.is_active)
      and (p_brand is null or g.brand_id = p_brand)
      and (
        p_category is null
        or g.category_id = p_category
        or g.category_id in (select id from public.product_categories where parent_id = p_category)
      )
      and (
        params.term is null
        or lower(public.immutable_unaccent(g.name)) like '%' || params.term || '%'
        or exists (
          select 1 from public.products p
          where p.group_id = g.id
            and (p.sku ilike '%' || params.code || '%' or p.barcode ilike '%' || params.code || '%')
        )
      )
  ), page as (
    select * from matched order by lower(name) limit greatest(p_limit, 1) offset greatest(p_offset, 0)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(public.product_group_json(page.id, p_include_archived) order by lower(page.name))
      from page
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.list_product_groups(text, boolean, int, int, uuid, uuid) from public;
grant execute on function public.list_product_groups(text, boolean, int, int, uuid, uuid) to anon, authenticated;

notify pgrst, 'reload schema';
