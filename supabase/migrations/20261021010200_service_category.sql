-- Medical records, step 1 (3/3): service groups (docs/ho-so-benh-an.md, sections 4 and 6).
-- Runs after 20261021010100_medical_settings_rpcs.sql. Safe to run more than once.
--
-- Before: every row in pet_services is a spa service, so the spa booking list and the public
-- spa price list would also show exams and lab tests once the clinic adds them.
-- After: pet_services.category is 'spa' (default, every existing row), 'medical' or 'other'.
-- save_pet_service takes the group; the public spa catalog and the web quote only use 'spa'
-- services. The POS and boarding extras still see every group.

alter table public.pet_services add column if not exists category text not null default 'spa';
alter table public.pet_services drop constraint if exists pet_services_category_check;
alter table public.pet_services add constraint pet_services_category_check
  check (category in ('spa', 'medical', 'other'));
create index if not exists pet_services_category_idx on public.pet_services (category);

-- --------------------------------------------------------------------- services
-- p: { name, description, type, unit, general_price, duration_minutes, is_show, is_active,
--      category ('spa' | 'medical' | 'other', default 'spa'), species_ids: [...] }
-- Species dropped from the service lose the prices set for them. A missing category keeps the
-- current one on update.
create or replace function public.save_pet_service(p jsonb, p_id uuid default null) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
  v_species uuid[];
begin
  if p_id is null then
    insert into public.pet_services
      (name, description, type, unit, general_price, duration_minutes, is_show, is_active, category)
    values (
      p ->> 'name',
      nullif(p ->> 'description', ''),
      nullif(p ->> 'type', ''),
      nullif(p ->> 'unit', ''),
      nullif(p ->> 'general_price', '')::numeric,
      nullif(p ->> 'duration_minutes', '')::int,
      coalesce((p ->> 'is_show')::boolean, true),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'category', ''), 'spa')
    )
    returning id into v_id;
  else
    update public.pet_services set
      name             = p ->> 'name',
      description      = nullif(p ->> 'description', ''),
      type             = nullif(p ->> 'type', ''),
      unit             = nullif(p ->> 'unit', ''),
      general_price    = nullif(p ->> 'general_price', '')::numeric,
      duration_minutes = nullif(p ->> 'duration_minutes', '')::int,
      is_show          = coalesce((p ->> 'is_show')::boolean, true),
      is_active        = coalesce((p ->> 'is_active')::boolean, true),
      category         = coalesce(nullif(p ->> 'category', ''), category)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'pet service % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  select coalesce(array_agg(x::uuid), '{}')
  into v_species
  from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);

  delete from public.pet_service_prices
  where service_id = v_id and species_id <> all (v_species);

  delete from public.service_species where service_id = v_id;
  insert into public.service_species (service_id, species_id)
  select v_id, s from unnest(v_species) as s;

  return v_id;
end;
$$;

