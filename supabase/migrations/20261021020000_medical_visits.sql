-- Medical records, step 2 (1/3): visits, diagnoses and addenda
-- (docs/ho-so-benh-an.md, sections 4 and 5). Safe to run more than once.
--
-- Before: nothing records a clinic visit.
-- After: a visit belongs to one pet at one branch (the customer pays), moves through
-- scheduled -> waiting -> in_progress -> done -> paid, and keeps vitals and a SOAP note. Once the
-- vet signs it, a trigger refuses any change to the clinical content; later corrections are
-- addenda that can only be added. The database also refuses a second open visit for one pet.
-- Every write goes through the RPCs in 20261021020100_medical_visit_rpcs.sql; the client only
-- reads these tables (medical: VIEW). Runs after 20261021010200_service_category.sql.

-- ----------------------------------------------------------------------- pets
-- The day a pet died, set together with status = 'deceased'.
alter table public.pets add column if not exists deceased_on date;

-- --------------------------------------------------------------------- helper
create or replace function public.medical_local_date(p_at timestamptz) returns date
language sql
immutable
set search_path = ''
as $$ select (p_at at time zone 'Asia/Ho_Chi_Minh')::date; $$;

revoke execute on function public.medical_local_date(timestamptz) from public, anon, authenticated;

-- -------------------------------------------------------------------- visits
create table if not exists public.medical_visits (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  branch_id      uuid not null references public.branches(id) on delete restrict,
  pet_id         uuid not null references public.pets(id) on delete restrict,
  -- The person who brings the pet and pays; the history follows the pet, not this person.
  customer_id    uuid not null references public.customers(id) on delete restrict,
  -- Copied at check-in so lists read without joins.
  pet_name       text not null,
  customer_name  text not null,
  customer_phone text not null,
  status         text not null default 'waiting'
                 check (status in ('scheduled', 'waiting', 'in_progress', 'done', 'paid', 'cancelled', 'no_show')),
  priority       text not null default 'normal' check (priority in ('normal', 'urgent')),
  -- Business date and number in the day's queue, given at check-in (null while scheduled).
  queue_date     date,
  queue_no       int check (queue_no > 0),
  scheduled_at   timestamptz,
  reason         text,
  vet_id         uuid references auth.users(id) on delete set null,
  vet_name       text,
  checked_in_at  timestamptz,
  started_at     timestamptz,
  -- Vitals. The weight is kept per visit and also logged on the pet.
  weight_kg      numeric(6,2) check (weight_kg > 0),
  temperature_c  numeric(4,1) check (temperature_c between 25 and 45),
  heart_rate     int check (heart_rate > 0),
  resp_rate      int check (resp_rate > 0),
  vitals_note    text,
  -- SOAP, free text.
  subjective     text,
  objective      text,
  assessment     text,
  plan           text,
  -- The part the owner may read.
  owner_instructions text,
  outcome        text check (outcome in ('home', 'recheck', 'inpatient', 'referred', 'deceased')),
  recheck_on     date,
  -- The visit this one is a re-check of.
  follow_up_of   uuid references public.medical_visits(id) on delete set null,
  signed_at      timestamptz,
  signed_by      uuid references auth.users(id) on delete set null,
  signed_by_name text,
  source         text not null default 'counter' check (source in ('counter', 'phone', 'recheck', 'web')),
  cancelled_at   timestamptz,
  cancel_reason  text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  -- A visit that is checked in has its queue place; one that is booked ahead has a time.
  check (status = 'scheduled' or queue_no is not null or status in ('cancelled', 'no_show')),
  check (status <> 'scheduled' or scheduled_at is not null)
);
create unique index if not exists medical_visits_queue_key
  on public.medical_visits (branch_id, queue_date, queue_no);
-- A pet is in front of one vet at a time.
create unique index if not exists medical_visits_pet_open_key
  on public.medical_visits (pet_id) where status in ('waiting', 'in_progress');
create index if not exists medical_visits_branch_queue_idx on public.medical_visits (branch_id, queue_date desc);
create index if not exists medical_visits_pet_idx on public.medical_visits (pet_id, created_at desc);
create index if not exists medical_visits_customer_idx on public.medical_visits (customer_id);
create index if not exists medical_visits_status_idx on public.medical_visits (branch_id, status);
create index if not exists medical_visits_scheduled_idx on public.medical_visits (branch_id, scheduled_at)
  where status = 'scheduled';

