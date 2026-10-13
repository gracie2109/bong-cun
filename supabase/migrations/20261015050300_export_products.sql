-- Product module, step 5 (4/4): export_products (docs/module-san-pham.md, 5.3).
-- One row per variant (inactive ones too) in the shape import_products reads, so an export can be
-- edited and imported back. Paged: { total, rows }. Needs the VIEW permission on products.

create or replace function public.export_products(p_limit int default 500, p_offset int default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rows  jsonb;
  v_total int;
begin
  if not public.can_products('VIEW') then
    raise exception 'not allowed to view products' using errcode = '42501';
  end if;
  select count(*) into v_total from public.products where group_id is not null;

  select coalesce(jsonb_agg(x.j order by x.n, x.gid, x.so, x.pid), '[]'::jsonb) into v_rows
  from (
    select
      lower(g.name) as n, g.id as gid, p.sort_order as so, p.id as pid,
      jsonb_build_object(
        'group', g.name,
        'category', (
          select case when c.parent_id is null then c.name
                      else (select pc.name from public.product_categories pc where pc.id = c.parent_id) || ' > ' || c.name end
          from public.product_categories c where c.id = g.category_id
        ),
        'brand', (select b.name from public.product_brands b where b.id = g.brand_id),
        'description', g.description,
        'images', coalesce((select jsonb_agg(i.url order by i.sort_order) from public.product_images i where i.group_id = g.id), '[]'::jsonb),
        'attrs', coalesce((
          select jsonb_agg(jsonb_build_object('name', a.name, 'value', v.value) order by ga.sort_order)
          from public.product_variant_values pv
          join public.product_attributes a on a.id = pv.attribute_id
          join public.product_attribute_values v on v.id = pv.value_id
          join public.product_group_attributes ga on ga.group_id = g.id and ga.attribute_id = a.id
          where pv.product_id = p.id
        ), '[]'::jsonb),
        'sku', p.sku,
        'barcode', p.barcode,
        'unit', p.unit,
        'price', p.price,
        'track_stock', p.track_stock,
        'is_active', p.is_active,
        'units', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', u.name, 'factor', u.factor, 'barcode', u.barcode, 'price', u.price,
            'for_sale', u.for_sale, 'for_purchase', u.for_purchase) order by u.factor)
          from public.product_units u where u.product_id = p.id and u.is_active
        ), '[]'::jsonb)
      ) as j
    from public.products p
    join public.product_groups g on g.id = p.group_id
    order by lower(g.name), g.id, p.sort_order, p.id
    limit greatest(p_limit, 0) offset greatest(p_offset, 0)
  ) x;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function public.export_products(int, int) from public, anon;
grant execute on function public.export_products(int, int) to authenticated;

notify pgrst, 'reload schema';
