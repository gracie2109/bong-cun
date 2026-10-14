-- Data import/export, step 6: find_products_by_sku (docs/nhap-xuat-du-lieu.md, 6.4). Safe to run more than once.
--
-- Read only. For the stock receipt filled from a file: the active products behind a list of SKUs
-- (compared ignoring case and spaces at the ends), with their base unit and the units goods can be
-- bought in. A SKU nobody has simply does not come back. At most 2000 SKUs. Needs "inventory: CREATE".

create or replace function public.find_products_by_sku(p_skus text[])
returns table (sku text, product_id uuid, name text, unit text, track_stock boolean, units jsonb)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_inventory('CREATE') then
    raise exception 'not allowed to receive stock' using errcode = '42501';
  end if;
  if coalesce(array_length(p_skus, 1), 0) > 2000 then
    raise exception 'at most 2000 SKUs per call' using errcode = '22023', hint = 'too_many_rows';
  end if;

  return query
  select p.sku,
         p.id,
         p.name,
         p.unit,
         p.track_stock,
         coalesce((
           select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.name, 'factor', u.factor, 'for_purchase', u.for_purchase)
                            order by u.sort_order, u.factor)
           from public.product_units u
           where u.product_id = p.id and u.is_active
         ), '[]'::jsonb)
  from public.products p
  where p.is_active
    and p.sku is not null
    and lower(btrim(p.sku)) in (select lower(btrim(x)) from unnest(p_skus) as x);
end;
$$;

revoke execute on function public.find_products_by_sku(text[]) from public, anon;
grant execute on function public.find_products_by_sku(text[]) to authenticated;

notify pgrst, 'reload schema';