-- Once signed, the clinical content cannot change; only the workflow columns (status, billing)
-- and the addenda can. The lock lives here so no client can walk around it.
create or replace function public.medical_visits_lock() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.signed_at is null then
    return new;
  end if;
  if new.signed_at is distinct from old.signed_at
     or new.signed_by is distinct from old.signed_by
     or new.pet_id is distinct from old.pet_id
     or new.customer_id is distinct from old.customer_id
     or new.weight_kg is distinct from old.weight_kg
     or new.temperature_c is distinct from old.temperature_c
     or new.heart_rate is distinct from old.heart_rate
     or new.resp_rate is distinct from old.resp_rate
     or new.vitals_note is distinct from old.vitals_note
     or new.subjective is distinct from old.subjective
     or new.objective is distinct from old.objective
     or new.assessment is distinct from old.assessment
     or new.plan is distinct from old.plan
     or new.owner_instructions is distinct from old.owner_instructions
     or new.outcome is distinct from old.outcome
     or new.recheck_on is distinct from old.recheck_on then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  return new;
end;
$$;

drop trigger if exists medical_visits_lock on public.medical_visits;
create trigger medical_visits_lock before update on public.medical_visits
  for each row execute function public.medical_visits_lock();

-- ----------------------------------------------------------------- diagnoses
create table if not exists public.medical_diagnoses (
  id            uuid primary key default gen_random_uuid(),
  visit_id      uuid not null references public.medical_visits(id) on delete cascade,
  -- Null = typed by hand.
  term_id       uuid references public.diagnosis_terms(id) on delete set null,
  name          text not null check (length(btrim(name)) > 0),
  is_contagious boolean not null default false,
  note          text,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now()
);
create index if not exists medical_diagnoses_visit_idx on public.medical_diagnoses (visit_id, sort_order);
create index if not exists medical_diagnoses_contagious_idx on public.medical_diagnoses (visit_id) where is_contagious;

-- Diagnoses follow the lock of their visit.
create or replace function public.medical_diagnoses_lock() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_visit uuid := coalesce(new.visit_id, old.visit_id);
begin
  if exists (select 1 from public.medical_visits where id = v_visit and signed_at is not null) then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists medical_diagnoses_lock on public.medical_diagnoses;
create trigger medical_diagnoses_lock before insert or update or delete on public.medical_diagnoses
  for each row execute function public.medical_diagnoses_lock();

-- ------------------------------------------------------------------- addenda
-- Written after the visit is signed. Never edited, never deleted.
create table if not exists public.medical_addenda (
  id              uuid primary key default gen_random_uuid(),
  visit_id        uuid not null references public.medical_visits(id) on delete cascade,
  content         text not null check (length(btrim(content)) > 0),
  created_by      uuid references auth.users(id) on delete set null,
  created_by_name text,
  created_at      timestamptz not null default now()
);
create index if not exists medical_addenda_visit_idx on public.medical_addenda (visit_id, created_at);

create or replace function public.medical_addenda_frozen() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'an addendum cannot be changed' using errcode = 'P0001', hint = 'signed';
end;
$$;

drop trigger if exists medical_addenda_frozen on public.medical_addenda;
create trigger medical_addenda_frozen before update or delete on public.medical_addenda
  for each row execute function public.medical_addenda_frozen();

drop trigger if exists set_updated_at on public.medical_visits;
create trigger set_updated_at before update on public.medical_visits
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------------------ RLS
alter table public.medical_visits    enable row level security;
alter table public.medical_diagnoses enable row level security;
alter table public.medical_addenda   enable row level security;

-- A pet's history is readable from every branch (the catalog of pets and owners is shared);
-- writing stays per branch inside the RPCs.
drop policy if exists "medical read" on public.medical_visits;
create policy "medical read" on public.medical_visits for select to authenticated
  using ((select public.can_medical('VIEW')));

drop policy if exists "medical read" on public.medical_diagnoses;
create policy "medical read" on public.medical_diagnoses for select to authenticated
  using ((select public.can_medical('VIEW')));

drop policy if exists "medical read" on public.medical_addenda;
create policy "medical read" on public.medical_addenda for select to authenticated
  using ((select public.can_medical('VIEW')));

revoke insert, update, delete on public.medical_visits, public.medical_diagnoses,
  public.medical_addenda from anon, authenticated;
revoke all on public.medical_visits, public.medical_diagnoses, public.medical_addenda from anon;

notify pgrst, 'reload schema';
