-- Pet hotel (boarding), step 3 (1/2): care log and extra charges of a stay
-- (docs/khach-san-thu-cung.md, sections 4 and 6). Safe to run more than once.
--
-- Before: a stay has pets and kennels but nothing records what happens during it, and no money.
-- After: staff write a care log per pet (meals, walks, potty, medicine, notes) and add extra
-- services from the service catalogue; both are shown on the stay detail. boarding_charges is also
-- where check-out (next file) writes the night and late-fee lines, and where the POS takes money
-- from (step 4). The client only reads these tables; every write goes through the RPCs.
-- Runs after 20261020020200_boarding_views.sql.
--
-- Refusals carry a `hint`: not_found, not_editable (the stay is not checked in), bad_input,
-- no_service, species_not_allowed (detail: pet), no_price (detail: service), too_old (a log older
-- than a day).

-- ---------------------------------------------------------------------- tables
create table if not exists public.boarding_care_logs (
  id                  uuid primary key default gen_random_uuid(),
  stay_pet_id         uuid not null references public.boarding_stay_pets(id) on delete cascade,
  stay_id             uuid not null references public.boarding_stays(id) on delete cascade,
  branch_id           uuid not null references public.branches(id) on delete restrict,
  kind                text not null check (kind in ('meal', 'walk', 'potty', 'medication', 'note')),
  -- Only for meals.
  meal_eaten          text check (meal_eaten in ('all', 'some', 'none')),
  content             text,
  visible_to_customer boolean not null default true,
  logged_at           timestamptz not null default now(),
  created_by          uuid references auth.users(id) on delete set null,
  check (kind = 'meal' or meal_eaten is null),
  check (kind = 'meal' or nullif(btrim(content), '') is not null)
);
create index if not exists boarding_care_logs_stay_idx on public.boarding_care_logs (stay_id, logged_at desc);
create index if not exists boarding_care_logs_pet_idx on public.boarding_care_logs (stay_pet_id, logged_at desc);

-- What the customer owes for a stay: one night line per pet and a late-fee line, both written at
-- check-out, and the extras written as they happen. invoice_line_id is set once the POS bills it.
create table if not exists public.boarding_charges (
  id              uuid primary key default gen_random_uuid(),
  stay_id         uuid not null references public.boarding_stays(id) on delete cascade,
  stay_pet_id     uuid references public.boarding_stay_pets(id) on delete cascade,
  branch_id       uuid not null references public.branches(id) on delete restrict,
  kind            text not null check (kind in ('night', 'late', 'extra')),
  service_id      uuid references public.pet_services(id) on delete restrict,
  name            text not null,
  qty             numeric(8,2) not null check (qty > 0),
  unit_price      numeric(14,2) not null check (unit_price >= 0),
  amount          numeric(14,2) not null check (amount >= 0),
  invoice_line_id uuid references public.invoice_lines(id) on delete set null,
  created_by      uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  check (kind <> 'extra' or service_id is not null)
);
create index if not exists boarding_charges_stay_idx on public.boarding_charges (stay_id);
create index if not exists boarding_charges_open_idx on public.boarding_charges (branch_id) where invoice_line_id is null;

-- ------------------------------------------------------------------------ RLS
alter table public.boarding_care_logs enable row level security;
alter table public.boarding_charges   enable row level security;

drop policy if exists "boarding read" on public.boarding_care_logs;
create policy "boarding read" on public.boarding_care_logs for select to authenticated
  using ((select public.can_boarding('VIEW', branch_id)));

drop policy if exists "boarding read" on public.boarding_charges;
create policy "boarding read" on public.boarding_charges for select to authenticated
  using ((select public.can_boarding('VIEW', branch_id)));

revoke insert, update, delete on public.boarding_care_logs, public.boarding_charges from anon, authenticated;
revoke all on public.boarding_care_logs, public.boarding_charges from anon;

