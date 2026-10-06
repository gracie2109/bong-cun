-- bongCunManager schema. Replaces the Firestore collections listed in
-- src/lib/constants.ts (COLLECTION). Dropped on purpose: stored `uid`,
-- denormalized *Profiles / userInfo copies, raw passwords, array-of-one durations.

create function public.set_updated_at() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------- RBAC vocab
create table public.roles (
  name        text primary key,
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.permissions (
  name        text primary key,
  methods     text[] not null default '{}',
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint permissions_methods_valid check (
    methods <@ array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','SETTING','ALL']
  )
);

create table public.role_permissions (
  role       text not null references public.roles(name) on update cascade on delete cascade,
  permission text not null references public.permissions(name) on update cascade on delete cascade,
  primary key (role, permission)
);
create index role_permissions_permission_idx on public.role_permissions (permission);

-- Reference data the signup trigger depends on (DEFAULT_ROLE in constants.ts).
insert into public.roles (name, description) values
  ('superAdmin', 'Toàn quyền'),
  ('admin',      'Quản trị viên'),
  ('cashier',    'Thu ngân'),
  ('customer',   'Khách hàng');

-- ------------------------------------------------------------ users / profiles
create table public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  email        text,
  display_name text unique,
  full_name    text,
  phone_number text unique,
  photo_url    text,
  gender       text check (gender in ('MALE','FEMALE','OTHER')),
  address      jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- One role per user. No client write policy is ever created for this table's
-- role column, so a user cannot promote themselves.
create table public.user_roles (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  role       text not null default 'customer'
             references public.roles(name) on update cascade on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index user_roles_role_idx on public.user_roles (role);

-- ------------------------------------------------------------------- catalog
create table public.pets (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  icon        text,
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Lookup table replacing src/data/pet-weights.json. ids kept verbatim.
create table public.pet_weights (
  id         text primary key,
  label_vi   text not null,
  label_en   text not null,
  sort_order int  not null default 0
);

create table public.pet_services (
  id               uuid primary key default gen_random_uuid(),
  name             text not null unique,
  description      text,
  type             text check (type in ('all','by_weight')),
  unit             text check (unit in ('unit1','unit2')),
  general_price    numeric(14,2) check (general_price >= 0),
  duration_minutes int check (duration_minutes between 0 and 1439),
  is_show          boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table public.pet_service_pets (
  service_id uuid not null references public.pet_services(id) on delete cascade,
  pet_id     uuid not null references public.pets(id) on delete cascade,
  primary key (service_id, pet_id)
);
create index pet_service_pets_pet_idx on public.pet_service_pets (pet_id);

create table public.pet_service_prices (
  id         uuid primary key default gen_random_uuid(),
  pet_id     uuid not null references public.pets(id) on delete cascade,
  service_id uuid not null references public.pet_services(id) on delete cascade,
  weight_id  text not null references public.pet_weights(id),
  price      numeric(14,2) not null check (price >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (pet_id, service_id, weight_id)
);
create index pet_service_prices_service_idx on public.pet_service_prices (service_id);
create index pet_service_prices_weight_idx  on public.pet_service_prices (weight_id);

create table public.pet_service_combos (
  id               uuid primary key default gen_random_uuid(),
  name             text not null unique,
  description      text,
  origin_price     numeric(14,2) check (origin_price >= 0),
  price            numeric(14,2) check (price >= 0),
  duration_minutes int check (duration_minutes between 0 and 1439),
  mark_as_id       text check (mark_as_id in ('1','2','3','4')),
  mark_start       timestamptz,
  mark_end         timestamptz,
  status           smallint not null default 1 check (status in (1,2)),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table public.combo_pets (
  combo_id uuid not null references public.pet_service_combos(id) on delete cascade,
  pet_id   uuid not null references public.pets(id) on delete cascade,
  primary key (combo_id, pet_id)
);
create index combo_pets_pet_idx on public.combo_pets (pet_id);

create table public.combo_services (
  combo_id   uuid not null references public.pet_service_combos(id) on delete cascade,
  service_id uuid not null references public.pet_services(id) on delete cascade,
  primary key (combo_id, service_id)
);
create index combo_services_service_idx on public.combo_services (service_id);

-- Minimal tables: the source has no field evidence for these. Extend when real
-- forms exist rather than inventing columns now.
create table public.products (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.service_providers (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  phone       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.banners (
  id         uuid primary key default gen_random_uuid(),
  title      text,
  image_url  text,
  link_url   text,
  is_active  boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------- bookings and orders
-- register-booking collection. `scheduled_at` replaces the lossy 12h string
-- "MM/dd/yyyy hh:mm:ss"; the form must send an ISO timestamp.
create table public.bookings (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  email            text not null,
  phone_number     text not null,
  scheduled_at     timestamptz not null,
  content          text,
  user_id          uuid references auth.users(id) on delete set null,
  status           text not null default 'PENDING'
                   check (status in ('PENDING','PROCESSING','CONFIRMED','CANCEL')),
  is_cancel        boolean not null default false,
  is_moving_time   boolean not null default false,
  cancel_date      timestamptz,
  cancel_by        uuid references auth.users(id) on delete set null,
  cancel_reason    text,
  confirm_changed_by uuid references auth.users(id) on delete set null,
  confirm_from_time  timestamptz,
  confirm_to_time    timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index bookings_user_idx on public.bookings (user_id);
create index bookings_status_scheduled_idx on public.bookings (status, scheduled_at desc);
create index bookings_created_idx on public.bookings (created_at desc);

-- order-services collection (parent).
create table public.orders (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  phone_number text not null,
  pet_num      int check (pet_num >= 0),
  scheduled_at timestamptz,
  user_id      uuid references auth.users(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index orders_user_idx on public.orders (user_id);
create index orders_created_idx on public.orders (created_at desc);

-- order-services-service collection (child). The FK now lives here instead of
-- the parent's hand-rolled order_service[] array. A line is either a single
-- service or a combo, never both.
create table public.order_items (
  id                uuid primary key default gen_random_uuid(),
  order_id          uuid not null references public.orders(id) on delete cascade,
  service_id        uuid references public.pet_services(id) on delete restrict,
  combo_id          uuid references public.pet_service_combos(id) on delete restrict,
  name              text not null,
  price             numeric(14,2) not null check (price >= 0),
  duration_minutes  int check (duration_minutes between 0 and 1439),
  status            text not null default 'PENDING'
                    check (status in ('PENDING','PROCESSING','CONFIRMED','CANCEL')),
  is_cancel         boolean not null default false,
  is_moving_time    boolean not null default false,
  cancel_date       timestamptz,
  cancel_by         uuid references auth.users(id) on delete set null,
  cancel_reason     text,
  changes_by        uuid references auth.users(id) on delete set null,
  changes_from_time timestamptz,
  changes_to_time   timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint order_items_service_xor_combo check (num_nonnulls(service_id, combo_id) = 1)
);
create index order_items_order_idx   on public.order_items (order_id);
create index order_items_service_idx on public.order_items (service_id) where service_id is not null;
create index order_items_combo_idx   on public.order_items (combo_id)   where combo_id is not null;

-- ----------------------------------------------------------- updated_at triggers
do $$
declare t text;
begin
  foreach t in array array[
    'roles','permissions','profiles','user_roles','pets','pet_services',
    'pet_service_prices','pet_service_combos','bookings','orders','order_items',
    'products','service_providers','banners'
  ] loop
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;
