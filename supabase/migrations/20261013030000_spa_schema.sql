-- Spa appointments, step 1 (docs/lich-hen-spa.md).
--
-- Before: bookings (contact form) and orders / order_items (services as text, no customer,
-- pet, staff or table) were the only "schedule". Nothing stopped two bookings at the same time.
-- After: an appointment belongs to a customer at a branch and has one ticket per pet and
-- service, each with its own staff member, spa table and time slot. The database refuses
-- overlapping tickets for the same staff member or the same table.
--
-- Runs after 20261007140000_product_variants.sql. Every write goes through the RPCs below;
-- the client only reads the tables (RLS: the "schedule" permission at the branch).
--
-- Permission "schedule" at the appointment's branch:
--   VIEW read, CREATE book, UPDATE edit, DELETE cancel, SETTING spa tables / hours / staff.

-- ------------------------------------------------------------ who does services
alter table public.staff_branches add column if not exists does_services boolean not null default false;

-- save_staff_branches used to delete and re-insert every row, which would reset does_services each
-- time the roles screen assigns someone. Branches that stay assigned are now updated in place.
-- Still SECURITY INVOKER: the superAdmin-only policies on staff_branches apply.
create or replace function public.save_staff_branches(p_user uuid, p jsonb) returns void
language plpgsql
set search_path = ''
as $$
begin
  delete from public.staff_branches
  where user_id = p_user
    and branch_id not in (
      select (e ->> 'branch_id')::uuid from jsonb_array_elements(coalesce(p, '[]'::jsonb)) as t(e)
    );
  insert into public.staff_branches (user_id, branch_id, role)
  select p_user, (e ->> 'branch_id')::uuid, e ->> 'role'
  from jsonb_array_elements(coalesce(p, '[]'::jsonb)) as t(e)
  on conflict (user_id, branch_id) do update set role = excluded.role;
end;
$$;

-- --------------------------------------------------------------------- tables
create table if not exists public.spa_resources (
  id         uuid primary key default gen_random_uuid(),
  branch_id  uuid not null references public.branches(id) on delete cascade,
  name       text not null check (length(btrim(name)) > 0),
  is_active  boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, name)
);

-- Opening hours per weekday (ISO: 1 = Monday ... 7 = Sunday). No row = 08:00-20:00.
create table if not exists public.branch_hours (
  branch_id  uuid not null references public.branches(id) on delete cascade,
  weekday    smallint not null check (weekday between 1 and 7),
  open_time  time not null default '08:00',
  close_time time not null default '20:00',
  is_closed  boolean not null default false,
  primary key (branch_id, weekday),
  check (is_closed or close_time > open_time)
);

create table if not exists public.appointments (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  branch_id      uuid not null references public.branches(id) on delete restrict,
  customer_id    uuid not null references public.customers(id) on delete restrict,
  -- Copied at booking time so lists read without joining customers.
  customer_name  text not null,
  customer_phone text not null,
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  status         text not null default 'booked'
                 check (status in ('booked', 'checked_in', 'in_progress', 'done', 'paid', 'cancelled', 'no_show')),
  source         text not null default 'counter' check (source in ('counter', 'phone', 'legacy', 'web')),
  note           text,
  checked_in_at  timestamptz,
  cancelled_at   timestamptz,
  cancel_reason  text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (end_at > start_at)
);
create index if not exists appointments_branch_start_idx on public.appointments (branch_id, start_at desc);
create index if not exists appointments_customer_idx on public.appointments (customer_id);

create table if not exists public.appointment_items (
  id               uuid primary key default gen_random_uuid(),
  appointment_id   uuid not null references public.appointments(id) on delete cascade,
  -- Same as the appointment's branch; kept here so RLS and the overlap checks need no join.
  branch_id        uuid not null references public.branches(id) on delete restrict,
  line_no          int not null,
  pet_id           uuid references public.pets(id) on delete restrict,
  item_type        text not null check (item_type in ('service', 'combo')),
  service_id       uuid references public.pet_services(id) on delete restrict,
  combo_id         uuid references public.pet_service_combos(id) on delete restrict,
  name             text not null,
  duration_minutes int not null check (duration_minutes > 0),
  staff_id         uuid references public.users(id) on delete restrict,
  resource_id      uuid references public.spa_resources(id) on delete restrict,
  start_at         timestamptz not null,
  end_at           timestamptz not null,
  status           text not null default 'waiting'
                   check (status in ('waiting', 'in_progress', 'done', 'cancelled')),
  est_price        numeric(14,2) check (est_price >= 0),
  weight_kg        numeric(6,2) check (weight_kg > 0),
  unit_price       numeric(14,2) check (unit_price >= 0),
  invoice_line_id  uuid references public.invoice_lines(id) on delete set null,
  note             text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (appointment_id, line_no),
  check (end_at > start_at),
  check ((item_type = 'service' and service_id is not null and combo_id is null)
      or (item_type = 'combo' and combo_id is not null and service_id is null)),
  -- One staff member / one table cannot have two tickets at the same time.
  constraint appointment_items_staff_no_overlap
    exclude using gist (staff_id with =, tstzrange(start_at, end_at, '[)') with &&)
    where (staff_id is not null and status <> 'cancelled'),
  constraint appointment_items_resource_no_overlap
    exclude using gist (resource_id with =, tstzrange(start_at, end_at, '[)') with &&)
    where (resource_id is not null and status <> 'cancelled')
);
create index if not exists appointment_items_appointment_idx on public.appointment_items (appointment_id);
create index if not exists appointment_items_branch_start_idx on public.appointment_items (branch_id, start_at);
create index if not exists appointment_items_staff_idx on public.appointment_items (staff_id) where staff_id is not null;
create index if not exists appointment_items_pet_idx on public.appointment_items (pet_id) where pet_id is not null;

do $$
declare t text;
begin
  foreach t in array array['spa_resources', 'appointments', 'appointment_items'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------- permissions
create or replace function public.can_schedule(p_method text, p_branch uuid) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('schedule', p_method, p_branch));
$$;

revoke execute on function public.can_schedule(text, uuid) from public, anon;
grant execute on function public.can_schedule(text, uuid) to authenticated;

-- ------------------------------------------------------------------------ RLS
alter table public.spa_resources     enable row level security;
alter table public.branch_hours      enable row level security;
alter table public.appointments      enable row level security;
alter table public.appointment_items enable row level security;

drop policy if exists "schedule read" on public.spa_resources;
create policy "schedule read" on public.spa_resources for select to authenticated
  using ((select public.can_schedule('VIEW', branch_id)));

drop policy if exists "schedule read" on public.branch_hours;
create policy "schedule read" on public.branch_hours for select to authenticated
  using ((select public.can_schedule('VIEW', branch_id)));

-- A staff member sees the tickets assigned to them even without "schedule: VIEW".
drop policy if exists "schedule read" on public.appointment_items;
create policy "schedule read" on public.appointment_items for select to authenticated
  using (staff_id = (select auth.uid()) or (select public.can_schedule('VIEW', branch_id)));

drop policy if exists "schedule read" on public.appointments;
create policy "schedule read" on public.appointments for select to authenticated
  using (
    (select public.can_schedule('VIEW', branch_id))
    or exists (
      select 1 from public.appointment_items i
      where i.appointment_id = appointments.id and i.staff_id = (select auth.uid())
    )
  );

revoke insert, update, delete on public.spa_resources, public.branch_hours,
  public.appointments, public.appointment_items from anon, authenticated;
revoke all on public.spa_resources, public.branch_hours, public.appointments, public.appointment_items from anon;


notify pgrst, 'reload schema';