-- ------------------------------------------------------------------ care log
-- p: { kind, meal_eaten? ('all' | 'some' | 'none', meals only), content?, visible_to_customer? }
-- A meal needs no text; every other kind needs some. Returns the id.
create or replace function public.add_care_log(p_stay_pet uuid, p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sp      public.boarding_stay_pets;
  v_status  text;
  v_kind    text := p ->> 'kind';
  v_eaten   text := nullif(p ->> 'meal_eaten', '');
  v_content text := nullif(btrim(p ->> 'content'), '');
  v_id      uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = p_stay_pet;
  if not found then
    raise exception 'pet of stay % not found', p_stay_pet using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('CREATE', v_sp.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select status into v_status from public.boarding_stays where id = v_sp.stay_id;
  if v_status <> 'checked_in' or v_sp.status <> 'active' then
    raise exception 'the pet is not in the hotel' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_kind is null or v_kind not in ('meal', 'walk', 'potty', 'medication', 'note')
     or (v_kind = 'meal' and (v_eaten is null or v_eaten not in ('all', 'some', 'none')))
     or (v_kind <> 'meal' and v_content is null) then
    raise exception 'bad care log' using errcode = '22023', hint = 'bad_input';
  end if;

  insert into public.boarding_care_logs (
    stay_pet_id, stay_id, branch_id, kind, meal_eaten, content, visible_to_customer, created_by
  )
  values (
    p_stay_pet, v_sp.stay_id, v_sp.branch_id, v_kind,
    case when v_kind = 'meal' then v_eaten end,
    v_content,
    coalesce((p ->> 'visible_to_customer')::boolean, true),
    (select auth.uid())
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.add_care_log(uuid, jsonb) from public, anon;
grant execute on function public.add_care_log(uuid, jsonb) to authenticated;

-- A log is removed by its writer or anyone who can update stays within a day of writing it, and by
-- anyone who can delete at any time.
create or replace function public.delete_care_log(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_log public.boarding_care_logs;
  v_uid uuid := (select auth.uid());
begin
  select * into v_log from public.boarding_care_logs where id = p_id;
  if not found then
    raise exception 'log % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('DELETE', v_log.branch_id) then
    if not public.can_boarding('VIEW', v_log.branch_id)
       or not (v_log.created_by = v_uid or public.can_boarding('UPDATE', v_log.branch_id)) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_log.logged_at < now() - interval '24 hours' then
      raise exception 'the log is older than a day' using errcode = 'P0001', hint = 'too_old';
    end if;
  end if;
  delete from public.boarding_care_logs where id = p_id;
end;
$$;

revoke execute on function public.delete_care_log(uuid) from public, anon;
grant execute on function public.delete_care_log(uuid) to authenticated;

-- ------------------------------------------------------------------- extras
-- Adds a service from the catalogue to a pet that is in the hotel. The name and the price come from
-- the database: the price table of the pet's species and its weight at check-in.
create or replace function public.add_boarding_extra(p_stay_pet uuid, p_service uuid, p_qty numeric default 1) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sp      public.boarding_stay_pets;
  v_status  text;
  v_service public.pet_services;
  v_species uuid;
  v_price   numeric;
  v_qty     numeric := coalesce(p_qty, 1);
  v_id      uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = p_stay_pet;
  if not found then
    raise exception 'pet of stay % not found', p_stay_pet using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('CREATE', v_sp.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select status into v_status from public.boarding_stays where id = v_sp.stay_id;
  if v_status <> 'checked_in' or v_sp.status <> 'active' then
    raise exception 'the pet is not in the hotel' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_qty <= 0 or v_qty > 999 then
    raise exception 'bad quantity' using errcode = '22023', hint = 'bad_input';
  end if;

  select * into v_service from public.pet_services where id = p_service and is_active;
  if not found then
    raise exception 'service is not available' using errcode = 'P0002', hint = 'no_service';
  end if;
  select species_id into v_species from public.pets where id = v_sp.pet_id;
  if exists (select 1 from public.service_species where service_id = v_service.id)
     and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
    raise exception 'the service is not for this species' using errcode = '22023', hint = 'species_not_allowed', detail = v_sp.pet_name;
  end if;
  v_price := public.get_service_price(v_species, v_service.id, coalesce(v_sp.weight_kg, 0), v_sp.branch_id);
  if v_price is null then
    raise exception 'no price for this service' using errcode = 'P0001', hint = 'no_price', detail = v_service.name;
  end if;

  insert into public.boarding_charges (
    stay_id, stay_pet_id, branch_id, kind, service_id, name, qty, unit_price, amount, created_by
  )
  values (
    v_sp.stay_id, p_stay_pet, v_sp.branch_id, 'extra', v_service.id, v_service.name,
    v_qty, v_price, round(v_price * v_qty, 2), (select auth.uid())
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.add_boarding_extra(uuid, uuid, numeric) from public, anon;
grant execute on function public.add_boarding_extra(uuid, uuid, numeric) to authenticated;

-- Removes an extra that has not been billed yet.
create or replace function public.remove_boarding_extra(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_charge public.boarding_charges;
begin
  select * into v_charge from public.boarding_charges where id = p_id;
  if not found or v_charge.kind <> 'extra' then
    raise exception 'extra % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_charge.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_charge.invoice_line_id is not null then
    raise exception 'the extra is already billed' using errcode = 'P0001', hint = 'not_editable';
  end if;
  delete from public.boarding_charges where id = p_id;
end;
$$;

revoke execute on function public.remove_boarding_extra(uuid) from public, anon;
grant execute on function public.remove_boarding_extra(uuid) to authenticated;

-- ------------------------------------------------------------ list and detail
-- The stay JSON now sums what is really owed once the pets have left, and the extras while they
-- are in (re-created from 20261020020200_boarding_views.sql; only est_total changes).
create or replace function public.boarding_stay_json(p_stay public.boarding_stays) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', p_stay.id,
    'code', p_stay.code,
    'branch_id', p_stay.branch_id,
    'status', p_stay.status,
    'customer_id', p_stay.customer_id,
    'customer_name', p_stay.customer_name,
    'customer_phone', p_stay.customer_phone,
    'planned_in_at', p_stay.planned_in_at,
    'planned_out_at', p_stay.planned_out_at,
    'checked_in_at', p_stay.checked_in_at,
    'checked_out_at', p_stay.checked_out_at,
    'source', p_stay.source,
    'emergency_phone', p_stay.emergency_phone,
    'note', p_stay.note,
    'cancel_reason', p_stay.cancel_reason,
    'est_total',
      case
        when p_stay.status in ('checked_out', 'paid') then
          coalesce((select sum(c.amount) from public.boarding_charges c where c.stay_id = p_stay.id), 0)
        else
          coalesce((
            select sum(coalesce(sp.night_price, sp.est_night_price) * sp.charged_nights)
            from public.boarding_stay_pets sp where sp.stay_id = p_stay.id and sp.status = 'active'
          ), 0)
          + coalesce((select sum(c.amount) from public.boarding_charges c where c.stay_id = p_stay.id), 0)
      end,
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', sp.id,
        'line_no', sp.line_no,
        'pet_id', sp.pet_id,
        'pet_name', sp.pet_name,
        'status', sp.status,
        'kennel_type_id', sp.kennel_type_id,
        'kennel_type_name', t.name,
        'kennel_id', sp.kennel_id,
        'kennel_code', k.code,
        'nights_from', lower(sp.nights),
        'nights_to', upper(sp.nights),
        'charged_nights', sp.charged_nights,
        'is_extra_pet', sp.is_extra_pet,
        'est_night_price', sp.est_night_price,
        'night_price', sp.night_price,
        'weight_kg', sp.weight_kg,
        'vaccine_checked', sp.vaccine_checked,
        'vaccine_note', sp.vaccine_note,
        'belongings', sp.belongings,
        'belongings_returned', sp.belongings_returned,
        'feeding', sp.feeding,
        'medication', sp.medication,
        'has_notes', exists (
          select 1 from public.pets pt
          where pt.id = sp.pet_id
            and (nullif(btrim(pt.behavior_notes), '') is not null or nullif(btrim(pt.allergies), '') is not null)
        )
      ) order by sp.line_no)
      from public.boarding_stay_pets sp
      join public.kennel_types t on t.id = sp.kennel_type_id
      join public.kennels k on k.id = sp.kennel_id
      where sp.stay_id = p_stay.id
    ), '[]'::jsonb)
  );
$$;

revoke execute on function public.boarding_stay_json(public.boarding_stays) from public, anon, authenticated;

-- One stay in full: the list JSON plus the care log (newest first) and the charges.
-- care_logs: [{ id, stay_pet_id, pet_name, kind, meal_eaten, content, visible_to_customer, logged_at,
--               created_by_name, can_delete }]
-- charges: [{ id, stay_pet_id, pet_name, kind, name, qty, unit_price, amount, invoice_line_id }]
create or replace function public.get_boarding_stay(p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_stay public.boarding_stays;
  v_uid  uuid := (select auth.uid());
begin
  select * into v_stay from public.boarding_stays where id = p_id;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('VIEW', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return public.boarding_stay_json(v_stay) || jsonb_build_object(
    'care_logs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'stay_pet_id', l.stay_pet_id,
        'pet_name', sp.pet_name,
        'kind', l.kind,
        'meal_eaten', l.meal_eaten,
        'content', l.content,
        'visible_to_customer', l.visible_to_customer,
        'logged_at', l.logged_at,
        'created_by_name', case when l.created_by is null then null else public.staff_display_name(l.created_by) end,
        'can_delete', public.can_boarding('DELETE', l.branch_id)
          or (l.logged_at >= now() - interval '24 hours'
              and (l.created_by = v_uid or public.can_boarding('UPDATE', l.branch_id)))
      ) order by l.logged_at desc)
      from public.boarding_care_logs l
      join public.boarding_stay_pets sp on sp.id = l.stay_pet_id
      where l.stay_id = p_id
    ), '[]'::jsonb),
    'charges', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'stay_pet_id', c.stay_pet_id,
        'pet_name', sp.pet_name,
        'kind', c.kind,
        'name', c.name,
        'qty', c.qty,
        'unit_price', c.unit_price,
        'amount', c.amount,
        'invoice_line_id', c.invoice_line_id
      ) order by c.created_at, c.id)
      from public.boarding_charges c
      left join public.boarding_stay_pets sp on sp.id = c.stay_pet_id
      where c.stay_id = p_id
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.get_boarding_stay(uuid) from public, anon;
grant execute on function public.get_boarding_stay(uuid) to authenticated;

notify pgrst, 'reload schema';
