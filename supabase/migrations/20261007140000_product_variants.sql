-- Product variants (docs: Claude Doc "Kế hoạch biến thể sản phẩm").
--
--  A product group is what the customer sees ("Hạt Royal Canin Mini Adult"); each variant is one
--  row of public.products, i.e. one SKU with its own barcode, price, unit, stock and image. POS,
--  invoices, stock lots and returns keep pointing at products(id), so they work unchanged.
--
--  Attributes are shared across groups (Kích cỡ, Vị, Màu...) and a group can vary by any number
--  of them. A variant holds one value per attribute of its group; one combination = one SKU.
--  products.name is kept as "<group> · <value> / <value>" so every screen that prints a product
--  name shows the variant without changes.
--
--  Every existing product becomes a group with a single variant. Writes go through
--  save_product_group / set_product_group_active ("products" permission). Safe to run more than once.

-- ---------------------------------------------------------------- attributes
create table if not exists public.product_attributes (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(btrim(name)) > 0),
  created_at timestamptz not null default now()
);
create unique index if not exists product_attributes_name_key
  on public.product_attributes (lower(btrim(name)));

create table if not exists public.product_attribute_values (
  id           uuid primary key default gen_random_uuid(),
  attribute_id uuid not null references public.product_attributes(id) on delete cascade,
  value        text not null check (length(btrim(value)) > 0),
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create unique index if not exists product_attribute_values_key
  on public.product_attribute_values (attribute_id, lower(btrim(value)));

-- -------------------------------------------------------------------- groups
create table if not exists public.product_groups (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (length(btrim(name)) > 0),
  description text,
  image_url   text,
  is_active   boolean not null default true,
  created_by  uuid references auth.users(id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create unique index if not exists product_groups_name_key on public.product_groups (lower(btrim(name)));

-- The attributes a group varies by, in display order.
create table if not exists public.product_group_attributes (
  group_id     uuid not null references public.product_groups(id) on delete cascade,
  attribute_id uuid not null references public.product_attributes(id) on delete restrict,
  sort_order   int not null default 0,
  primary key (group_id, attribute_id)
);
create index if not exists product_group_attributes_attribute_idx on public.product_group_attributes (attribute_id);

-- ------------------------------------------------------------------ variants
alter table public.products
  add column if not exists group_id   uuid references public.product_groups(id) on delete restrict,
  add column if not exists image_url  text,
  add column if not exists sort_order int not null default 0,
  -- The variant's value ids in the group's attribute order; '' for a group without attributes.
  add column if not exists option_key text not null default '';

create table if not exists public.product_variant_values (
  product_id   uuid not null references public.products(id) on delete cascade,
  attribute_id uuid not null references public.product_attributes(id) on delete restrict,
  value_id     uuid not null references public.product_attribute_values(id) on delete restrict,
  primary key (product_id, attribute_id)
);
create index if not exists product_variant_values_value_idx on public.product_variant_values (value_id);

-- Every product without a group becomes a group of one.
do $$
declare
  r record;
  v_group uuid;
begin
  for r in select * from public.products where group_id is null loop
    select id into v_group from public.product_groups where lower(btrim(name)) = lower(btrim(r.name));
    if v_group is null then
      insert into public.product_groups (name, description, is_active, created_at)
      values (r.name, r.description, r.is_active, r.created_at)
      returning id into v_group;
    end if;
    update public.products set group_id = v_group where id = r.id;
  end loop;
end;
$$;

alter table public.products alter column group_id set not null;
create index if not exists products_group_idx on public.products (group_id, sort_order);

-- Names are now derived from the group; two groups may legitimately end in the same text.
alter table public.products drop constraint if exists products_name_key;

-- One SKU per combination. Deferred so a save can swap two variants' values.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'products_group_option_key') then
    alter table public.products add constraint products_group_option_key
      unique (group_id, option_key) deferrable initially deferred;
  end if;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['product_groups'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ----------------------------------------------------------------------- RLS
-- The catalog is public (the shop reads it); writes go through the functions below.
do $$
declare t text;
begin
  foreach t in array array['product_attributes', 'product_attribute_values', 'product_groups',
                           'product_group_attributes', 'product_variant_values'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "public read" on public.%I', t);
    execute format('create policy "public read" on public.%I for select to anon, authenticated using (true)', t);
    execute format('revoke insert, update, delete on public.%I from anon, authenticated', t);
  end loop;
end;
$$;

create or replace function public.can_products(p_method text) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or coalesce((select public.has_permission('products', p_method)), false);
$$;

revoke execute on function public.can_products(text) from public, anon;
grant execute on function public.can_products(text) to authenticated;

-- "<group> · <value> / <value>" for every variant of a group, archived ones included.
create or replace function public.refresh_variant_names(p_group uuid) returns void
language sql
security definer
set search_path = ''
as $$
  update public.products p
  set name = g.name || coalesce(' · ' || (
        select string_agg(v.value, ' / ' order by coalesce(ga.sort_order, 2147483647), v.value)
        from public.product_variant_values pv
        join public.product_attribute_values v on v.id = pv.value_id
        left join public.product_group_attributes ga
          on ga.group_id = p.group_id and ga.attribute_id = pv.attribute_id
        where pv.product_id = p.id
      ), ''),
      description = g.description,
      updated_at = now()
  from public.product_groups g
  where g.id = p_group and p.group_id = g.id;
$$;

revoke execute on function public.refresh_variant_names(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------ the save
-- Creates or updates a group with its attributes and variants in one transaction; returns its id.
-- p: {
--   id?, name, description?, image_url?, is_active?,
--   attributes: [{ name, values: [text] }],            -- any number, in display order
--   variants:   [{ id?, options: [text],              -- one value per attribute, same order
--                  sku?, barcode?, unit?, price, track_stock?, is_active?, image_url? }]
-- }
-- Attributes and values are matched by name (case-insensitive) and created when new.
-- A variant left out of "variants" is deleted when nothing references it, else archived.
create or replace function public.save_product_group(p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group    uuid := nullif(p ->> 'id', '')::uuid;
  v_name     text := btrim(coalesce(p ->> 'name', ''));
  v_active   boolean := coalesce((p ->> 'is_active')::boolean, true);
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

  if v_group is null then
    insert into public.product_groups (name, description, image_url, is_active, created_by)
    values (v_name, nullif(btrim(p ->> 'description'), ''), nullif(btrim(p ->> 'image_url'), ''),
            v_active, (select auth.uid()))
    returning id into v_group;
  else
    update public.product_groups
    set name = v_name,
        description = nullif(btrim(p ->> 'description'), ''),
        image_url = nullif(btrim(p ->> 'image_url'), ''),
        is_active = v_active
    where id = v_group;
    if not found then
      raise exception 'product % not found', v_group using errcode = 'P0002';
    end if;
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
        nullif(btrim(v_v ->> 'image_url'), ''), v_sort
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
          image_url = nullif(btrim(v_v ->> 'image_url'), ''),
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

-- Archive or restore a whole group with all its variants.
create or replace function public.set_product_group_active(p_group uuid, p_active boolean) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_products('UPDATE') then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  update public.product_groups set is_active = p_active where id = p_group;
  if not found then
    raise exception 'product % not found', p_group using errcode = 'P0002';
  end if;
  update public.products set is_active = p_active, updated_at = now() where group_id = p_group;
end;
$$;

revoke execute on function public.set_product_group_active(uuid, boolean) from public, anon;
grant execute on function public.set_product_group_active(uuid, boolean) to authenticated;

-- ------------------------------------------------------------------ reading
-- A group as the admin screens read it:
-- { id, name, description, image_url, is_active, min_price, max_price,
--   attributes: [{ id, name, values: [text] }],
--   variants: [{ id, name, options: [text], sku, barcode, unit, price, track_stock, is_active, image_url }] }
-- p_all = false leaves out archived variants (and the values only they use).
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

-- One page of groups for the admin list: { total, rows: [product_group_json] }.
-- Search matches the group name (accents ignored) or a variant's SKU or barcode.
create or replace function public.list_product_groups(
  p_search           text default null,
  p_include_archived boolean default false,
  p_limit            int default 20,
  p_offset           int default 0
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

revoke execute on function public.list_product_groups(text, boolean, int, int) from public;
grant execute on function public.list_product_groups(text, boolean, int, int) to anon, authenticated;

notify pgrst, 'reload schema';
