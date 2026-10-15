-- Medical records, step 8 (1/2): in-patient care on top of the pet hotel (docs/ho-so-benh-an.md, section 4).
-- Safe to run more than once.
--
-- Before: a sick pet that must stay at the clinic has nowhere to go and no order sheet.
-- After: the vet admits the pet of an open visit into a medical or isolation kennel (a pet hotel
-- stay of kind 'inpatient' tied to the visit), writes orders (medicine, services, care) with
-- the hours of the day, and the assistant ticks each dose as it is given. A given medicine or
-- service becomes a line of the visit, billed at the POS after the vet signs. Discharge closes the
-- stay like a normal check-out (kennel nights go to the POS "boarding" box). The visit cannot be
-- signed or cancelled while the pet is still in the kennel.
-- 20261021080100_inpatient_rpcs.sql follows.

-- --------------------------------------------------------------------- stays
alter table public.boarding_stays add column if not exists kind text not null default 'boarding';
alter table public.boarding_stays drop constraint if exists boarding_stays_kind_check;
alter table public.boarding_stays add constraint boarding_stays_kind_check check (kind in ('boarding', 'inpatient'));
alter table public.boarding_stays add column if not exists visit_id uuid references public.medical_visits(id) on delete set null;
create unique index if not exists boarding_stays_visit_key
  on public.boarding_stays (visit_id) where kind = 'inpatient' and status in ('booked', 'checked_in');

-- Vital signs and treatments are logged on the same care log, hidden from the customer.
alter table public.boarding_care_logs drop constraint if exists boarding_care_logs_kind_check;
alter table public.boarding_care_logs
  add constraint boarding_care_logs_kind_check check (kind in ('meal', 'walk', 'potty', 'medication', 'note', 'vitals', 'treatment'));

-- ------------------------------------------------------------------- orders
create table if not exists public.inpatient_orders (
  id            uuid primary key default gen_random_uuid(),
  stay_pet_id   uuid not null references public.boarding_stay_pets(id) on delete cascade,
  stay_id       uuid not null references public.boarding_stays(id) on delete cascade,
  visit_id      uuid not null references public.medical_visits(id) on delete cascade,
  branch_id     uuid not null references public.branches(id) on delete restrict,
  kind          text not null check (kind in ('product', 'service', 'care')),
  product_id    uuid references public.products(id) on delete restrict,
  service_id    uuid references public.pet_services(id) on delete restrict,
  name          text not null check (length(btrim(name)) > 0),
  dose          text,
  qty_per_dose  numeric(10,2) not null default 1 check (qty_per_dose > 0),
  -- Hours of the day, "HH:MM", Vietnam time.
  times         text[] not null check (cardinality(times) between 1 and 8),
  start_on      date not null,
  end_on        date not null,
  note          text,
  -- The line of the visit the given doses add up to (medicine and services only).
  item_id       uuid references public.medical_visit_items(id) on delete set null,
  stopped_at    timestamptz,
  created_by    uuid references auth.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  check (end_on >= start_on and end_on <= start_on + 30),
  check ((kind = 'product' and product_id is not null and service_id is null)
      or (kind = 'service' and service_id is not null and product_id is null)
      or (kind = 'care' and product_id is null and service_id is null))
);
create index if not exists inpatient_orders_stay_idx on public.inpatient_orders (stay_id);
create index if not exists inpatient_orders_visit_idx on public.inpatient_orders (visit_id);

create table if not exists public.inpatient_doses (
  id             uuid primary key default gen_random_uuid(),
  order_id       uuid not null references public.inpatient_orders(id) on delete cascade,
  due_at         timestamptz not null,
  given_at       timestamptz,
  given_by       uuid references auth.users(id) on delete set null,
  given_by_name  text,
  skipped_reason text,
  unique (order_id, due_at),
  check (given_at is null or skipped_reason is null)
);
create index if not exists inpatient_doses_due_idx on public.inpatient_doses (due_at);

alter table public.inpatient_orders enable row level security;
alter table public.inpatient_doses  enable row level security;

drop policy if exists "medical read" on public.inpatient_orders;
create policy "medical read" on public.inpatient_orders for select to authenticated
  using ((select public.can_medical('VIEW')));
drop policy if exists "medical read" on public.inpatient_doses;
create policy "medical read" on public.inpatient_doses for select to authenticated
  using ((select public.can_medical('VIEW')));

revoke insert, update, delete on public.inpatient_orders, public.inpatient_doses from anon, authenticated;
revoke all on public.inpatient_orders, public.inpatient_doses from anon;

-- ----------------------------------------------------------------- the guard
-- A visit with a pet still in the kennel is neither signed nor cancelled: discharge comes first.
create or replace function public.medical_visits_inpatient_guard() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if ((old.signed_at is null and new.signed_at is not null) or (old.status <> 'cancelled' and new.status = 'cancelled'))
     and exists (
       select 1 from public.boarding_stays s
       where s.visit_id = new.id and s.kind = 'inpatient' and s.status = 'checked_in'
     ) then
    raise exception 'the pet is still in the clinic' using errcode = 'P0001', hint = 'inpatient_active';
  end if;
  return new;
end;
$$;

drop trigger if exists medical_visits_inpatient_guard on public.medical_visits;
create trigger medical_visits_inpatient_guard before update on public.medical_visits
  for each row execute function public.medical_visits_inpatient_guard();

notify pgrst, 'reload schema';
