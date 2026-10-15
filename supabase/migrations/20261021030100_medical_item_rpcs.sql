-- Medical records, step 3 (2/3): the RPCs that add, change and remove the lines of a visit, and
-- the prescription (docs/ho-so-benh-an.md, sections 5 and 6). Runs after
-- 20261021030000_medical_items.sql. Safe to run more than once.
--
-- Lines can be added to an open case and to a signed one that is not yet paid for (forgetting a
-- shot does not mean editing the record). A line that went onto an invoice cannot change.
-- Refusals carry a `hint`: bad_input, not_found, not_editable, paid, no_service, not_available,
-- species_not_allowed (detail: pet), no_weight (detail: service), no_price (detail: service),
-- bad_unit.

-- The status of a signed visit follows its lines: `done` while something is waiting to be charged,
-- `paid` when nothing is (no lines to charge, or every line is on an invoice).
create or replace function public.medical_refresh_status(p_visit uuid) returns void
language sql
security definer
set search_path = ''
as $$
  update public.medical_visits v set status = case
    when exists (
      select 1 from public.medical_visit_items i
      where i.visit_id = v.id and i.kind in ('service', 'product') and i.invoice_line_id is null
    ) then 'done' else 'paid' end
  where v.id = p_visit and v.signed_at is not null and v.status in ('done', 'paid');
$$;

revoke execute on function public.medical_refresh_status(uuid) from public, anon, authenticated;

-- Usable stock of a product at a branch, in the product's own unit: lots that have not expired.
create or replace function public.medical_stock_qty(p_branch uuid, p_product uuid) returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(qty_on_hand), 0)
  from public.stock_lots
  where branch_id = p_branch and product_id = p_product
    and (expiry_date is null or expiry_date >= public.business_date());
$$;

