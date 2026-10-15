-- Pet hotel (boarding), step 1 (1/2): permission, kennel catalog, kennels and branch rules
-- (docs/khach-san-thu-cung.md, sections 4 and 7). Safe to run more than once.
--
-- Before: nothing in the database knows about kennels or boarding.
-- After: kennel types (shared by all branches) carry a nightly price with an optional branch
-- price; kennels belong to a branch; each branch has its own check-in / check-out rules. The
-- client only reads these tables; every write goes through the RPCs in
-- 20261020010100_boarding_settings_rpcs.sql.
--
-- Permission "boarding" at the branch: VIEW read, CREATE book / check in / log care,
-- UPDATE edit / check out / kennel status, DELETE cancel, SETTING catalog / prices / kennels / rules.

-- --------------------------------------------------------------- permissions
insert into public.permissions (name, description, methods, module, sort_order) values
  ('boarding', 'Khách sạn thú cưng: đặt chỗ, check-in / check-out, chuồng và giá',
   array['VIEW','CREATE','UPDATE','DELETE','SETTING','EXPORT','ALL'], 'Lưu trú', 35)
on conflict (name) do nothing;

insert into public.role_permissions (role, permission, methods)
select r.role, r.permission, r.methods
from (values
  ('admin',   'boarding', array['ALL']),
  ('cashier', 'boarding', array['VIEW','CREATE','UPDATE'])
) as r(role, permission, methods)
where exists (select 1 from public.roles where name = r.role)
on conflict do nothing;

create or replace function public.can_boarding(p_method text, p_branch uuid default null) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('boarding', p_method, p_branch));
$$;

revoke execute on function public.can_boarding(text, uuid) from public, anon;
grant execute on function public.can_boarding(text, uuid) to authenticated;

-- -------------------------------------------------------------------- tables
-- The catalog shared by every branch (like pet_services).
create table if not exists public.kennel_types (
  id            uuid primary key default gen_random_uuid(),
  name          text not null check (length(btrim(name)) > 0),
  description   text,
  photo_url     text,
  -- Species accepted; empty = every species.
  species_ids   uuid[] not null default '{}',
  -- Heaviest pet; null = no limit. Over the limit is a warning, not a refusal.
  max_weight_kg numeric(6,2) check (max_weight_kg > 0),
  -- Pets of one stay (one owner) that may share a kennel.
  max_pets      int not null default 1 check (max_pets >= 1),
  -- 'medical' and 'isolation' are kept for in-patient care (phase 2).
  purpose       text not null default 'boarding' check (purpose in ('boarding', 'medical', 'isolation')),
  is_active     boolean not null default true,
  -- Shown on the public price list.
  is_public     boolean not null default true,
  sort_order    int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create unique index if not exists kennel_types_name_key on public.kennel_types (lower(btrim(name)));

-- branch_id null = the price for every branch; a row with branch_id overrides it there.
create table if not exists public.kennel_type_prices (
  id                    uuid primary key default gen_random_uuid(),
  kennel_type_id        uuid not null references public.kennel_types(id) on delete cascade,
  branch_id             uuid references public.branches(id) on delete cascade,
  night_price           numeric(14,2) not null check (night_price >= 0),
  -- Each further pet sharing the kennel; null = same as night_price.
  extra_pet_night_price numeric(14,2) check (extra_pet_night_price >= 0),
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint kennel_type_prices_key unique nulls not distinct (kennel_type_id, branch_id)
);

create table if not exists public.kennels (
  id             uuid primary key default gen_random_uuid(),
  branch_id      uuid not null references public.branches(id) on delete restrict,
  kennel_type_id uuid not null references public.kennel_types(id) on delete restrict,
  code           text not null check (length(btrim(code)) > 0),
  name           text,
  -- Physical state set by a person. "Occupied" is never stored: it comes from the stays.
  status         text not null default 'ready' check (status in ('ready', 'cleaning', 'maintenance')),
  is_active      boolean not null default true,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create unique index if not exists kennels_branch_code_key on public.kennels (branch_id, lower(btrim(code)));
create index if not exists kennels_type_idx on public.kennels (kennel_type_id);

-- One row per branch; a branch without a row uses the defaults below.
create table if not exists public.boarding_settings (
  branch_id       uuid primary key references public.branches(id) on delete cascade,
  check_in_from   time not null default '08:00',
  check_out_by    time not null default '12:00',
  late_half_until time not null default '18:00',
  max_nights      int not null default 30 check (max_nights between 1 and 365),
  day_stay_nights numeric(2,1) not null default 1 check (day_stay_nights in (0.5, 1)),
  updated_at      timestamptz not null default now(),
  check (check_out_by < late_half_until)
);

do $$
declare t text;
begin
  foreach t in array array['kennel_types', 'kennel_type_prices', 'kennels', 'boarding_settings'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ------------------------------------------------------------------------ RLS
alter table public.kennel_types       enable row level security;
alter table public.kennel_type_prices enable row level security;
alter table public.kennels            enable row level security;
alter table public.boarding_settings  enable row level security;

-- The catalog is shared: every staff account reads it.
drop policy if exists "staff read" on public.kennel_types;
create policy "staff read" on public.kennel_types for select to authenticated
  using ((select public.is_staff()));

drop policy if exists "staff read" on public.kennel_type_prices;
create policy "staff read" on public.kennel_type_prices for select to authenticated
  using ((select public.is_staff()));

drop policy if exists "boarding read" on public.kennels;
create policy "boarding read" on public.kennels for select to authenticated
  using ((select public.can_boarding('VIEW', branch_id)));

drop policy if exists "boarding read" on public.boarding_settings;
create policy "boarding read" on public.boarding_settings for select to authenticated
  using ((select public.can_boarding('VIEW', branch_id)));

revoke insert, update, delete on public.kennel_types, public.kennel_type_prices,
  public.kennels, public.boarding_settings from anon, authenticated;
revoke all on public.kennel_types, public.kennel_type_prices, public.kennels,
  public.boarding_settings from anon;

notify pgrst, 'reload schema';
