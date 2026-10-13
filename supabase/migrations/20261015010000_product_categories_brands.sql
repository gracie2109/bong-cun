-- Product categories and brands (docs/module-san-pham.md, step 1): tables, rules, RLS.
--
--  Two levels at most ("Thức ăn" › "Hạt cho chó"), shared by every branch. A product group
--  belongs to one category of any level (the link is added in 20261015010100). Names are unique
--  among siblings (accents and case ignored), slugs are unique overall and follow the name.
--  A category or brand in use cannot be deleted, only switched off. Writes go through the
--  functions of the next files ("products" permission); the tables are public read so the shop
--  can list them. Brands are flat. Safe to run more than once.

-- "Hạt cho chó" -> "hat-cho-cho"; never empty.
create or replace function public.slugify(p_text text) returns text
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    nullif(trim(both '-' from regexp_replace(lower(public.immutable_unaccent(p_text)), '[^a-z0-9]+', '-', 'g')), ''),
    'item'
  );
$$;

create table if not exists public.product_categories (
  id         uuid primary key default gen_random_uuid(),
  parent_id  uuid references public.product_categories(id) on delete restrict,
  name       text not null check (length(btrim(name)) > 0),
  slug       text not null,
  image_url  text,
  sort_order int not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint product_categories_not_own_parent check (parent_id is distinct from id)
);
create unique index if not exists product_categories_name_key
  on public.product_categories (
    coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(public.immutable_unaccent(btrim(name)))
  );
create unique index if not exists product_categories_slug_key on public.product_categories (slug);
create index if not exists product_categories_parent_idx on public.product_categories (parent_id) where parent_id is not null;

drop trigger if exists set_updated_at on public.product_categories;
create trigger set_updated_at before update on public.product_categories
  for each row execute function public.set_updated_at();

-- Two levels only: a parent must be a top-level category, and a category that has children
-- cannot be moved under another one.
create or replace function public.product_categories_check_depth() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.parent_id is null then
    return new;
  end if;
  if exists (select 1 from public.product_categories where id = new.parent_id and parent_id is not null) then
    raise exception 'categories have two levels at most' using errcode = '22023', hint = 'too_deep';
  end if;
  if exists (select 1 from public.product_categories where parent_id = new.id) then
    raise exception 'a category with sub-categories cannot have a parent' using errcode = '22023', hint = 'too_deep';
  end if;
  return new;
end;
$$;

drop trigger if exists check_depth on public.product_categories;
create trigger check_depth before insert or update of parent_id on public.product_categories
  for each row execute function public.product_categories_check_depth();

alter table public.product_categories enable row level security;
drop policy if exists "public read" on public.product_categories;
create policy "public read" on public.product_categories for select to anon, authenticated using (true);
revoke insert, update, delete on public.product_categories from anon, authenticated;

create table if not exists public.product_brands (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(btrim(name)) > 0),
  slug       text not null,
  image_url  text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists product_brands_name_key
  on public.product_brands (lower(public.immutable_unaccent(btrim(name))));
create unique index if not exists product_brands_slug_key on public.product_brands (slug);

drop trigger if exists set_updated_at on public.product_brands;
create trigger set_updated_at before update on public.product_brands
  for each row execute function public.set_updated_at();

alter table public.product_brands enable row level security;
drop policy if exists "public read" on public.product_brands;
create policy "public read" on public.product_brands for select to anon, authenticated using (true);
revoke insert, update, delete on public.product_brands from anon, authenticated;

-- A product group has one category (any level) and one brand, both optional.
alter table public.product_groups
  add column if not exists category_id uuid references public.product_categories(id) on delete restrict,
  add column if not exists brand_id    uuid references public.product_brands(id) on delete restrict;
create index if not exists product_groups_category_idx on public.product_groups (category_id) where category_id is not null;
create index if not exists product_groups_brand_idx on public.product_groups (brand_id) where brand_id is not null;

notify pgrst, 'reload schema';
