-- Product module, step 4 (2/9): pricing, saving and scanning of units (docs/module-san-pham.md, 3.4).
-- Runs after 20261015040000_product_units.sql. Safe to run more than once.

-- The one place a price is worked out. Without a unit: the branch price, else the general price.
-- With a unit: the unit's own price, else that price x the unit's factor. Null when the unit does
-- not belong to the product.
create or replace function public.product_unit_price(
  p_product uuid,
  p_branch  uuid default null,
  p_unit    uuid default null
) returns numeric
language sql
stable
set search_path = ''
as $$
  select case
    when p_unit is null then base.price
    when u.id is null then null
    else coalesce(u.price, round(base.price * u.factor, 2))
  end
  from (
    select p.id, coalesce(bp.price, p.price) as price
    from public.products p
    left join public.product_branch_prices bp on bp.product_id = p.id and bp.branch_id = p_branch
    where p.id = p_product
  ) base
  left join public.product_units u on u.id = p_unit and u.product_id = base.id;
$$;

revoke execute on function public.product_unit_price(uuid, uuid, uuid) from public;
grant execute on function public.product_unit_price(uuid, uuid, uuid) to anon, authenticated;

-- Replaces the units of one variant: [{ id?, name, factor, barcode?, price?, for_sale?, for_purchase?,
-- is_active? }] in order. A unit already on an invoice or stock document keeps its factor and is
-- switched off instead of deleted. Called by save_product_group, which checks the permission.
create or replace function public.save_product_units(p_product uuid, p_units jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_base    text;
  v_u       jsonb;
  v_id      uuid;
  v_name    text;
  v_factor  numeric;
  v_barcode text;
  v_price   numeric;
  v_sort    int := 0;
  v_keep    uuid[] := '{}';
  v_names   text[] := '{}';
  v_old     public.product_units;
  r         record;
begin
  select unit into v_base from public.products where id = p_product;
  if not found then
    raise exception 'product % not found', p_product using errcode = 'P0002';
  end if;

  for v_u in select * from jsonb_array_elements(coalesce(p_units, '[]'::jsonb)) loop
    v_sort := v_sort + 1;
    v_id := nullif(v_u ->> 'id', '')::uuid;
    v_name := btrim(coalesce(v_u ->> 'name', ''));
    v_factor := nullif(v_u ->> 'factor', '')::numeric;
    v_barcode := nullif(btrim(coalesce(v_u ->> 'barcode', '')), '');
    v_price := nullif(btrim(coalesce(v_u ->> 'price', '')), '')::numeric;

    if v_name = '' then
      raise exception 'a unit needs a name' using errcode = '22023', hint = 'unit_name_required';
    end if;
    if lower(v_name) = lower(btrim(v_base)) or lower(v_name) = any (v_names) then
      raise exception 'unit % is listed twice', v_name using errcode = '23505', hint = 'duplicate_unit', detail = v_name;
    end if;
    v_names := v_names || lower(v_name);
    if v_factor is null or v_factor <= 1 then
      raise exception 'unit % must be worth more than one %', v_name, v_base using errcode = '22023', hint = 'unit_factor', detail = v_name;
    end if;
    if v_price is not null and v_price < 0 then
      raise exception 'price must be zero or more' using errcode = '22023';
    end if;
    if v_barcode is not null and (
      exists (select 1 from public.products where barcode = v_barcode)
      or exists (select 1 from public.product_units where barcode = v_barcode and id is distinct from v_id)
    ) then
      raise exception 'barcode % is taken', v_barcode using errcode = '23505', hint = 'duplicate_barcode', detail = v_barcode;
    end if;

    if v_id is null then
      insert into public.product_units (product_id, name, factor, barcode, price, for_sale, for_purchase, is_active, sort_order)
      values (
        p_product, v_name, v_factor, v_barcode, v_price,
        coalesce((v_u ->> 'for_sale')::boolean, true),
        coalesce((v_u ->> 'for_purchase')::boolean, false),
        coalesce((v_u ->> 'is_active')::boolean, true),
        v_sort
      )
      returning id into v_id;
    else
      select * into v_old from public.product_units where id = v_id and product_id = p_product;
      if not found then
        raise exception 'unit % does not belong to this product', v_id using errcode = 'P0002';
      end if;
      if v_old.factor <> v_factor and (
        exists (select 1 from public.invoice_lines where unit_id = v_id)
        or exists (select 1 from public.stock_document_lines where unit_id = v_id)
      ) then
        raise exception 'unit % is already used, its factor cannot change', v_name
          using errcode = '23503', hint = 'unit_in_use', detail = v_name;
      end if;
      update public.product_units
      set name = v_name,
          factor = v_factor,
          barcode = v_barcode,
          price = v_price,
          for_sale = coalesce((v_u ->> 'for_sale')::boolean, true),
          for_purchase = coalesce((v_u ->> 'for_purchase')::boolean, false),
          is_active = coalesce((v_u ->> 'is_active')::boolean, true),
          sort_order = v_sort
      where id = v_id;
    end if;
    v_keep := v_keep || v_id;
  end loop;

  -- Units left out of the list: deleted when nothing uses them, else switched off.
  for r in select id from public.product_units where product_id = p_product and not (id = any (v_keep)) loop
    begin
      delete from public.product_units where id = r.id;
    exception when foreign_key_violation then
      update public.product_units set is_active = false where id = r.id;
    end;
  end loop;
end;
$$;

revoke execute on function public.save_product_units(uuid, jsonb) from public, anon, authenticated;

-- What a scanned code stands for: { product_id, unit_id | null, name, unit, factor, price } with
-- the price at p_branch, or null when nothing sellable has that code. A unit's code wins nothing
-- over a product's: codes are unique across both.
create or replace function public.find_by_barcode(p_code text, p_branch uuid default null) returns jsonb
language sql
stable
set search_path = ''
as $$
  with code as (select nullif(btrim(coalesce(p_code, '')), '') as v), hit as (
    select p.id as product_id, null::uuid as unit_id, p.name, p.unit, 1::numeric as factor, 0 as ord
    from public.products p, code
    where code.v is not null and p.barcode = code.v and p.is_active
    union all
    select p.id, u.id, p.name, u.name, u.factor, 1
    from public.product_units u
    join public.products p on p.id = u.product_id, code
    where code.v is not null and u.barcode = code.v and u.is_active and u.for_sale and p.is_active
  )
  select jsonb_build_object(
    'product_id', h.product_id,
    'unit_id', h.unit_id,
    'name', h.name,
    'unit', h.unit,
    'factor', h.factor,
    'price', public.product_unit_price(h.product_id, p_branch, h.unit_id)
  )
  from hit h
  order by h.ord
  limit 1;
$$;

revoke execute on function public.find_by_barcode(text, uuid) from public, anon;
grant execute on function public.find_by_barcode(text, uuid) to authenticated;

notify pgrst, 'reload schema';
