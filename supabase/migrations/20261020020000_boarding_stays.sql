-- Pet hotel (boarding), step 2 (1/3): stays and the pets in them
-- (docs/khach-san-thu-cung.md, sections 4 and 5). Safe to run more than once.
--
-- Before: kennels exist but nothing can be booked into them.
-- After: a stay belongs to a customer at a branch and holds one row per pet with its kennel and
-- the nights it occupies it. The database refuses to put two stays in one kennel on the same
-- night, or one pet in two stays on the same night. Every write goes through the RPCs in
-- 20261020020100_boarding_booking.sql; the client only reads these tables (boarding: VIEW).
-- Runs after 20261020010100_boarding_settings_rpcs.sql.

-- -------------------------------------------------------------------- stays
create table if not exists public.boarding_stays (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  branch_id      uuid not null references public.branches(id) on delete restrict,
  customer_id    uuid not null references public.customers(id) on delete restrict,
  -- Copied at booking time so lists read without joining customers.
  customer_name  text not null,
  customer_phone text not null,
  status         text not null default 'booked'
                 check (status in ('booked', 'checked_in', 'checked_out', 'paid', 'cancelled', 'no_show')),
  planned_in_at  timestamptz not null,
  planned_out_at timestamptz not null,
  checked_in_at  timestamptz,
  checked_out_at timestamptz,
  source         text not null default 'counter' check (source in ('counter', 'phone', 'web')),
  emergency_phone text,
  note           text,
  cancelled_at   timestamptz,
  cancel_reason  text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (planned_out_at > planned_in_at)
);
create index if not exists boarding_stays_branch_in_idx on public.boarding_stays (branch_id, planned_in_at desc);
create index if not exists boarding_stays_customer_idx on public.boarding_stays (customer_id);

-- One row per pet of a stay.
create table if not exists public.boarding_stay_pets (
  id                  uuid primary key default gen_random_uuid(),
  stay_id             uuid not null references public.boarding_stays(id) on delete cascade,
  -- Same as the stay's branch; kept here so RLS and the kennel checks need no join.
  branch_id           uuid not null references public.branches(id) on delete restrict,
  line_no             int not null,
  pet_id              uuid not null references public.pets(id) on delete restrict,
  pet_name            text not null,
  kennel_type_id      uuid not null references public.kennel_types(id) on delete restrict,
  kennel_id           uuid not null references public.kennels(id) on delete restrict,
  -- The nights the kennel is occupied: [arrival date, departure date), Vietnam business dates.
  -- A pet dropped and collected on the same day uses [day, day + 1).
  nights              daterange not null check (not isempty(nights)),
  -- Nights charged: the date difference, or day_stay_nights for a same-day stay.
  charged_nights      numeric(5,1) not null check (charged_nights > 0),
  status              text not null default 'active' check (status in ('active', 'cancelled')),
  -- Second and later pets sharing a kennel pay extra_pet_night_price.
  is_extra_pet        boolean not null default false,
  est_night_price     numeric(14,2) not null check (est_night_price >= 0),
  -- Fixed at check-in; later price changes do not touch it.
  night_price         numeric(14,2) check (night_price >= 0),
  weight_kg           numeric(6,2) check (weight_kg > 0),
  vaccine_checked     boolean not null default false,
  vaccine_note        text,
  belongings          text,
  belongings_returned boolean not null default false,
  feeding             text,
  medication          text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (stay_id, line_no),
  -- A kennel holds one stay per night; pets of the same stay may share it (the RPC limits how many).
  constraint boarding_stay_pets_kennel_no_overlap
    exclude using gist (kennel_id with =, stay_id with <>, nights with &&)
    where (status = 'active'),
  -- A pet is in one stay per night.
  constraint boarding_stay_pets_pet_no_overlap
    exclude using gist (pet_id with =, nights with &&)
    where (status = 'active')
);
create index if not exists boarding_stay_pets_stay_idx on public.boarding_stay_pets (stay_id);
create index if not exists boarding_stay_pets_branch_nights_idx on public.boarding_stay_pets using gist (branch_id, nights);
create index if not exists boarding_stay_pets_kennel_idx on public.boarding_stay_pets (kennel_id);
create index if not exists boarding_stay_pets_pet_idx on public.boarding_stay_pets (pet_id);

