-- Medical records, step 4 (1/2): the e-book of shots (docs/ho-so-benh-an.md, sections 4, 5, 6).
-- Safe to run more than once. Runs after 20261021030200_medical_visit_rpcs_lines.sql.
--
-- Before: nothing records which vaccine or dewormer a pet had.
-- After: every shot (given at the clinic, or elsewhere and typed in) is a row of `vaccinations`
-- with the batch, the vet and the day the next shot is due. A shot given in a visit also adds a
-- charged line (the vaccine product, from the chosen batch) to that visit. A wrong entry is
-- voided, not deleted. Writes go through the RPCs below; the client only reads the table.
-- Refusals carry a `hint`: bad_input, not_found, no_vaccine, no_lot, not_editable, future_date.
-- Warnings returned by give_vaccination: too_young, species_mismatch.

create table if not exists public.vaccinations (
  id              uuid primary key default gen_random_uuid(),
  pet_id          uuid not null references public.pets(id) on delete restrict,
  vaccine_type_id uuid not null references public.vaccine_types(id) on delete restrict,
  -- Null for a shot given elsewhere.
  branch_id       uuid references public.branches(id) on delete restrict,
  dose_no         int not null default 1 check (dose_no > 0),
  given_on        date not null,
  visit_id        uuid references public.medical_visits(id) on delete set null,
  visit_item_id   uuid references public.medical_visit_items(id) on delete set null,
  lot_id          uuid references public.stock_lots(id) on delete set null,
  -- The batch is copied: a recall can find the pets even after the lot row is gone.
  lot_no          text,
  expiry_date     date,
  is_external     boolean not null default false,
  external_place  text,
  vet_name        text,
  next_due_on     date,
  reminded_at     timestamptz,
  reminded_by     uuid references auth.users(id) on delete set null,
  remind_note     text,
  voided_at       timestamptz,
  void_reason     text,
  created_by      uuid references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  constraint vaccinations_origin check (
    (is_external and branch_id is null and visit_id is null)
    or (not is_external and branch_id is not null)
  )
);
create index if not exists vaccinations_pet_idx on public.vaccinations (pet_id, given_on desc);
create index if not exists vaccinations_due_idx on public.vaccinations (next_due_on) where voided_at is null and next_due_on is not null;
create index if not exists vaccinations_item_idx on public.vaccinations (visit_item_id) where visit_item_id is not null;
create index if not exists vaccinations_lot_idx on public.vaccinations (lot_id) where lot_id is not null;

-- A line of the visit can point at the shot it came from.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'medical_visit_items_vaccination_fk') then
    alter table public.medical_visit_items
      add constraint medical_visit_items_vaccination_fk
      foreign key (vaccination_id) references public.vaccinations(id) on delete set null;
  end if;
end;
$$;

alter table public.vaccinations enable row level security;
drop policy if exists "medical read" on public.vaccinations;
create policy "medical read" on public.vaccinations for select to authenticated
  using ((select public.can_medical('VIEW')));
revoke insert, update, delete on public.vaccinations from anon, authenticated;
revoke all on public.vaccinations from anon;

-- ------------------------------------------------------------------ protocol
-- The day the next shot is due: another shot of the basic series is due `series_interval_days`
-- later; the last shot of the series (and every booster) is followed by `booster_interval_days`;
-- null when the type has no reminder.
create or replace function public.medical_next_due(p_type uuid, p_dose_no int, p_given_on date) returns date
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_dose_no < t.series_doses then p_given_on + t.series_interval_days
    when t.booster_interval_days is not null then p_given_on + t.booster_interval_days
  end
  from public.vaccine_types t where t.id = p_type;
$$;

revoke execute on function public.medical_next_due(uuid, int, date) from public, anon, authenticated;

-- The shot number a pet is due for: how many valid shots of this type it has, plus one.
create or replace function public.medical_next_dose_no(p_pet uuid, p_type uuid) returns int
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int + 1 from public.vaccinations
  where pet_id = p_pet and vaccine_type_id = p_type and voided_at is null;
