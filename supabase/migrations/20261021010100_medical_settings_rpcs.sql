-- Medical records, step 1 (2/3): RPCs for the medical settings screen
-- (docs/ho-so-benh-an.md, section 6). Runs after 20261021010000_medical_schema.sql.
-- Safe to run more than once.
--
-- Refusals carry a `hint` the screen turns into text: duplicate_name, bad_input, bad_protocol,
-- bad_rules, not_found.

-- ------------------------------------------------------------ diagnosis terms
-- p: { name, species_ids?, is_contagious?, is_active?, sort_order? }
-- On update a missing field keeps its value.
create or replace function public.save_diagnosis_term(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
  v_name text := nullif(btrim(p ->> 'name'), '');
  v_species uuid[];
begin
  if not public.can_medical('SETTING') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and v_name is null then
    raise exception 'name is required' using errcode = '22023', hint = 'bad_input';
  end if;
  if p_id is not null and not exists (select 1 from public.diagnosis_terms where id = p_id) then
    raise exception 'diagnosis % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_name is not null and exists (
    select 1 from public.diagnosis_terms
    where lower(btrim(name)) = lower(v_name) and id is distinct from p_id
  ) then
    raise exception 'a diagnosis with this name exists' using errcode = '23505', hint = 'duplicate_name';
  end if;

  if p ? 'species_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_species
    from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);
  end if;

  if p_id is null then
    insert into public.diagnosis_terms (name, species_ids, is_contagious, is_active, sort_order)
    values (
      v_name,
      coalesce(v_species, '{}'),
      coalesce((p ->> 'is_contagious')::boolean, false),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.diagnosis_terms set
      name = coalesce(v_name, name),
      species_ids = coalesce(v_species, species_ids),
      is_contagious = coalesce((p ->> 'is_contagious')::boolean, is_contagious),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id;
  end if;

  return v_id;
end;
$$;

revoke execute on function public.save_diagnosis_term(jsonb, uuid) from public, anon;
grant execute on function public.save_diagnosis_term(jsonb, uuid) to authenticated;

-- { total, rows: [{ id, name, species_ids, species_names, is_contagious, is_active, sort_order }] }
-- p_species keeps the terms for that species (and the ones for every species). Search matches the
-- name, accents ignored.
create or replace function public.list_diagnosis_terms(
  p_search      text default null,
  p_species     uuid default null,
  p_page        int default 1,
  p_page_size   int default 20,
  p_active_only boolean default false
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.is_staff() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select d.*
    from public.diagnosis_terms d
    where (not p_active_only or d.is_active)
      and (p_species is null or cardinality(d.species_ids) = 0 or p_species = any (d.species_ids))
      and (v_term = '' or lower(public.immutable_unaccent(d.name)) like v_like)
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id,
        'name', d.name,
        'species_ids', to_jsonb(d.species_ids),
        'species_names', coalesce((
          select jsonb_agg(s.name order by s.name) from public.species s where s.id = any (d.species_ids)
        ), '[]'::jsonb),
        'is_contagious', d.is_contagious,
        'is_active', d.is_active,
        'sort_order', d.sort_order
      ) order by d.sort_order, lower(d.name), d.id)
      from (select * from f order by sort_order, lower(name), id limit v_size offset v_offset) d
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function public.list_diagnosis_terms(text, uuid, int, int, boolean) from public, anon;
grant execute on function public.list_diagnosis_terms(text, uuid, int, int, boolean) to authenticated;