do $$
declare t text;
begin
  foreach t in array array['boarding_stays', 'boarding_stay_pets'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ------------------------------------------------------------------------ RLS
alter table public.boarding_stays     enable row level security;
alter table public.boarding_stay_pets enable row level security;

drop policy if exists "boarding read" on public.boarding_stays;
create policy "boarding read" on public.boarding_stays for select to authenticated
  using ((select public.can_boarding('VIEW', branch_id)));

drop policy if exists "boarding read" on public.boarding_stay_pets;
create policy "boarding read" on public.boarding_stay_pets for select to authenticated
  using ((select public.can_boarding('VIEW', branch_id)));

revoke insert, update, delete on public.boarding_stays, public.boarding_stay_pets from anon, authenticated;
revoke all on public.boarding_stays, public.boarding_stay_pets from anon;

-- --------------------------------------------- kennel guards (re-created from step 1)
-- A kennel cannot change type while a stay that is not finished uses it (hint kennel_in_use).
create or replace function public.save_kennel(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_code text := nullif(btrim(p ->> 'code'), '');
  v_type uuid := nullif(p ->> 'kennel_type_id', '')::uuid;
  v_id uuid;
begin
  if p_id is not null then
    select branch_id into v_branch from public.kennels where id = p_id;
    if v_branch is null then
      raise exception 'kennel % not found', p_id using errcode = 'P0002', hint = 'not_found';
    end if;
  end if;
  if v_branch is null or not public.can_boarding('SETTING', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and (v_code is null or v_type is null) then
    raise exception 'code and kennel type are required' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_type is not null and not exists (select 1 from public.kennel_types where id = v_type) then
    raise exception 'kennel type not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_code is not null and exists (
    select 1 from public.kennels
    where branch_id = v_branch and lower(btrim(code)) = lower(v_code) and id is distinct from p_id
  ) then
    raise exception 'a kennel with this code exists at the branch' using errcode = '23505', hint = 'duplicate_code';
  end if;
  if p_id is not null and v_type is not null and exists (
    select 1 from public.kennels where id = p_id and kennel_type_id <> v_type
  ) and exists (
    select 1
    from public.boarding_stay_pets sp
    join public.boarding_stays s on s.id = sp.stay_id
    where sp.kennel_id = p_id and sp.status = 'active' and s.status in ('booked', 'checked_in')
  ) then
    raise exception 'the kennel has stays that are not finished' using errcode = 'P0001', hint = 'kennel_in_use';
  end if;

  if p_id is null then
    insert into public.kennels (branch_id, kennel_type_id, code, name, status, is_active, sort_order)
    values (
      v_branch, v_type, v_code,
      nullif(btrim(p ->> 'name'), ''),
      coalesce(nullif(p ->> 'status', ''), 'ready'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.kennels set
      kennel_type_id = coalesce(v_type, kennel_type_id),
      code = coalesce(v_code, code),
      name = case when p ? 'name' then nullif(btrim(p ->> 'name'), '') else name end,
      status = coalesce(nullif(p ->> 'status', ''), status),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

revoke execute on function public.save_kennel(jsonb, uuid) from public, anon;
grant execute on function public.save_kennel(jsonb, uuid) to authenticated;

-- Maintenance is refused while a pet is in the kennel (hint kennel_occupied); a kennel that only
-- has future bookings can still be switched, and the board lists the stays that need another kennel.
create or replace function public.set_kennel_status(p_id uuid, p_status text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
begin
  if p_status is null or p_status not in ('ready', 'cleaning', 'maintenance') then
    raise exception 'bad status' using errcode = '22023', hint = 'bad_input';
  end if;
  select branch_id into v_branch from public.kennels where id = p_id;
  if v_branch is null then
    raise exception 'kennel % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_status = 'maintenance' and exists (
    select 1
    from public.boarding_stay_pets sp
    join public.boarding_stays s on s.id = sp.stay_id
    where sp.kennel_id = p_id and sp.status = 'active' and s.status = 'checked_in'
  ) then
    raise exception 'a pet is in this kennel' using errcode = 'P0001', hint = 'kennel_occupied';
  end if;
  update public.kennels set status = p_status where id = p_id;
end;
$$;

revoke execute on function public.set_kennel_status(uuid, text) from public, anon;
grant execute on function public.set_kennel_status(uuid, text) to authenticated;

notify pgrst, 'reload schema';