revoke execute on function public.medical_stock_qty(uuid, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------- add a line
-- p: { kind: 'service' | 'product' | 'external',
--      service_id | product_id | name (external), unit_id?, qty?, take_home?,
--      dose?, frequency?, days?, route?, instructions? }
-- Returns { id, warnings: ['low_stock'] }.
create or replace function public.add_medical_item(p_visit uuid, p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_visit    public.medical_visits;
  v_kind     text := p ->> 'kind';
  v_qty      numeric := coalesce(nullif(p ->> 'qty', '')::numeric, 1);
  v_service  public.pet_services;
  v_product  public.products;
  v_unit     public.product_units;
  v_species  uuid;
  v_name     text;
  v_price    numeric := 0;
  v_factor   numeric := 1;
  v_unit_name text;
  v_days     int := nullif(p ->> 'days', '')::int;
  v_id       uuid;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into v_visit from public.medical_visits where id = p_visit for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status not in ('in_progress', 'done', 'paid') then
    raise exception 'the visit is not open' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_kind is null or v_kind not in ('service', 'product', 'external') or v_qty <= 0 or v_qty > 999
     or (v_days is not null and v_days <= 0) then
    raise exception 'bad line' using errcode = '22023', hint = 'bad_input';
  end if;

  select species_id into v_species from public.pets where id = v_visit.pet_id;

  if v_kind = 'service' then
    select * into v_service from public.pet_services
    where id = nullif(p ->> 'service_id', '')::uuid and is_active and category = 'medical';
    if not found then
      raise exception 'service is not available' using errcode = 'P0002', hint = 'no_service';
    end if;
    if exists (select 1 from public.service_species where service_id = v_service.id)
       and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
      raise exception 'the service is not for this species' using errcode = '22023', hint = 'species_not_allowed', detail = v_visit.pet_name;
    end if;
    if v_service.type <> 'all' and v_visit.weight_kg is null then
      raise exception 'the weight is needed for this service' using errcode = 'P0001', hint = 'no_weight', detail = v_service.name;
    end if;
    v_price := public.get_service_price(v_species, v_service.id, coalesce(v_visit.weight_kg, 0), v_visit.branch_id);
    if v_price is null then
      raise exception 'no price for this service' using errcode = 'P0001', hint = 'no_price', detail = v_service.name;
    end if;
    v_name := v_service.name;
    v_unit_name := v_service.unit;

  elsif v_kind = 'product' then
    select * into v_product from public.products
    where id = nullif(p ->> 'product_id', '')::uuid and is_active;
    if not found then
      raise exception 'product is not available' using errcode = 'P0002', hint = 'not_available';
    end if;
    if nullif(p ->> 'unit_id', '') is not null then
      select * into v_unit from public.product_units
      where id = (p ->> 'unit_id')::uuid and product_id = v_product.id and is_active and for_sale;
      if not found then
        raise exception 'unit does not belong to the product' using errcode = '22023', hint = 'bad_unit';
      end if;
      v_factor := v_unit.factor;
      v_unit_name := v_unit.name;
    else
      v_unit_name := v_product.unit;
    end if;
    v_price := public.product_unit_price(v_product.id, v_visit.branch_id, v_unit.id);
    if v_price is null then
      raise exception 'no price for this product' using errcode = 'P0001', hint = 'no_price', detail = v_product.name;
    end if;
    v_name := v_product.name;
    if v_product.track_stock and public.medical_stock_qty(v_visit.branch_id, v_product.id) < v_qty * v_factor then
      v_warnings := v_warnings || to_jsonb('low_stock'::text);
    end if;

  else
    v_name := nullif(btrim(p ->> 'name'), '');
    if v_name is null then
      raise exception 'the medicine needs a name' using errcode = '22023', hint = 'bad_input';
    end if;
  end if;

  insert into public.medical_visit_items (
    visit_id, branch_id, kind, service_id, product_id, unit_id, unit_name, unit_factor, name, qty,
    unit_price, amount, take_home, dose, frequency, days, route, instructions, created_by, created_by_name
  ) values (
    p_visit, v_visit.branch_id, v_kind, v_service.id, v_product.id, v_unit.id, v_unit_name, v_factor, v_name, v_qty,
    v_price, round(v_price * v_qty, 2),
    -- External medicine is always for the owner to take; services are never "taken home".
    case v_kind when 'external' then true when 'service' then false else coalesce((p ->> 'take_home')::boolean, false) end,
    nullif(btrim(p ->> 'dose'), ''), nullif(btrim(p ->> 'frequency'), ''), v_days,
    nullif(btrim(p ->> 'route'), ''), nullif(btrim(p ->> 'instructions'), ''),
    v_uid, public.staff_display_name(v_uid)
  ) returning id into v_id;

  perform public.medical_refresh_status(p_visit);
  return jsonb_build_object('id', v_id, 'warnings', v_warnings);
end;
$$;

revoke execute on function public.add_medical_item(uuid, jsonb) from public, anon;
grant execute on function public.add_medical_item(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------- change a line
-- p: any of { qty, unit_id (product lines), take_home, dose, frequency, days, route, instructions }.
-- A missing field keeps its value; '' clears a text field. The price is worked out again from the
-- price the line was added with (a changed unit gets the price of that unit).
create or replace function public.update_medical_item(p_id uuid, p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item     public.medical_visit_items;
  v_visit    public.medical_visits;
  v_qty      numeric;
  v_unit     public.product_units;
  v_factor   numeric;
  v_unit_name text;
  v_unit_id  uuid;
  v_price    numeric;
  v_days     int;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into v_item from public.medical_visit_items where id = p_id for update;
  if not found then
    raise exception 'line not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_visit from public.medical_visits where id = v_item.visit_id for update;
  if not public.can_medical('UPDATE', v_item.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.invoice_line_id is not null or v_visit.status not in ('in_progress', 'done', 'paid') then
    raise exception 'the line can no longer be changed' using errcode = 'P0001', hint = 'not_editable';
  end if;

  v_qty := case when p ? 'qty' then (p ->> 'qty')::numeric else v_item.qty end;
  v_days := case when p ? 'days' then nullif(p ->> 'days', '')::int else v_item.days end;
  if v_qty is null or v_qty <= 0 or v_qty > 999 or (v_days is not null and v_days <= 0) then
    raise exception 'bad line' using errcode = '22023', hint = 'bad_input';
  end if;

  v_price := v_item.unit_price;
  v_factor := v_item.unit_factor;
  v_unit_name := v_item.unit_name;
  v_unit_id := v_item.unit_id;
  if v_item.kind = 'product' and p ? 'unit_id' then
    if nullif(p ->> 'unit_id', '') is null then
      v_unit_id := null;
      v_factor := 1;
      select unit into v_unit_name from public.products where id = v_item.product_id;
    else
      select * into v_unit from public.product_units
      where id = (p ->> 'unit_id')::uuid and product_id = v_item.product_id and is_active and for_sale;
      if not found then
        raise exception 'unit does not belong to the product' using errcode = '22023', hint = 'bad_unit';
      end if;
      v_unit_id := v_unit.id;
      v_factor := v_unit.factor;
      v_unit_name := v_unit.name;
    end if;
    v_price := public.product_unit_price(v_item.product_id, v_item.branch_id, v_unit_id);
  end if;

  update public.medical_visit_items set
    qty = v_qty,
    unit_id = v_unit_id,
    unit_name = v_unit_name,
    unit_factor = v_factor,
    unit_price = v_price,
    amount = case when kind = 'external' then 0 else round(v_price * v_qty, 2) end,
    take_home = case
      when kind = 'external' then true
      when kind = 'service' then false
      when p ? 'take_home' then coalesce((p ->> 'take_home')::boolean, false)
      else take_home end,
    dose = case when p ? 'dose' then nullif(btrim(p ->> 'dose'), '') else dose end,
    frequency = case when p ? 'frequency' then nullif(btrim(p ->> 'frequency'), '') else frequency end,
    days = v_days,
    route = case when p ? 'route' then nullif(btrim(p ->> 'route'), '') else route end,
    instructions = case when p ? 'instructions' then nullif(btrim(p ->> 'instructions'), '') else instructions end
  where id = p_id;

  if v_item.kind = 'product'
     and exists (select 1 from public.products pr where pr.id = v_item.product_id and pr.track_stock)
     and public.medical_stock_qty(v_item.branch_id, v_item.product_id) < v_qty * v_factor then
    v_warnings := v_warnings || to_jsonb('low_stock'::text);
  end if;
  return jsonb_build_object('id', p_id, 'warnings', v_warnings);
end;
$$;

revoke execute on function public.update_medical_item(uuid, jsonb) from public, anon;
grant execute on function public.update_medical_item(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------- remove a line
create or replace function public.remove_medical_item(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item  public.medical_visit_items;
  v_visit public.medical_visits;
begin
  select * into v_item from public.medical_visit_items where id = p_id for update;
  if not found then
    raise exception 'line not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_visit from public.medical_visits where id = v_item.visit_id for update;
  if not public.can_medical('UPDATE', v_item.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.invoice_line_id is not null or v_visit.status not in ('in_progress', 'done', 'paid') then
    raise exception 'the line can no longer be removed' using errcode = 'P0001', hint = 'not_editable';
  end if;
  delete from public.medical_visit_items where id = p_id;
  perform public.medical_refresh_status(v_item.visit_id);
end;
$$;

revoke execute on function public.remove_medical_item(uuid) from public, anon;
grant execute on function public.remove_medical_item(uuid) to authenticated;

-- ---------------------------------------------------------------- prescription
-- Everything the printed prescription shows: the pet and owner, diagnoses, the medicine to take
-- home (from stock or bought elsewhere), the owner's instructions, the re-check date and the vet.
create or replace function public.medical_prescription(p_visit uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v public.medical_visits;
begin
  select * into v from public.medical_visits where id = p_visit;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'code', v.code,
    'date', public.medical_local_date(coalesce(v.signed_at, v.checked_in_at, v.created_at)),
    'branch_name', (select b.name from public.branches b where b.id = v.branch_id),
    'pet_name', v.pet_name,
    'species_name', (select s.name from public.pets p join public.species s on s.id = p.species_id where p.id = v.pet_id),
    'weight_kg', v.weight_kg,
    'customer_name', v.customer_name,
    'customer_phone', v.customer_phone,
    'vet_name', coalesce(v.signed_by_name, v.vet_name),
    'signed', v.signed_at is not null,
    'owner_instructions', v.owner_instructions,
    'recheck_on', v.recheck_on,
    'diagnoses', coalesce((
      select jsonb_agg(d.name order by d.sort_order) from public.medical_diagnoses d where d.visit_id = v.id
    ), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', i.name, 'qty', i.qty,
        'unit_name', coalesce(i.unit_name, (select p.unit from public.products p where p.id = i.product_id)),
        'dose', i.dose, 'frequency', i.frequency, 'days', i.days, 'route', i.route,
        'instructions', i.instructions, 'external', i.kind = 'external'
      ) order by i.created_at, i.id)
      from public.medical_visit_items i where i.visit_id = v.id and i.take_home
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.medical_prescription(uuid) from public, anon;
grant execute on function public.medical_prescription(uuid) to authenticated;

notify pgrst, 'reload schema';
