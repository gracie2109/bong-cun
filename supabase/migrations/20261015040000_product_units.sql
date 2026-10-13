-- Product module, step 4 (1/9): unit conversion tables and columns (docs/module-san-pham.md, 3.4).
-- A variant sells and receives in its base unit (products.unit, stock is counted in it) and in
-- any number of larger units ("hộp" = 10 "viên"). Safe to run more than once.

create table if not exists public.product_units (
  id           uuid primary key default gen_random_uuid(),
  product_id   uuid not null references public.products(id) on delete cascade,
  name         text not null check (length(btrim(name)) > 0),
  factor       numeric(12,2) not null check (factor > 1),
  barcode      text,
  price        numeric(14,2) check (price >= 0),   -- null = base price x factor
  for_sale     boolean not null default true,
  for_purchase boolean not null default false,
  is_active    boolean not null default true,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);
create unique index if not exists product_units_name_key
  on public.product_units (product_id, lower(btrim(name)));
create unique index if not exists product_units_barcode_key
  on public.product_units (barcode) where barcode is not null;

-- Readable by everyone (the shop and the POS), written only through save_product_group.
alter table public.product_units enable row level security;
drop policy if exists "public read" on public.product_units;
create policy "public read" on public.product_units for select to anon, authenticated using (true);
revoke insert, update, delete on public.product_units from anon, authenticated;

-- A sale line keeps the unit it was sold in and how many base units that is. Lines from before
-- this step have factor 1, so base_qty = qty.
alter table public.invoice_lines
  add column if not exists unit_id     uuid references public.product_units(id) on delete restrict,
  add column if not exists unit_factor numeric(12,2) not null default 1 check (unit_factor > 0);
alter table public.invoice_lines
  add column if not exists base_qty numeric generated always as (qty * unit_factor) stored;
create index if not exists invoice_lines_unit_idx on public.invoice_lines (unit_id) where unit_id is not null;

-- A receipt line keeps what was typed (entered_*) next to the base-unit qty and unit_cost the
-- stock is posted with.
alter table public.stock_document_lines
  add column if not exists unit_id      uuid references public.product_units(id) on delete restrict,
  add column if not exists unit_name    text,
  add column if not exists unit_factor  numeric(12,2) not null default 1 check (unit_factor > 0),
  add column if not exists entered_qty  numeric(12,2),
  add column if not exists entered_cost numeric(14,2);
create index if not exists stock_document_lines_unit_idx on public.stock_document_lines (unit_id) where unit_id is not null;

notify pgrst, 'reload schema';