-- ---------------------------------------------------------------- vaccine types
-- p: { name, kind?, species_ids?, product_id?, series_doses?, series_interval_days?,
--      booster_interval_days?, min_age_weeks?, is_active?, sort_order? }
-- On update a missing field keeps its value; a null product_id, series_interval_days,
-- booster_interval_days or min_age_weeks that is sent clears it.
create or replace function public.save_vaccine_type(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := p_id;
  v_name text := nullif(btrim(p ->> 'name'), '');
  v_species uuid[];
  v_kind text := nullif(p ->> 'kind', '');
  v_doses int;
  v_gap int;
  v_product uuid;
begin
  if not public.can_medical('SETTING') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and v_name is null then
    raise exception 'name is required' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_kind is not null and v_kind not in ('vaccine', 'deworm', 'other') then
    raise exception 'unknown kind' using errcode = '22023', hint = 'bad_input';
  end if;
  if p_id is not null and not exists (select 1 from public.vaccine_types where id = p_id) then
    raise exception 'vaccine type % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_name is not null and exists (
    select 1 from public.vaccine_types
    where lower(btrim(name)) = lower(v_name) and id is distinct from p_id
  ) then
    raise exception 'a vaccine type with this name exists' using errcode = '23505', hint = 'duplicate_name';
  end if;

  if p ? 'species_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_species
    from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);
  end if;

  if p ? 'product_id' then
    v_product := nullif(p ->> 'product_id', '')::uuid;
    if v_product is not null and not exists (select 1 from public.products where id = v_product) then
      raise exception 'product not found' using errcode = 'P0002', hint = 'bad_input';
    end if;
  end if;

  -- The protocol as it will be stored: the sent value, else the current one.
  v_doses := coalesce(nullif(p ->> 'series_doses', '')::int,
                      (select series_doses from public.vaccine_types where id = p_id), 1);
  v_gap := case when p ? 'series_interval_days' then nullif(p ->> 'series_interval_days', '')::int
                else (select series_interval_days from public.vaccine_types where id = p_id) end;
  if v_doses < 1 or v_doses > 10 or (v_doses > 1 and coalesce(v_gap, 0) < 1) then
    raise exception 'a series of several shots needs the days between them' using errcode = '22023', hint = 'bad_protocol';
  end if;
  if coalesce(nullif(p ->> 'booster_interval_days', '')::int, 1) < 1
     or coalesce(nullif(p ->> 'min_age_weeks', '')::int, 0) < 0 then
    raise exception 'invalid protocol' using errcode = '22023', hint = 'bad_protocol';
  end if;

  if p_id is null then
    insert into public.vaccine_types (
      name, kind, species_ids, product_id, series_doses, series_interval_days,
      booster_interval_days, min_age_weeks, is_active, sort_order
    ) values (
      v_name,
      coalesce(v_kind, 'vaccine'),
      coalesce(v_species, '{}'),
      v_product,
      v_doses,
      v_gap,
      nullif(p ->> 'booster_interval_days', '')::int,
      nullif(p ->> 'min_age_weeks', '')::int,
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.vaccine_types set
      name = coalesce(v_name, name),
      kind = coalesce(v_kind, kind),
      species_ids = coalesce(v_species, species_ids),
      product_id = case when p ? 'product_id' then v_product else product_id end,
      series_doses = v_doses,
      series_interval_days = v_gap,
      booster_interval_days = case when p ? 'booster_interval_days'
        then nullif(p ->> 'booster_interval_days', '')::int else booster_interval_days end,
      min_age_weeks = case when p ? 'min_age_weeks'
        then nullif(p ->> 'min_age_weeks', '')::int else min_age_weeks end,
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id;
  end if;

  return v_id;
end;
$$;

revoke execute on function public.save_vaccine_type(jsonb, uuid) from public, anon;
grant execute on function public.save_vaccine_type(jsonb, uuid) to authenticated;

-- { total, rows: [{ id, name, kind, species_ids, species_names, product_id, product_name,
--   product_unit, stock_qty, series_doses, series_interval_days, booster_interval_days,
--   min_age_weeks, is_active, sort_order }] }
-- stock_qty is the unexpired stock at p_branch (null when the type has no product or no branch).
-- p_species keeps the types for that species (and the ones for every species).
create or replace function public.list_vaccine_types(
  p_search      text default null,
  p_kind        text default null,
  p_page        int default 1,
  p_page_size   int default 20,
  p_branch      uuid default null,
  p_species     uuid default null,
  p_active_only boolean default false
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.is_staff() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select v.*
    from public.vaccine_types v
    where (not p_active_only or v.is_active)
      and (p_kind is null or v.kind = p_kind)
      and (p_species is null or cardinality(v.species_ids) = 0 or p_species = any (v.species_ids))
      and (v_term = '' or lower(public.immutable_unaccent(v.name)) like v_like)
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id,
        'name', v.name,
        'kind', v.kind,
        'species_ids', to_jsonb(v.species_ids),
        'species_names', coalesce((
          select jsonb_agg(s.name order by s.name) from public.species s where s.id = any (v.species_ids)
        ), '[]'::jsonb),
        'product_id', v.product_id,
        'product_name', pr.name,
        'product_unit', pr.unit,
        'stock_qty', case when v.product_id is null or p_branch is null or not coalesce(pr.track_stock, false) then null
          else (
            select coalesce(sum(l.qty_on_hand), 0)
            from public.stock_lots l
            where l.product_id = v.product_id and l.branch_id = p_branch and l.qty_on_hand > 0
              and (l.expiry_date is null or l.expiry_date >= public.business_date())
          ) end,
        'series_doses', v.series_doses,
        'series_interval_days', v.series_interval_days,
        'booster_interval_days', v.booster_interval_days,
        'min_age_weeks', v.min_age_weeks,
        'is_active', v.is_active,
        'sort_order', v.sort_order
      ) order by v.sort_order, lower(v.name), v.id)
      from (select * from f order by sort_order, lower(name), id limit v_size offset v_offset) v
      left join public.products pr on pr.id = v.product_id
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function public.list_vaccine_types(text, text, int, int, uuid, uuid, boolean) from public, anon;
grant execute on function public.list_vaccine_types(text, text, int, int, uuid, uuid, boolean) to authenticated;

