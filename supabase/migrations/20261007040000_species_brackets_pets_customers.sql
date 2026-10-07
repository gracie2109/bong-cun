-- Phase 0 base schema (docs: pet-care-plan/ke-hoach-ba-kien-truc.md, sections 2.4, 2.5, 3.2).
--
--  1. `pets` was a species catalog (Chó, Mèo) -> renamed `species`; a new `pets` table holds
--     one row per animal, with `customers` and `pet_owners` (n-n).
--  2. `pet_weights` (labels only, gaps and overlaps) -> `weight_brackets`: per species, with
--     min_kg / max_kg and a no-overlap constraint, so a weight in kg resolves to one bracket.
--  3. Spa prices can be overridden per branch (branch_id NULL = shared price).
--  4. Species, services and combos are archived (is_active) instead of deleted; links that used
--     to cascade on species delete now restrict.
--
-- The existing price rows are kept. Old brackets are mapped to the new ranges below; the old
-- "Từ 2-4kg" becomes 2-5 kg and the old "Trên 5kg" becomes 5-10 kg (it overlapped the next two).

create extension if not exists btree_gist with schema extensions;

-- ------------------------------------------------------------------ branches
create table public.branches (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique check (code ~ '^[A-Z0-9]{2,8}$'),
  name       text not null,
  address    text,
  phone      text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
insert into public.branches (code, name) values ('CS01', 'Cơ sở chính');

-- -------------------------------------------------- pets -> species (rename)
alter table public.pets rename to species;
alter table public.species rename constraint pets_pkey to species_pkey;
alter table public.species rename constraint pets_name_key to species_name_key;
alter table public.species add column is_active boolean not null default true;
-- The two sample species from seed.sql get their Vietnamese names; real data is left alone.
update public.species set name = 'Chó' where name = 'Dog' and not exists (select 1 from public.species where name = 'Chó');
update public.species set name = 'Mèo' where name = 'Cat' and not exists (select 1 from public.species where name = 'Mèo');

alter table public.pet_service_pets rename to service_species;
alter table public.service_species rename column pet_id to species_id;
alter table public.service_species rename constraint pet_service_pets_pkey to service_species_pkey;
alter table public.service_species rename constraint pet_service_pets_service_id_fkey to service_species_service_id_fkey;
alter table public.service_species drop constraint pet_service_pets_pet_id_fkey;
alter table public.service_species
  add constraint service_species_species_id_fkey
  foreign key (species_id) references public.species(id) on delete restrict;
alter index public.pet_service_pets_pet_idx rename to service_species_species_idx;

alter table public.combo_pets rename to combo_species;
alter table public.combo_species rename column pet_id to species_id;
alter table public.combo_species rename constraint combo_pets_pkey to combo_species_pkey;
alter table public.combo_species rename constraint combo_pets_combo_id_fkey to combo_species_combo_id_fkey;
alter table public.combo_species drop constraint combo_pets_pet_id_fkey;
alter table public.combo_species
  add constraint combo_species_species_id_fkey
  foreign key (species_id) references public.species(id) on delete restrict;
alter index public.combo_pets_pet_idx rename to combo_species_species_idx;

alter table public.pet_services add column is_active boolean not null default true;
alter table public.pet_service_combos add column is_active boolean not null default true;

-- ---------------------------------------------- pet_weights -> weight_brackets
create table public.weight_brackets (
  id         uuid primary key default gen_random_uuid(),
  species_id uuid not null references public.species(id) on delete restrict,
  label      text not null check (length(btrim(label)) > 0),
  min_kg     numeric(6,2) not null check (min_kg >= 0),
  max_kg     numeric(6,2),
  sort_order int not null default 0,
  legacy_id  text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint weight_brackets_range_check check (max_kg is null or max_kg > min_kg),
  -- Checked at commit so a save can shift several ranges at once. max_kg NULL = no upper limit.
  constraint weight_brackets_no_overlap
    exclude using gist (species_id with =, numrange(min_kg, max_kg, '[)') with &&)
    deferrable initially deferred
);
create index weight_brackets_species_idx on public.weight_brackets (species_id, min_kg);

create temp table bracket_map (legacy_id text, label text, min_kg numeric, max_kg numeric, sort_order int);
insert into bracket_map values
  ('lessthan2',  'Dưới 2 kg', 0,  2,  1),
  ('from2to4',   '2-5 kg',    2,  5,  2),
  ('morethan5',  '5-10 kg',   5,  10, 3),
  ('from10to14', '10-15 kg',  10, 15, 4),
  ('from15to14', '15-20 kg',  15, 20, 5);

insert into public.weight_brackets (species_id, label, min_kg, max_kg, sort_order, legacy_id)
select s.id, m.label, m.min_kg, m.max_kg, m.sort_order, m.legacy_id
from public.species s cross join bracket_map m;

insert into public.weight_brackets (species_id, label, min_kg, max_kg, sort_order)
select id, 'Trên 20 kg', 20, null, 6 from public.species;

drop table bracket_map;

-- ------------------------------------------------------- pet_service_prices
alter table public.pet_service_prices rename column pet_id to species_id;
alter table public.pet_service_prices drop constraint pet_service_prices_pet_id_fkey;
alter table public.pet_service_prices
  add constraint pet_service_prices_species_id_fkey
  foreign key (species_id) references public.species(id) on delete restrict;

alter table public.pet_service_prices
  add column bracket_id uuid references public.weight_brackets(id) on delete cascade,
  add column branch_id  uuid references public.branches(id) on delete cascade;

update public.pet_service_prices pr
set bracket_id = wb.id
from public.weight_brackets wb
where wb.species_id = pr.species_id and wb.legacy_id = pr.weight_id;

alter table public.pet_service_prices alter column bracket_id set not null;
alter table public.pet_service_prices drop constraint pet_service_prices_pet_id_service_id_weight_id_key;
alter table public.pet_service_prices drop column weight_id;

-- NULL branch_id is the shared price; a row with a branch overrides it for that branch.
alter table public.pet_service_prices
  add constraint pet_service_prices_unique
  unique nulls not distinct (species_id, service_id, bracket_id, branch_id);
create index pet_service_prices_bracket_idx on public.pet_service_prices (bracket_id);

alter table public.weight_brackets drop column legacy_id;
drop table public.pet_weights;

-- -------------------------------------------------------- customers and pets
create table public.customers (
  id           uuid primary key default gen_random_uuid(),
  full_name    text not null check (length(btrim(full_name)) > 0),
  phone        text not null check (length(regexp_replace(phone, '\D', '', 'g')) between 8 and 15),
  phone_digits text generated always as (regexp_replace(phone, '\D', '', 'g')) stored,
  email        text,
  note         text,
  -- Optional link to a web account; walk-in customers have none.
  user_id      uuid unique references public.users(id) on delete set null,
  is_active    boolean not null default true,
  created_by   uuid default auth.uid() references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint customers_phone_digits_key unique (phone_digits)
);

create table public.pets (
  id             uuid primary key default gen_random_uuid(),
  species_id     uuid not null references public.species(id) on delete restrict,
  name           text not null check (length(btrim(name)) > 0),
  breed          text,
  sex            text not null default 'unknown' check (sex in ('male', 'female', 'unknown')),
  neutered       boolean not null default false,
  birth_date     date,
  microchip      text unique,
  photo_url      text,
  allergies      text,
  behavior_notes text,
  status         text not null default 'active' check (status in ('active', 'deceased', 'archived')),
  created_by     uuid default auth.uid() references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index pets_species_idx on public.pets (species_id);
create index pets_name_idx    on public.pets (lower(name));

-- A pet can have several owners and a customer several pets. Medical records follow the pet,
-- invoices follow the customer, so a change of owner closes the link instead of editing it.
create table public.pet_owners (
  pet_id      uuid not null references public.pets(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete restrict,
  role        text not null default 'primary' check (role in ('primary', 'co_owner')),
  from_date   date not null default current_date,
  to_date     date,
  primary key (pet_id, customer_id),
  check (to_date is null or to_date >= from_date)
);
create index pet_owners_customer_idx on public.pet_owners (customer_id);
create unique index pet_owners_one_primary_idx
  on public.pet_owners (pet_id) where role = 'primary' and to_date is null;

create table public.pet_weight_logs (
  id          uuid primary key default gen_random_uuid(),
  pet_id      uuid not null references public.pets(id) on delete cascade,
  weight_kg   numeric(6,2) not null check (weight_kg > 0),
  measured_at timestamptz not null default now(),
  note        text,
  created_by  uuid default auth.uid() references auth.users(id) on delete set null
);
create index pet_weight_logs_pet_idx on public.pet_weight_logs (pet_id, measured_at desc);

do $$
declare t text;
begin
  foreach t in array array['branches', 'weight_brackets', 'customers', 'pets'] loop
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- --------------------------------------------------------------------- RLS
create function public.is_staff() returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select auth.jwt() ->> 'user_role') in ('admin', 'superAdmin', 'cashier'), false);
$$;

-- Branches and weight brackets are public reference data like the rest of the catalog.
do $$
declare t text;
begin
  foreach t in array array['branches', 'weight_brackets'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "public read" on public.%I for select to anon, authenticated using (true)', t);
    execute format('create policy "admin insert" on public.%I for insert to authenticated with check ((select public.is_admin()))', t);
    execute format('create policy "admin update" on public.%I for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()))', t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using ((select public.is_admin()))', t);
  end loop;
end;
$$;

-- Customers and their pets are personal data: staff only. Cashiers work the counter, so they
-- can add and edit; only admins delete.
do $$
declare t text;
begin
  foreach t in array array['customers', 'pets', 'pet_owners', 'pet_weight_logs'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "staff read" on public.%I for select to authenticated using ((select public.is_staff()))', t);
    execute format('create policy "staff insert" on public.%I for insert to authenticated with check ((select public.is_staff()))', t);
    execute format('create policy "staff update" on public.%I for update to authenticated using ((select public.is_staff())) with check ((select public.is_staff()))', t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using ((select public.is_admin()))', t);
  end loop;
end;
$$;

-- ------------------------------------------------------------ list view
-- One row per pet for the list screen. security_invoker keeps the staff-only policies in force.
create view public.pet_overview with (security_invoker = true) as
select
  p.id,
  p.name,
  p.species_id,
  s.name        as species_name,
  s.icon        as species_icon,
  p.breed,
  p.sex,
  p.neutered,
  p.birth_date,
  p.photo_url,
  p.allergies,
  p.behavior_notes,
  p.status,
  p.created_at,
  w.weight_kg,
  w.measured_at as weight_measured_at,
  b.id          as bracket_id,
  b.label       as bracket_label,
  o.customer_id as owner_id,
  c.full_name   as owner_name,
  c.phone       as owner_phone,
  (select count(*) from public.pet_owners po
    where po.pet_id = p.id and po.to_date is null) as owner_count
from public.pets p
join public.species s on s.id = p.species_id
left join lateral (
  select l.weight_kg, l.measured_at
  from public.pet_weight_logs l
  where l.pet_id = p.id
  order by l.measured_at desc
  limit 1
) w on true
left join public.weight_brackets b
  on b.species_id = p.species_id
 and w.weight_kg >= b.min_kg
 and (b.max_kg is null or w.weight_kg < b.max_kg)
left join lateral (
  select po.customer_id
  from public.pet_owners po
  where po.pet_id = p.id and po.to_date is null
  order by (po.role = 'primary') desc, po.from_date
  limit 1
) o on true
left join public.customers c on c.id = o.customer_id;

-- ------------------------------------------------------------------ functions
-- Default brackets for a species with none (used by save_species and the seed).
create function public.seed_default_weight_brackets(p_species_id uuid) returns void
language sql
set search_path = ''
as $$
  insert into public.weight_brackets (species_id, label, min_kg, max_kg, sort_order)
  select p_species_id, v.label, v.min_kg, v.max_kg, v.sort_order
  from (values
    ('Dưới 2 kg', 0, 2, 1), ('2-5 kg', 2, 5, 2), ('5-10 kg', 5, 10, 3),
    ('10-15 kg', 10, 15, 4), ('15-20 kg', 15, 20, 5), ('Trên 20 kg', 20, null::numeric, 6)
  ) as v(label, min_kg, max_kg, sort_order)
  where not exists (select 1 from public.weight_brackets where species_id = p_species_id);
$$;

-- p: { name, icon, description, is_active }
create function public.save_species(p jsonb, p_id uuid default null) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if p_id is null then
    insert into public.species (name, icon, description, is_active)
    values (
      p ->> 'name',
      nullif(p ->> 'icon', ''),
      nullif(p ->> 'description', ''),
      coalesce((p ->> 'is_active')::boolean, true)
    )
    returning id into v_id;
    perform public.seed_default_weight_brackets(v_id);
  else
    update public.species set
      name        = p ->> 'name',
      icon        = nullif(p ->> 'icon', ''),
      description = nullif(p ->> 'description', ''),
      is_active   = coalesce((p ->> 'is_active')::boolean, true)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'species % not found', p_id using errcode = 'P0002';
    end if;
  end if;
  return v_id;
end;
$$;

-- Replaces the brackets of one species. p_rows: [{ id?, label, min_kg, max_kg }], max_kg null =
-- no upper limit. A bracket missing from p_rows is deleted together with its prices. Overlaps
-- are rejected when the transaction commits (see weight_brackets_no_overlap).
create function public.save_weight_brackets(p_species_id uuid, p_rows jsonb) returns void
language plpgsql
set search_path = ''
as $$
begin
  delete from public.weight_brackets
  where species_id = p_species_id
    and id not in (
      select (r.v ->> 'id')::uuid
      from jsonb_array_elements(p_rows) as r(v)
      where nullif(r.v ->> 'id', '') is not null
    );

  update public.weight_brackets b set
    label      = r.v ->> 'label',
    min_kg     = (r.v ->> 'min_kg')::numeric,
    max_kg     = nullif(r.v ->> 'max_kg', '')::numeric,
    sort_order = r.ord::int
  from jsonb_array_elements(p_rows) with ordinality as r(v, ord)
  where b.species_id = p_species_id
    and nullif(r.v ->> 'id', '') is not null
    and b.id = (r.v ->> 'id')::uuid;

  insert into public.weight_brackets (species_id, label, min_kg, max_kg, sort_order)
  select p_species_id, r.v ->> 'label', (r.v ->> 'min_kg')::numeric,
         nullif(r.v ->> 'max_kg', '')::numeric, r.ord::int
  from jsonb_array_elements(p_rows) with ordinality as r(v, ord)
  where nullif(r.v ->> 'id', '') is null;
end;
$$;

-- p: { name, description, type, unit, general_price, duration_minutes, is_show, is_active,
--      species_ids: [...] }
-- Species dropped from the service lose the prices set for them.
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
      (name, description, type, unit, general_price, duration_minutes, is_show, is_active)
    values (
      p ->> 'name',
      nullif(p ->> 'description', ''),
      nullif(p ->> 'type', ''),
      nullif(p ->> 'unit', ''),
      nullif(p ->> 'general_price', '')::numeric,
      nullif(p ->> 'duration_minutes', '')::int,
      coalesce((p ->> 'is_show')::boolean, true),
      coalesce((p ->> 'is_active')::boolean, true)
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
      is_active        = coalesce((p ->> 'is_active')::boolean, true)
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

-- p: { name, description, origin_price, price, duration_minutes, mark_as_id, mark_start,
--      mark_end, status, is_active, species_ids: [...], service_ids: [...] }
-- Every service in a combo must be offered for every species of the combo.
create or replace function public.save_pet_combo(p jsonb, p_id uuid default null) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
  v_species uuid[];
  v_services uuid[];
  v_missing text;
begin
  select coalesce(array_agg(x::uuid), '{}')
  into v_species
  from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);

  select coalesce(array_agg(x::uuid), '{}')
  into v_services
  from jsonb_array_elements_text(coalesce(p -> 'service_ids', '[]'::jsonb)) as t(x);

  select string_agg(distinct sv.name || ' / ' || sp.name, ', ')
  into v_missing
  from unnest(v_services) as s(service_id)
  cross join unnest(v_species) as k(species_id)
  join public.pet_services sv on sv.id = s.service_id
  join public.species sp on sp.id = k.species_id
  where not exists (
    select 1 from public.service_species ss
    where ss.service_id = s.service_id and ss.species_id = k.species_id
  );

  if v_missing is not null then
    raise exception 'service not offered for species: %', v_missing using errcode = '23514';
  end if;

  if p_id is null then
    insert into public.pet_service_combos
      (name, description, origin_price, price, duration_minutes, mark_as_id,
       mark_start, mark_end, status, is_active)
    values (
      p ->> 'name',
      nullif(p ->> 'description', ''),
      nullif(p ->> 'origin_price', '')::numeric,
      nullif(p ->> 'price', '')::numeric,
      nullif(p ->> 'duration_minutes', '')::int,
      nullif(p ->> 'mark_as_id', ''),
      nullif(p ->> 'mark_start', '')::timestamptz,
      nullif(p ->> 'mark_end', '')::timestamptz,
      coalesce(nullif(p ->> 'status', '')::smallint, 1),
      coalesce((p ->> 'is_active')::boolean, true)
    )
    returning id into v_id;
  else
    update public.pet_service_combos set
      name             = p ->> 'name',
      description      = nullif(p ->> 'description', ''),
      origin_price     = nullif(p ->> 'origin_price', '')::numeric,
      price            = nullif(p ->> 'price', '')::numeric,
      duration_minutes = nullif(p ->> 'duration_minutes', '')::int,
      mark_as_id       = nullif(p ->> 'mark_as_id', ''),
      mark_start       = nullif(p ->> 'mark_start', '')::timestamptz,
      mark_end         = nullif(p ->> 'mark_end', '')::timestamptz,
      status           = coalesce(nullif(p ->> 'status', '')::smallint, 1),
      is_active        = coalesce((p ->> 'is_active')::boolean, true)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'combo % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  delete from public.combo_species where combo_id = v_id;
  insert into public.combo_species (combo_id, species_id)
  select v_id, s from unnest(v_species) as s;

  delete from public.combo_services where combo_id = v_id;
  insert into public.combo_services (combo_id, service_id)
  select v_id, s from unnest(v_services) as s;

  return v_id;
end;
$$;

-- Replaces the prices of one service for one species, in the shared scope (p_branch_id null) or
-- as overrides for one branch. p_rows: [{ bracket_id, price }]; an empty price removes it.
drop function public.save_service_prices(uuid, uuid, jsonb);
create function public.save_service_prices(
  p_species_id uuid,
  p_service_id uuid,
  p_rows jsonb,
  p_branch_id uuid default null
) returns void
language plpgsql
set search_path = ''
as $$
declare
  v_type text;
begin
  select type into v_type from public.pet_services where id = p_service_id;
  if v_type is distinct from 'by_weight' then
    raise exception 'service % is not priced by weight', p_service_id using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.service_species
    where service_id = p_service_id and species_id = p_species_id
  ) then
    raise exception 'service % is not offered for species %', p_service_id, p_species_id
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_rows) as r(v)
    where nullif(r.v ->> 'price', '') is not null
      and not exists (
        select 1 from public.weight_brackets b
        where b.id = (r.v ->> 'bracket_id')::uuid and b.species_id = p_species_id
      )
  ) then
    raise exception 'bracket does not belong to species %', p_species_id using errcode = '23514';
  end if;

  delete from public.pet_service_prices
  where species_id = p_species_id
    and service_id = p_service_id
    and branch_id is not distinct from p_branch_id
    and bracket_id not in (
      select (r.v ->> 'bracket_id')::uuid
      from jsonb_array_elements(p_rows) as r(v)
      where nullif(r.v ->> 'price', '') is not null
    );

  insert into public.pet_service_prices (species_id, service_id, bracket_id, branch_id, price)
  select p_species_id, p_service_id, (r.v ->> 'bracket_id')::uuid, p_branch_id,
         (r.v ->> 'price')::numeric
  from jsonb_array_elements(p_rows) as r(v)
  where nullif(r.v ->> 'price', '') is not null
  on conflict on constraint pet_service_prices_unique do update set price = excluded.price;
end;
$$;

-- The price of a service for an animal of a given weight: a branch override first, then the
-- shared price; NULL when the service is not priced for that weight yet.
create function public.get_service_price(
  p_species_id uuid,
  p_service_id uuid,
  p_weight_kg numeric,
  p_branch_id uuid default null
) returns numeric
language sql
stable
set search_path = ''
as $$
  select case
    when sv.type = 'all' then sv.general_price
    else (
      select pr.price
      from public.weight_brackets b
      join public.pet_service_prices pr
        on pr.bracket_id = b.id
       and pr.service_id = sv.id
       and (pr.branch_id is null or pr.branch_id = p_branch_id)
      where b.species_id = p_species_id
        and p_weight_kg >= b.min_kg
        and (b.max_kg is null or p_weight_kg < b.max_kg)
      order by (pr.branch_id is not null) desc
      limit 1
    )
  end
  from public.pet_services sv
  where sv.id = p_service_id;
$$;

-- Counter registration in one transaction. A customer is matched by phone number, so the same
-- person is never created twice. p: { customer: { id?, full_name, phone, email? },
-- pet: { species_id, name, breed, sex, neutered, birth_date, microchip, photo_url, allergies,
-- behavior_notes }, weight_kg? }
create function public.register_pet(p jsonb) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_customer uuid;
  v_pet uuid;
  v_weight numeric := nullif(p ->> 'weight_kg', '')::numeric;
begin
  v_customer := nullif(p #>> '{customer,id}', '')::uuid;

  if v_customer is null then
    insert into public.customers (full_name, phone, email)
    values (
      p #>> '{customer,full_name}',
      p #>> '{customer,phone}',
      nullif(p #>> '{customer,email}', '')
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  end if;

  insert into public.pets
    (species_id, name, breed, sex, neutered, birth_date, microchip, photo_url, allergies, behavior_notes)
  values (
    (p #>> '{pet,species_id}')::uuid,
    p #>> '{pet,name}',
    nullif(p #>> '{pet,breed}', ''),
    coalesce(nullif(p #>> '{pet,sex}', ''), 'unknown'),
    coalesce((p #>> '{pet,neutered}')::boolean, false),
    nullif(p #>> '{pet,birth_date}', '')::date,
    nullif(p #>> '{pet,microchip}', ''),
    nullif(p #>> '{pet,photo_url}', ''),
    nullif(p #>> '{pet,allergies}', ''),
    nullif(p #>> '{pet,behavior_notes}', '')
  )
  returning id into v_pet;

  insert into public.pet_owners (pet_id, customer_id, role) values (v_pet, v_customer, 'primary');

  if v_weight is not null then
    insert into public.pet_weight_logs (pet_id, weight_kg) values (v_pet, v_weight);
  end if;

  return v_pet;
end;
$$;

revoke execute on function public.seed_default_weight_brackets(uuid) from public, anon;
revoke execute on function public.save_species(jsonb, uuid) from public, anon;
revoke execute on function public.save_weight_brackets(uuid, jsonb) from public, anon;
revoke execute on function public.save_pet_service(jsonb, uuid) from public, anon;
revoke execute on function public.save_pet_combo(jsonb, uuid) from public, anon;
revoke execute on function public.save_service_prices(uuid, uuid, jsonb, uuid) from public, anon;
revoke execute on function public.register_pet(jsonb) from public, anon;
revoke execute on function public.is_staff() from public, anon;
grant execute on function public.seed_default_weight_brackets(uuid) to authenticated;
grant execute on function public.save_species(jsonb, uuid) to authenticated;
grant execute on function public.save_weight_brackets(uuid, jsonb) to authenticated;
grant execute on function public.save_pet_service(jsonb, uuid) to authenticated;
grant execute on function public.save_pet_combo(jsonb, uuid) to authenticated;
grant execute on function public.save_service_prices(uuid, uuid, jsonb, uuid) to authenticated;
grant execute on function public.register_pet(jsonb) to authenticated;
grant execute on function public.is_staff() to authenticated;
-- Reading a price is public: the website shows it.
grant execute on function public.get_service_price(uuid, uuid, numeric, uuid) to anon, authenticated;