-- ------------------------------------------------------------- public spa catalog
-- Copied from 20261018040000_spa_public_catalog.sql: only 'spa' services are listed.
create or replace function public.spa_public_catalog(p_branch uuid default null) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with sp as (
    select s.id, s.name
    from public.species s
    where s.is_active
  ),
  svc as (
    select v.*
    from public.pet_services v
    where v.is_active and v.category = 'spa'
  ),
  cmb as (
    select c.*
    from public.pet_service_combos c
    where c.is_active and c.status = 1 and coalesce(c.mark_as_id, '4') <> '3'
  ),
  svc_species as (
    select v.id as service_id,
           coalesce(
             (select jsonb_agg(ss.species_id order by sp.name)
              from public.service_species ss join sp on sp.id = ss.species_id
              where ss.service_id = v.id),
             '[]'::jsonb
           ) as listed,
           (select jsonb_agg(sp.id order by sp.name) from sp) as every
    from svc v
  ),
  cmb_species as (
    select c.id as combo_id,
           coalesce(
             (select jsonb_agg(cs.species_id order by sp.name)
              from public.combo_species cs join sp on sp.id = cs.species_id
              where cs.combo_id = c.id),
             '[]'::jsonb
           ) as listed,
           (select jsonb_agg(sp.id order by sp.name) from sp) as every
    from cmb c
  ),
  prices as (
    select distinct on (pr.species_id, pr.service_id, pr.bracket_id)
           pr.species_id, pr.service_id, pr.bracket_id, pr.price
    from public.pet_service_prices pr
    join svc on svc.id = pr.service_id and svc.type = 'by_weight'
    where pr.branch_id is null or pr.branch_id = p_branch
    order by pr.species_id, pr.service_id, pr.bracket_id, (pr.branch_id is not null) desc
  )
  select jsonb_build_object(
    'species', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', sp.id,
                 'name', sp.name,
                 'brackets', coalesce((
                   select jsonb_agg(
                            jsonb_build_object('id', b.id, 'label', b.label, 'min_kg', b.min_kg, 'max_kg', b.max_kg)
                            order by b.min_kg)
                   from public.weight_brackets b where b.species_id = sp.id
                 ), '[]'::jsonb)
               )
               order by sp.name)
      from sp
    ), '[]'::jsonb),
    'services', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', v.id,
                 'name', v.name,
                 'description', v.description,
                 'type', coalesce(v.type, 'all'),
                 'duration_minutes', v.duration_minutes,
                 'general_price', v.general_price,
                 'species_ids', case when jsonb_array_length(ss.listed) = 0 then coalesce(ss.every, '[]'::jsonb) else ss.listed end,
                 'prices', coalesce((
                   select jsonb_agg(jsonb_build_object(
                            'species_id', p.species_id, 'bracket_id', p.bracket_id, 'price', p.price))
                   from prices p where p.service_id = v.id
                 ), '[]'::jsonb)
               )
               order by v.name)
      from svc v join svc_species ss on ss.service_id = v.id
    ), '[]'::jsonb),
    'combos', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', c.id,
                 'name', c.name,
                 'description', c.description,
                 'price', c.price,
                 'origin_price', c.origin_price,
                 'duration_minutes', c.duration_minutes,
                 'mark', c.mark_as_id,
                 'species_ids', case when jsonb_array_length(cs.listed) = 0 then coalesce(cs.every, '[]'::jsonb) else cs.listed end,
                 'service_names', coalesce((
                   select jsonb_agg(v.name order by v.name)
                   from public.combo_services x join public.pet_services v on v.id = x.service_id
                   where x.combo_id = c.id
                 ), '[]'::jsonb)
               )
               order by c.name)
      from cmb c join cmb_species cs on cs.combo_id = c.id
    ), '[]'::jsonb)
  );
$$;

-- ---------------------------------------------------------------- web quote
-- Copied from 20261018050000_spa_web_slots.sql: only 'spa' services can be booked on the web.
create or replace function public.spa_ticket_quote(p_branch uuid, p_pet uuid, p_type text, p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_default_minutes constant int := 30;
  v_species uuid;
  v_service public.pet_services;
  v_combo   public.pet_service_combos;
  v_weight  numeric;
  v_price   numeric;
begin
  select species_id into v_species from public.pets where id = p_pet and status = 'active';
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'no_pet';
  end if;

  if p_type = 'combo' then
    select * into v_combo from public.pet_service_combos
    where id = p_id and status = 1 and is_active and coalesce(mark_as_id, '4') <> '3';
    if not found then
      raise exception 'combo is not available' using errcode = 'P0002', hint = 'unavailable';
    end if;
    if exists (select 1 from public.combo_species where combo_id = v_combo.id)
       and not exists (select 1 from public.combo_species where combo_id = v_combo.id and species_id = v_species) then
      raise exception 'the combo is not for this species' using errcode = '22023', hint = 'wrong_species';
    end if;
    return jsonb_build_object(
      'name', v_combo.name,
      'minutes', coalesce(nullif(v_combo.duration_minutes, 0), c_default_minutes),
      'price', v_combo.price,
      'weight_kg', null
    );
  elsif p_type = 'service' then
    select * into v_service from public.pet_services where id = p_id and is_active and category = 'spa';
    if not found then
      raise exception 'service is not available' using errcode = 'P0002', hint = 'unavailable';
    end if;
    if exists (select 1 from public.service_species where service_id = v_service.id)
       and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
      raise exception 'the service is not for this species' using errcode = '22023', hint = 'wrong_species';
    end if;
    if v_service.type = 'by_weight' then
      select weight_kg into v_weight from public.pet_weight_logs where pet_id = p_pet order by measured_at desc limit 1;
      v_price := case when v_weight is null then null
                      else public.get_service_price(v_species, v_service.id, v_weight, p_branch) end;
    else
      v_price := v_service.general_price;
    end if;
    return jsonb_build_object(
      'name', v_service.name,
      'minutes', coalesce(nullif(v_service.duration_minutes, 0), c_default_minutes),
      'price', v_price,
      'weight_kg', v_weight
    );
  end if;
  raise exception 'unknown ticket type' using errcode = '22023', hint = 'unavailable';
end;
$$;

notify pgrst, 'reload schema';