-- ------------------------------------------------------------------ branch rules
-- { exam_service_id, exam_service_name, remind_ahead_days, contagious_days,
--   require_vaccine_for_boarding }. A branch without a row gets the defaults
-- (no exam service, 7 days, 30 days, false).
create or replace function public.medical_settings_get(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'exam_service_id', s.exam_service_id,
      'exam_service_name', (select v.name from public.pet_services v where v.id = s.exam_service_id),
      'remind_ahead_days', coalesce(s.remind_ahead_days, 7),
      'contagious_days', coalesce(s.contagious_days, 30),
      'require_vaccine_for_boarding', coalesce(s.require_vaccine_for_boarding, false)
    )
    from (select 1) as one
    left join public.medical_settings s on s.branch_id = p_branch
  );
end;
$$;

revoke execute on function public.medical_settings_get(uuid) from public, anon;
grant execute on function public.medical_settings_get(uuid) to authenticated;

create or replace function public.save_medical_settings(p_branch uuid, p jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_service uuid := nullif(p ->> 'exam_service_id', '')::uuid;
  v_ahead int := coalesce(nullif(p ->> 'remind_ahead_days', '')::int, 7);
  v_days int := coalesce(nullif(p ->> 'contagious_days', '')::int, 30);
  v_boarding boolean := coalesce((p ->> 'require_vaccine_for_boarding')::boolean, false);
begin
  if not public.can_medical('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_ahead < 0 or v_ahead > 90 or v_days < 1 or v_days > 365 then
    raise exception 'invalid medical rules' using errcode = '22023', hint = 'bad_rules';
  end if;
  -- Only a medical service can be the default exam.
  if v_service is not null and not exists (
    select 1 from public.pet_services where id = v_service and category = 'medical' and is_active
  ) then
    raise exception 'the exam service must be an active medical service' using errcode = '22023', hint = 'bad_rules';
  end if;
  insert into public.medical_settings (branch_id, exam_service_id, remind_ahead_days, contagious_days, require_vaccine_for_boarding)
  values (p_branch, v_service, v_ahead, v_days, v_boarding)
  on conflict (branch_id) do update set
    exam_service_id = excluded.exam_service_id,
    remind_ahead_days = excluded.remind_ahead_days,
    contagious_days = excluded.contagious_days,
    require_vaccine_for_boarding = excluded.require_vaccine_for_boarding;
end;
$$;

revoke execute on function public.save_medical_settings(uuid, jsonb) from public, anon;
grant execute on function public.save_medical_settings(uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
