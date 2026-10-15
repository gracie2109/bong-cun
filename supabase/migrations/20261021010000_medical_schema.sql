-- Medical records, step 1 (1/3): permission, "vet" role, branch rules, diagnosis catalog and
-- vaccine catalog (docs/ho-so-benh-an.md, sections 4 and 7). Safe to run more than once.
--
-- Before: nothing in the database knows about clinical work.
-- After: the "medical" permission and a "vet" role exist; each branch can keep its medical rules;
-- diagnoses and vaccine / deworming types (with a simple protocol) are shared by all branches.
-- The client only reads these tables; every write goes through the RPCs in
-- 20261021010100_medical_settings_rpcs.sql.
--
-- Permission "medical" at the branch: VIEW read, CREATE check in / book / external shots,
-- UPDATE take a case / write the record / sign, DELETE cancel, SETTING catalogs and rules,
-- EXPORT export the lists.

-- --------------------------------------------------------------- permissions
insert into public.permissions (name, description, methods, module, sort_order) values
  ('medical', 'Y tế: tiếp nhận khám, bệnh án, sổ tiêm, nhắc lịch và danh mục',
   array['VIEW','CREATE','UPDATE','DELETE','SETTING','EXPORT','ALL'], 'Y tế', 36)
on conflict (name) do nothing;

insert into public.roles (name, description) values ('vet', 'Bác sĩ thú y')
on conflict (name) do nothing;

-- admin: everything; cashier (front desk): receive pets and phone owners; vet: the whole clinical
-- work. The pets grant lets a vet open the pet profile; it is skipped where "pets" does not exist.
insert into public.role_permissions (role, permission, methods)
select r.role, r.permission, r.methods
from (values
  ('admin',   'medical', array['ALL']),
  ('cashier', 'medical', array['VIEW','CREATE']),
  ('vet',     'medical', array['VIEW','CREATE','UPDATE','EXPORT']),
  ('vet',     'pets',    array['VIEW','UPDATE'])
) as r(role, permission, methods)
where exists (select 1 from public.roles where name = r.role)
  and exists (select 1 from public.permissions where name = r.permission)
on conflict do nothing;

create or replace function public.can_medical(p_method text, p_branch uuid default null) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('medical', p_method, p_branch));
$$;

revoke execute on function public.can_medical(text, uuid) from public, anon;
grant execute on function public.can_medical(text, uuid) to authenticated;

-- -------------------------------------------------------------------- tables
-- One row per branch; a branch without a row uses the defaults below.
create table if not exists public.medical_settings (
  branch_id                  uuid primary key references public.branches(id) on delete cascade,
  -- Service added automatically when a vet takes a case (for example "General exam"); null = none.
  exam_service_id            uuid references public.pet_services(id) on delete set null,
  -- The reminder list shows shots due within this many days.
  remind_ahead_days          int not null default 7 check (remind_ahead_days between 0 and 90),
  -- A contagious diagnosis this recent raises a warning at spa / boarding check-in.
  contagious_days            int not null default 30 check (contagious_days between 1 and 365),
  -- true: boarding check-in warns (never blocks) when the e-book has no valid shot.
  require_vaccine_for_boarding boolean not null default false,
  updated_at                 timestamptz not null default now()
);

-- Diagnoses a vet can pick; free text is still allowed on a visit.
create table if not exists public.diagnosis_terms (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (length(btrim(name)) > 0),
  -- Empty = every species.
  species_ids   uuid[] not null default '{}',
  is_contagious boolean not null default false,
  is_active     boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index if not exists diagnosis_terms_name_key on public.diagnosis_terms (lower(btrim(name)));

-- Vaccines, dewormers and other preventive shots, with a simple protocol: a basic series of
-- `series_doses` shots `series_interval_days` apart, then a booster every `booster_interval_days`.
create table if not exists public.vaccine_types (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null check (length(btrim(name)) > 0),
  kind                  text not null default 'vaccine' check (kind in ('vaccine', 'deworm', 'other')),
  -- Empty = every species.
  species_ids           uuid[] not null default '{}',
  -- Stock item used for the shot (billed and taken from the lots); null = only recorded.
  product_id            uuid references public.products(id) on delete set null,
  series_doses          int not null default 1 check (series_doses between 1 and 10),
  series_interval_days  int check (series_interval_days > 0),
  -- Null = no reminder after the last basic shot.
  booster_interval_days int check (booster_interval_days > 0),
  -- Younger pets get a warning, not a refusal.
  min_age_weeks         int check (min_age_weeks >= 0),
  is_active             boolean not null default true,
  sort_order            int not null default 0,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint vaccine_types_series_gap check (series_doses = 1 or series_interval_days is not null)
);
create unique index if not exists vaccine_types_name_key on public.vaccine_types (lower(btrim(name)));
create index if not exists vaccine_types_product_idx on public.vaccine_types (product_id);

do $$
declare t text;
begin
  foreach t in array array['medical_settings', 'diagnosis_terms', 'vaccine_types'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ------------------------------------------------------------------------ RLS
alter table public.medical_settings enable row level security;
alter table public.diagnosis_terms  enable row level security;
alter table public.vaccine_types    enable row level security;

drop policy if exists "medical read" on public.medical_settings;
create policy "medical read" on public.medical_settings for select to authenticated
  using ((select public.can_medical('VIEW', branch_id)));

-- The catalogs are shared: every staff account reads them.
drop policy if exists "staff read" on public.diagnosis_terms;
create policy "staff read" on public.diagnosis_terms for select to authenticated
  using ((select public.is_staff()));

drop policy if exists "staff read" on public.vaccine_types;
create policy "staff read" on public.vaccine_types for select to authenticated
  using ((select public.is_staff()));

revoke insert, update, delete on public.medical_settings, public.diagnosis_terms,
  public.vaccine_types from anon, authenticated;
revoke all on public.medical_settings, public.diagnosis_terms, public.vaccine_types from anon;

notify pgrst, 'reload schema';
