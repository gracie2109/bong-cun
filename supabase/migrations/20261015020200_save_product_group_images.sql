-- save_product_group with the image gallery (docs/module-san-pham.md, step 2).
--
--  The function of 20261015010400 plus p.images: [{ url, storage_path? }] in order, at most 8.
--  The list replaces the gallery (images left out are removed from it; the client deletes their
--  files), the first image becomes the group's cover, and a variant whose image is not in the list
--  goes back to the cover. Without "images" nothing about the gallery changes. Signature
--  unchanged. Safe to run more than once.

create or replace function public.save_product_group(p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group    uuid := nullif(p ->> 'id', '')::uuid;
  v_name     text := btrim(coalesce(p ->> 'name', ''));
  v_active   boolean := coalesce((p ->> 'is_active')::boolean, true);
  v_category uuid := nullif(p ->> 'category_id', '')::uuid;
  v_brand    uuid := nullif(p ->> 'brand_id', '')::uuid;
  -- Gallery: only when "images" is sent; the first one is the cover. A caller that leaves it out
  -- keeps the gallery and sends the cover in p.image_url as before.
  v_has_imgs boolean := jsonb_typeof(p -> 'images') = 'array';
  v_urls     text[] := '{}';
  v_cover    text;
  v_image    text;
  v_attrs    uuid[] := '{}';
  v_attr     uuid;
  v_value    uuid;
  v_text     text;
  v_a        jsonb;
  v_v        jsonb;
  v_idx      int;
  v_keep     uuid[] := '{}';
  v_variant  uuid;
  v_options  jsonb;
  v_values   uuid[];
  v_key      text;
  v_keys     text[] := '{}';
  v_sku      text;
  v_barcode  text;
  v_unit     text;
  v_price    numeric;
  v_sort     int := 0;
  r          record;
begin
  if not public.can_products(case when v_group is null then 'CREATE' else 'UPDATE' end) then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if v_name = '' then
    raise exception 'a product needs a name' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.product_groups
    where lower(btrim(name)) = lower(v_name) and id is distinct from v_group
  ) then
    raise exception 'product name % is taken', v_name using errcode = '23505', hint = 'duplicate_name';
  end if;
  if jsonb_array_length(coalesce(p -> 'variants', '[]'::jsonb)) = 0 then
    raise exception 'a product needs at least one variant' using errcode = '22023', hint = 'no_variants';
  end if;

  if v_has_imgs then
    select coalesce(array_agg(u order by first_ord), '{}') into v_urls
    from (
      select btrim(x ->> 'url') as u, min(ord) as first_ord
      from jsonb_array_elements(p -> 'images') with ordinality as t(x, ord)
      where nullif(btrim(x ->> 'url'), '') is not null
      group by btrim(x ->> 'url')
    ) d;
    if coalesce(array_length(v_urls, 1), 0) > 8 then
      raise exception 'a product has 8 images at most' using errcode = '22023', hint = 'too_many_images';
    end if;
    v_cover := v_urls[1];
  else
    v_cover := nullif(btrim(p ->> 'image_url'), '');
  end if;

  -- A switched-off category or brand cannot be chosen for a group that does not already use it.
  if v_category is not null and not exists (
    select 1 from public.product_categories c
    where c.id = v_category
      and (c.is_active or exists (select 1 from public.product_groups g where g.id = v_group and g.category_id = c.id))
  ) then
    raise exception 'category is not available' using errcode = '22023', hint = 'invalid_category';
  end if;
  if v_brand is not null and not exists (
    select 1 from public.product_brands b
    where b.id = v_brand
      and (b.is_active or exists (select 1 from public.product_groups g where g.id = v_group and g.brand_id = b.id))
  ) then
    raise exception 'brand is not available' using errcode = '22023', hint = 'invalid_brand';
  end if;

  if v_group is null then
    insert into public.product_groups (name, description, image_url, is_active, category_id, brand_id, created_by)
    values (v_name, nullif(btrim(p ->> 'description'), ''), v_cover,
            v_active, v_category, v_brand, (select auth.uid()))
    returning id into v_group;
  else
    update public.product_groups
    set name = v_name,
        description = nullif(btrim(p ->> 'description'), ''),
        image_url = v_cover,
        is_active = v_active,
        category_id = v_category,
        brand_id = v_brand
    where id = v_group;
    if not found then
      raise exception 'product % not found', v_group using errcode = 'P0002';
    end if;
  end if;

  if v_has_imgs then
    delete from public.product_images where group_id = v_group and not (url = any (v_urls));
    insert into public.product_images (group_id, url, storage_path, sort_order)
    select v_group, u.url, nullif(btrim(i.x ->> 'storage_path'), ''), (u.ord)::int
    from unnest(v_urls) with ordinality as u(url, ord)
    left join lateral (
      select x from jsonb_array_elements(p -> 'images') as t(x) where btrim(x ->> 'url') = u.url limit 1
    ) i on true
    on conflict (group_id, url) do update set sort_order = excluded.sort_order;
  end if;

  -- Attributes, in order; values are created on first use.
  for v_a in select * from jsonb_array_elements(coalesce(p -> 'attributes', '[]'::jsonb)) loop
    v_text := btrim(coalesce(v_a ->> 'name', ''));
    if v_text = '' then
      raise exception 'an attribute needs a name' using errcode = '22023';
    end if;
    select id into v_attr from public.product_attributes where lower(btrim(name)) = lower(v_text);
    if v_attr is null then
      insert into public.product_attributes (name) values (v_text) returning id into v_attr;
    end if;
    if v_attr = any (v_attrs) then
      raise exception 'attribute % is listed twice', v_text using errcode = '22023', hint = 'duplicate_attribute';
    end if;
    v_attrs := v_attrs || v_attr;

    for v_text in select btrim(x) from jsonb_array_elements_text(coalesce(v_a -> 'values', '[]'::jsonb)) as x loop
      continue when v_text = '';
      if not exists (
        select 1 from public.product_attribute_values
        where attribute_id = v_attr and lower(btrim(value)) = lower(v_text)
      ) then
        insert into public.product_attribute_values (attribute_id, value, sort_order)
        select v_attr, v_text, coalesce(max(sort_order), 0) + 1
        from public.product_attribute_values where attribute_id = v_attr;
      end if;
    end loop;
  end loop;

  delete from public.product_group_attributes where group_id = v_group;
  insert into public.product_group_attributes (group_id, attribute_id, sort_order)
  select v_group, a.id, a.ord::int
  from unnest(v_attrs) with ordinality as a(id, ord);

  -- Variants.
  for v_v in select * from jsonb_array_elements(p -> 'variants') loop
    v_sort := v_sort + 1;
    v_variant := nullif(v_v ->> 'id', '')::uuid;
    v_options := coalesce(v_v -> 'options', '[]'::jsonb);
    if jsonb_array_length(v_options) <> coalesce(array_length(v_attrs, 1), 0) then
      raise exception 'variant % needs one value per attribute', v_sort using errcode = '22023', hint = 'variant_options';
    end if;

    v_values := '{}';
    for v_idx in 1 .. coalesce(array_length(v_attrs, 1), 0) loop
      v_text := btrim(coalesce(v_options ->> (v_idx - 1), ''));
      select id into v_value from public.product_attribute_values
      where attribute_id = v_attrs[v_idx] and lower(btrim(value)) = lower(v_text);
      if v_value is null then
        raise exception 'variant %: value "%" is not one of the attribute values', v_sort, v_text
          using errcode = '22023', hint = 'variant_options';
      end if;
      v_values := v_values || v_value;
    end loop;
    v_key := coalesce(array_to_string(v_values, '|'), '');
    if v_key = any (v_keys) then
      raise exception 'two variants have the same values' using errcode = '23505', hint = 'duplicate_variant';
    end if;
    v_keys := v_keys || v_key;

    v_sku := nullif(btrim(v_v ->> 'sku'), '');
    v_barcode := nullif(btrim(v_v ->> 'barcode'), '');
    v_unit := coalesce(nullif(btrim(v_v ->> 'unit'), ''), 'cái');
    v_price := coalesce(nullif(v_v ->> 'price', '')::numeric, 0);
    -- A variant shows one of the group's images; anything else falls back to the cover.
    v_image := nullif(btrim(v_v ->> 'image_url'), '');
    if v_has_imgs and v_image is not null and not (v_image = any (v_urls)) then
      v_image := null;
    end if;
    if v_price < 0 then
      raise exception 'price must be zero or more' using errcode = '22023';
    end if;
    if v_sku is not null and exists (
      select 1 from public.products where sku = v_sku and id is distinct from v_variant
    ) then
      raise exception 'SKU % is taken', v_sku using errcode = '23505', hint = 'duplicate_sku', detail = v_sku;
    end if;
    if v_barcode is not null and exists (
      select 1 from public.products where barcode = v_barcode and id is distinct from v_variant
    ) then
      raise exception 'barcode % is taken', v_barcode using errcode = '23505', hint = 'duplicate_barcode', detail = v_barcode;
    end if;

    if v_variant is null then
      insert into public.products (
        name, group_id, option_key, sku, barcode, unit, price, track_stock, is_active, image_url, sort_order
      ) values (
        v_name, v_group, v_key, v_sku, v_barcode, v_unit, v_price,
        coalesce((v_v ->> 'track_stock')::boolean, true),
        v_active and coalesce((v_v ->> 'is_active')::boolean, true),
        v_image, v_sort
      )
      returning id into v_variant;
    else
      update public.products
      set option_key = v_key,
          sku = v_sku,
          barcode = v_barcode,
          unit = v_unit,
          price = v_price,
          track_stock = coalesce((v_v ->> 'track_stock')::boolean, true),
          is_active = v_active and coalesce((v_v ->> 'is_active')::boolean, true),
          image_url = v_image,
          sort_order = v_sort,
          updated_at = now()
      where id = v_variant and group_id = v_group;
      if not found then
        raise exception 'variant % does not belong to this product', v_variant using errcode = 'P0002';
      end if;
    end if;

    delete from public.product_variant_values where product_id = v_variant;
    insert into public.product_variant_values (product_id, attribute_id, value_id)
    select v_variant, a.id, v.id
    from unnest(v_attrs, v_values) as x(attr, val)
    join public.product_attributes a on a.id = x.attr
    join public.product_attribute_values v on v.id = x.val;

    v_keep := v_keep || v_variant;
  end loop;

  -- Variants removed from the list: delete when nothing uses them, else archive.
  for r in select id from public.products where group_id = v_group and not (id = any (v_keep)) loop
    begin
      delete from public.products where id = r.id;
    exception when foreign_key_violation then
      update public.products set is_active = false, updated_at = now() where id = r.id;
    end;
  end loop;

  perform public.refresh_variant_names(v_group);
  return v_group;
end;
$$;

revoke execute on function public.save_product_group(jsonb) from public, anon;
grant execute on function public.save_product_group(jsonb) to authenticated;

notify pgrst, 'reload schema';
