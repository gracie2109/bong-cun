-- Product categories (docs/module-san-pham.md, step 1): save, move, delete and list.
-- Every function checks the "products" permission itself. Safe to run more than once.

-- ------------------------------------------------------------------ the save
-- p: { id?, parent_id?, name, image_url?, sort_order?, is_active? }; returns the id.
create or replace function public.save_product_category(p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id      uuid := nullif(p ->> 'id', '')::uuid;
  v_parent  uuid := nullif(p ->> 'parent_id', '')::uuid;
  v_name    text := btrim(coalesce(p ->> 'name', ''));
  v_old     public.product_categories;
  v_slug    text;
  v_base    text;
  v_n       int := 1;
begin
  if not public.can_products(case when v_id is null then 'CREATE' else 'UPDATE' end) then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if v_name = '' then
    raise exception 'a category needs a name' using errcode = '22023', hint = 'name_required';
  end if;
  if v_parent is not null and v_parent = v_id then
    raise exception 'a category cannot be its own parent' using errcode = '22023', hint = 'invalid_parent';
  end if;
  if v_parent is not null and not exists (select 1 from public.product_categories where id = v_parent) then
    raise exception 'parent category not found' using errcode = 'P0002', hint = 'invalid_parent';
  end if;
  if exists (
    select 1 from public.product_categories
    where parent_id is not distinct from v_parent
      and lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_name))
      and id is distinct from v_id
  ) then
    raise exception 'category % already exists here', v_name using errcode = '23505', hint = 'duplicate_name', detail = v_name;
  end if;

  if v_id is not null then
    select * into v_old from public.product_categories where id = v_id;
    if not found then
      raise exception 'category % not found', v_id using errcode = 'P0002';
    end if;
  end if;

  -- The slug follows the name; a clash adds -2, -3...
  if v_old.id is null or v_old.name is distinct from v_name then
    v_base := public.slugify(v_name);
    v_slug := v_base;
    while exists (select 1 from public.product_categories where slug = v_slug and id is distinct from v_id) loop
      v_n := v_n + 1;
      v_slug := v_base || '-' || v_n;
    end loop;
  else
    v_slug := v_old.slug;
  end if;

  if v_id is null then
    insert into public.product_categories (parent_id, name, slug, image_url, sort_order, is_active)
    values (
      v_parent, v_name, v_slug, nullif(btrim(p ->> 'image_url'), ''),
      coalesce(
        (p ->> 'sort_order')::int,
        (select coalesce(max(sort_order), 0) + 1 from public.product_categories where parent_id is not distinct from v_parent)
      ),
      coalesce((p ->> 'is_active')::boolean, true)
    )
    returning id into v_id;
  else
    update public.product_categories
    set parent_id = v_parent,
        name = v_name,
        slug = v_slug,
        image_url = nullif(btrim(p ->> 'image_url'), ''),
        sort_order = coalesce((p ->> 'sort_order')::int, sort_order),
        is_active = coalesce((p ->> 'is_active')::boolean, is_active)
    where id = v_id;
  end if;
  return v_id;
end;
$$;

revoke execute on function public.save_product_category(jsonb) from public, anon;
grant execute on function public.save_product_category(jsonb) to authenticated;

-- Moves a category one place up or down among its siblings.
create or replace function public.move_product_category(p_id uuid, p_direction text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_parent uuid;
  v_ids    uuid[];
  v_pos    int;
  v_other  int;
begin
  if not public.can_products('UPDATE') then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if p_direction not in ('up', 'down') then
    raise exception 'direction must be up or down' using errcode = '22023';
  end if;
  select parent_id into v_parent from public.product_categories where id = p_id;
  if not found then
    raise exception 'category % not found', p_id using errcode = 'P0002';
  end if;

  select array_agg(id order by sort_order, lower(name), id) into v_ids
  from public.product_categories where parent_id is not distinct from v_parent;
  v_pos := array_position(v_ids, p_id);
  v_other := case when p_direction = 'up' then v_pos - 1 else v_pos + 1 end;
  if v_other < 1 or v_other > array_length(v_ids, 1) then
    return;
  end if;
  v_ids[v_pos] := v_ids[v_other];
  v_ids[v_other] := p_id;

  -- Rewrite the siblings' order 1..n so ties never keep two rows in the same place.
  update public.product_categories c
  set sort_order = o.ord::int
  from unnest(v_ids) with ordinality as o(id, ord)
  where c.id = o.id and c.sort_order is distinct from o.ord::int;
end;
$$;

revoke execute on function public.move_product_category(uuid, text) from public, anon;
grant execute on function public.move_product_category(uuid, text) to authenticated;

-- A category with products or sub-categories is only switched off, so this refuses it.
create or replace function public.delete_product_category(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_products('DELETE') then
    raise exception 'not allowed to delete products' using errcode = '42501';
  end if;
  if exists (select 1 from public.product_categories where parent_id = p_id) then
    raise exception 'category has sub-categories' using errcode = '23503', hint = 'has_children';
  end if;
  begin
    delete from public.product_categories where id = p_id;
  exception when foreign_key_violation then
    raise exception 'category is in use' using errcode = '23503', hint = 'in_use';
  end;
  if not found then
    raise exception 'category % not found', p_id using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.delete_product_category(uuid) from public, anon;
grant execute on function public.delete_product_category(uuid) to authenticated;

-- --------------------------------------------------------------- the list
-- One page: { total, rows: [{ id, parent_id, parent_name, name, slug, image_url, sort_order,
-- is_active, product_count, child_count }] }, a parent followed by its children. Search matches
-- the name (accents ignored). product_count of a parent includes its sub-categories.
-- p_roots_only lists top-level categories only (the "parent" choice in the form).
create or replace function public.list_product_categories(
  p_search           text default null,
  p_include_inactive boolean default false,
  p_limit            int default 20,
  p_offset           int default 0,
  p_roots_only       boolean default false
) returns jsonb
language sql
stable
set search_path = ''
as $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term
  ), matched as (
    select c.*, par.name as parent_name,
           coalesce(par.sort_order, c.sort_order) as root_sort,
           lower(coalesce(par.name, c.name)) as root_name
    from public.product_categories c
    left join public.product_categories par on par.id = c.parent_id, params
    where (p_include_inactive or c.is_active)
      and (not p_roots_only or c.parent_id is null)
      and (params.term is null or lower(public.immutable_unaccent(c.name)) like '%' || params.term || '%')
  ), page as (
    select * from matched
    order by root_sort, root_name, (parent_id is not null), sort_order, lower(name), id
    limit greatest(p_limit, 1) offset greatest(p_offset, 0)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', page.id,
        'parent_id', page.parent_id,
        'parent_name', page.parent_name,
        'name', page.name,
        'slug', page.slug,
        'image_url', page.image_url,
        'sort_order', page.sort_order,
        'is_active', page.is_active,
        'product_count', (
          select count(*) from public.product_groups g
          where g.category_id = page.id
             or g.category_id in (select id from public.product_categories where parent_id = page.id)
        ),
        'child_count', (select count(*) from public.product_categories where parent_id = page.id)
      ) order by page.root_sort, page.root_name, (page.parent_id is not null), page.sort_order, lower(page.name), page.id)
      from page
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.list_product_categories(text, boolean, int, int, boolean) from public;
grant execute on function public.list_product_categories(text, boolean, int, int, boolean) to anon, authenticated;

notify pgrst, 'reload schema';