$$;

revoke execute on function public.medical_next_dose_no(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------- lots
-- The batches of the vaccine's product that can be used at a branch: unexpired, in stock, the one
-- that expires first on top (FEFO). [{ id, lot_no, expiry_date, qty_on_hand }]
create or replace function public.vaccine_lots(p_branch uuid, p_vaccine_type uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_product uuid;
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select product_id into v_product from public.vaccine_types where id = p_vaccine_type;
  if v_product is null then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id, 'lot_no', l.lot_no, 'expiry_date', l.expiry_date, 'qty_on_hand', l.qty_on_hand
    ) order by l.expiry_date nulls last, l.received_at)
    from public.stock_lots l
    where l.branch_id = p_branch and l.product_id = v_product and l.qty_on_hand > 0
      and (l.expiry_date is null or l.expiry_date >= public.business_date())
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.vaccine_lots(uuid, uuid) from public, anon;
grant execute on function public.vaccine_lots(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------- give a shot
-- p: { vaccine_type_id, lot_id?, dose_no?, next_due_on? }
-- A shot of a type that has a product also puts that product on the visit as a charged line, from
-- the chosen batch (else the one that expires first). Returns { id, item_id, warnings }.
create or replace function public.give_vaccination(p_visit uuid, p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid     uuid := (select auth.uid());
  v_visit   public.medical_visits;
  v_type    public.vaccine_types;
  v_pet     public.pets;
  v_lot     public.stock_lots;
  v_product public.products;
  v_dose    int;
  v_today   date := public.business_date();
  v_due     date;
  v_id      uuid;
  v_item    uuid;
  v_name    text;
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
  select * into v_type from public.vaccine_types where id = nullif(p ->> 'vaccine_type_id', '')::uuid and is_active;
  if not found then
    raise exception 'vaccine type is not available' using errcode = 'P0002', hint = 'no_vaccine';
  end if;
  select * into v_pet from public.pets where id = v_visit.pet_id;

  v_dose := coalesce(nullif(p ->> 'dose_no', '')::int, public.medical_next_dose_no(v_pet.id, v_type.id));
  if v_dose <= 0 then
    raise exception 'bad dose number' using errcode = '22023', hint = 'bad_input';
  end if;
  v_due := case when p ? 'next_due_on' then nullif(p ->> 'next_due_on', '')::date
                else public.medical_next_due(v_type.id, v_dose, v_today) end;

  if cardinality(v_type.species_ids) > 0 and not (v_pet.species_id = any (v_type.species_ids)) then
    v_warnings := v_warnings || to_jsonb('species_mismatch'::text);
  end if;
  if v_type.min_age_weeks is not null and v_pet.birth_date is not null
     and v_pet.birth_date > v_today - (v_type.min_age_weeks * 7) then
    v_warnings := v_warnings || to_jsonb('too_young'::text);
  end if;

  if v_type.product_id is not null then
    select * into v_product from public.products where id = v_type.product_id;
    if nullif(p ->> 'lot_id', '') is not null then
      select * into v_lot from public.stock_lots
      where id = (p ->> 'lot_id')::uuid and branch_id = v_visit.branch_id and product_id = v_type.product_id
        and qty_on_hand > 0 and (expiry_date is null or expiry_date >= v_today);
    else
      select * into v_lot from public.stock_lots
      where branch_id = v_visit.branch_id and product_id = v_type.product_id
        and qty_on_hand > 0 and (expiry_date is null or expiry_date >= v_today)
      order by expiry_date nulls last, received_at limit 1;
    end if;
    if v_lot.id is null then
      raise exception 'no usable batch in stock' using errcode = 'P0001', hint = 'no_lot', detail = v_type.name;
    end if;
  end if;

  insert into public.vaccinations (
    pet_id, vaccine_type_id, branch_id, dose_no, given_on, visit_id, lot_id, lot_no, expiry_date,
    vet_name, next_due_on, created_by
  ) values (
    v_pet.id, v_type.id, v_visit.branch_id, v_dose, v_today, p_visit, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
    coalesce(v_visit.vet_name, public.staff_display_name(v_uid)), v_due, v_uid
  ) returning id into v_id;

  if v_type.product_id is not null then
    v_name := v_type.name || ' (' || v_dose || ')';
    insert into public.medical_visit_items (
      visit_id, branch_id, kind, product_id, unit_name, name, qty, unit_price, amount,
      lot_id, vaccination_id, created_by, created_by_name
    ) values (
      p_visit, v_visit.branch_id, 'product', v_product.id, v_product.unit, v_name, 1,
      coalesce(public.product_unit_price(v_product.id, v_visit.branch_id, null), 0),
      round(coalesce(public.product_unit_price(v_product.id, v_visit.branch_id, null), 0), 2),
      v_lot.id, v_id, v_uid, public.staff_display_name(v_uid)
    ) returning id into v_item;
    update public.vaccinations set visit_item_id = v_item where id = v_id;
  end if;

  perform public.medical_refresh_status(p_visit);
  return jsonb_build_object('id', v_id, 'item_id', v_item, 'warnings', v_warnings);
end;
$$;

revoke execute on function public.give_vaccination(uuid, jsonb) from public, anon;
grant execute on function public.give_vaccination(uuid, jsonb) to authenticated;

-- --------------------------------------------------------------- shot elsewhere
-- p: { vaccine_type_id, given_on, external_place?, lot_no?, expiry_date?, dose_no?, vet_name?, next_due_on? }
-- A shot given at another clinic: no visit, no stock, no charge. Returns the id.
create or replace function public.add_external_vaccination(p_pet uuid, p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_type  public.vaccine_types;
  v_given date := nullif(p ->> 'given_on', '')::date;
  v_dose  int;
  v_due   date;
  v_id    uuid;
begin
  if not public.can_medical('CREATE') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not exists (select 1 from public.pets where id = p_pet) then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_type from public.vaccine_types where id = nullif(p ->> 'vaccine_type_id', '')::uuid and is_active;
  if not found then
    raise exception 'vaccine type is not available' using errcode = 'P0002', hint = 'no_vaccine';
  end if;
  if v_given is null then
    raise exception 'the day of the shot is needed' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_given > public.business_date() then
    raise exception 'the shot cannot be in the future' using errcode = '22023', hint = 'future_date';
  end if;
  v_dose := coalesce(nullif(p ->> 'dose_no', '')::int, public.medical_next_dose_no(p_pet, v_type.id));
  if v_dose <= 0 then
    raise exception 'bad dose number' using errcode = '22023', hint = 'bad_input';
  end if;
  v_due := case when p ? 'next_due_on' then nullif(p ->> 'next_due_on', '')::date
                else public.medical_next_due(v_type.id, v_dose, v_given) end;

  insert into public.vaccinations (
    pet_id, vaccine_type_id, dose_no, given_on, lot_no, expiry_date, is_external, external_place,
    vet_name, next_due_on, created_by
  ) values (
    p_pet, v_type.id, v_dose, v_given, nullif(btrim(p ->> 'lot_no'), ''), nullif(p ->> 'expiry_date', '')::date,
    true, nullif(btrim(p ->> 'external_place'), ''), nullif(btrim(p ->> 'vet_name'), ''), v_due, v_uid
  ) returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.add_external_vaccination(uuid, jsonb) from public, anon;
grant execute on function public.add_external_vaccination(uuid, jsonb) to authenticated;

-- ----------------------------------------------------------------------- void
-- Strikes out a wrong entry. A shot typed in from elsewhere, or one given at the clinic whose
-- charge has not gone on an invoice (that charge is removed with it).
create or replace function public.void_vaccination(p_id uuid, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shot public.vaccinations;
  v_item public.medical_visit_items;
begin
  select * into v_shot from public.vaccinations where id = p_id for update;
  if not found then
    raise exception 'shot not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_shot.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_shot.voided_at is not null then
    raise exception 'the shot is already voided' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_shot.visit_item_id is not null then
    select * into v_item from public.medical_visit_items where id = v_shot.visit_item_id for update;
    if found and v_item.invoice_line_id is not null then
      raise exception 'the shot is already billed' using errcode = 'P0001', hint = 'not_editable';
    end if;
    delete from public.medical_visit_items where id = v_shot.visit_item_id;
  end if;
  update public.vaccinations set voided_at = now(), void_reason = nullif(btrim(p_reason), '') where id = p_id;
  if v_shot.visit_id is not null then
    perform public.medical_refresh_status(v_shot.visit_id);
  end if;
end;
$$;

revoke execute on function public.void_vaccination(uuid, text) from public, anon;
grant execute on function public.void_vaccination(uuid, text) to authenticated;

-- ------------------------------------------------------------------- the book
-- A pet's e-book, one entry per vaccine type it has had a valid shot of, newest type first. The
-- state follows the latest shot: `overdue` past its due day, `due_soon` within the next 14 days,
-- `ok` otherwise (also when that shot has no reminder).
-- [{ vaccine_type_id, name, kind, state, next_due_on, last_given_on,
--    doses: [{ id, dose_no, given_on, lot_no, expiry_date, is_external, external_place, vet_name,
--              next_due_on, branch_name, visit_id, voided_at }] }]
create or replace function public.pet_vaccinations(p_pet uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := public.business_date();
begin
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(entry order by (entry ->> 'last_given_on') desc, entry ->> 'name')
    from (
      select jsonb_build_object(
        'vaccine_type_id', t.id,
        'name', t.name,
        'kind', t.kind,
        'last_given_on', last.given_on,
        'next_due_on', last.next_due_on,
        'state', case
          when last.next_due_on is null then 'ok'
          when last.next_due_on < v_today then 'overdue'
          when last.next_due_on <= v_today + 14 then 'due_soon'
          else 'ok' end,
        'doses', (
          select jsonb_agg(jsonb_build_object(
            'id', d.id, 'dose_no', d.dose_no, 'given_on', d.given_on, 'lot_no', d.lot_no,
            'expiry_date', d.expiry_date, 'is_external', d.is_external, 'external_place', d.external_place,
            'vet_name', d.vet_name, 'next_due_on', d.next_due_on, 'visit_id', d.visit_id,
            'branch_name', (select b.name from public.branches b where b.id = d.branch_id),
            'voided_at', d.voided_at
          ) order by d.given_on desc, d.created_at desc)
          from public.vaccinations d where d.pet_id = p_pet and d.vaccine_type_id = t.id
        )
      ) as entry
      from public.vaccine_types t
      join lateral (
        select v.given_on, v.next_due_on from public.vaccinations v
        where v.pet_id = p_pet and v.vaccine_type_id = t.id and v.voided_at is null
        order by v.given_on desc, v.created_at desc limit 1
      ) last on true
    ) e
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.pet_vaccinations(uuid) from public, anon;
grant execute on function public.pet_vaccinations(uuid) to authenticated;

-- The step 3 function again: taking a line off also voids the shot it came from.
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
  -- Taking a shot off the bill takes it out of the e-book too (kept, but struck out).
  update public.vaccinations set voided_at = now(), void_reason = 'line removed'
  where visit_item_id = p_id and voided_at is null;
  delete from public.medical_visit_items where id = p_id;
  perform public.medical_refresh_status(v_item.visit_id);
end;
$$;

revoke execute on function public.remove_medical_item(uuid) from public, anon;
grant execute on function public.remove_medical_item(uuid) to authenticated;

notify pgrst, 'reload schema';
