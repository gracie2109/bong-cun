-- product_group_json with the image gallery (docs/module-san-pham.md, step 2).
--
--  The function of 20261015010300 plus "images": the group's gallery in order, cover first.
--  Signature unchanged. Safe to run more than once.

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
    'images', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'url', i.url, 'storage_path', i.storage_path)
                       order by i.sort_order, i.created_at, i.id)
      from public.product_images i where i.group_id = g.id
    ), '[]'::jsonb),
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

notify pgrst, 'reload schema';
