-- Medical records, step 3 (1/3): the lines of a visit that are charged or prescribed
-- (docs/ho-so-benh-an.md, sections 4 and 5). Safe to run more than once.
--
-- Before: a visit has no services, medicine or prescription.
-- After: a visit keeps lines of three kinds: a medical service (priced by the pet's species and the
-- visit's weight), a stock product (medicine or supplies, used on the spot or taken home) and an
-- external medicine bought elsewhere (printed on the prescription, never charged). Prices are
-- worked out by the database when the line is added; the client never sends one.
-- Runs after 20261021020200_medical_views.sql. Writes go through 20261021030100_medical_item_rpcs.sql.

create table if not exists public.medical_visit_items (
  id              uuid primary key default gen_random_uuid(),
  visit_id        uuid not null references public.medical_visits(id) on delete cascade,
  branch_id       uuid not null references public.branches(id) on delete restrict,
  kind            text not null check (kind in ('service', 'product', 'external')),
  service_id      uuid references public.pet_services(id) on delete restrict,
  product_id      uuid references public.products(id) on delete restrict,
  -- The conversion unit a product line is counted in; null = the product's own unit.
  unit_id         uuid references public.product_units(id) on delete set null,
  unit_name       text,
  unit_factor     numeric(12,2) not null default 1 check (unit_factor >= 1),
  name            text not null check (length(btrim(name)) > 0),
  qty             numeric(10,2) not null default 1 check (qty > 0),
  unit_price      numeric(14,2) not null default 0 check (unit_price >= 0),
  amount          numeric(14,2) not null default 0 check (amount >= 0),
  -- Medicine for the owner to take home (printed on the prescription).
  take_home       boolean not null default false,
  dose            text,
  frequency       text,
  days            int check (days > 0),
  route           text,
  instructions    text,
  -- Added by the system when the vet took the case (the default exam service).
  auto_added      boolean not null default false,
  -- Filled in by the steps that follow: the batch of a vaccine, its record, the invoice line.
  lot_id          uuid references public.stock_lots(id) on delete set null,
  vaccination_id  uuid,
  invoice_line_id uuid references public.invoice_lines(id) on delete set null,
  created_by      uuid references auth.users(id) on delete set null,
  created_by_name text,
  created_at      timestamptz not null default now(),
  constraint medical_visit_items_kind_ref check (
    (kind = 'service' and service_id is not null and product_id is null)
    or (kind = 'product' and product_id is not null and service_id is null)
    or (kind = 'external' and service_id is null and product_id is null)
  ),
  constraint medical_visit_items_external_free check (kind <> 'external' or (unit_price = 0 and amount = 0))
);
create index if not exists medical_visit_items_visit_idx on public.medical_visit_items (visit_id, created_at);
create index if not exists medical_visit_items_product_idx on public.medical_visit_items (product_id) where product_id is not null;
create index if not exists medical_visit_items_invoice_idx on public.medical_visit_items (invoice_line_id) where invoice_line_id is not null;

alter table public.medical_visit_items enable row level security;

drop policy if exists "medical read" on public.medical_visit_items;
create policy "medical read" on public.medical_visit_items for select to authenticated
  using ((select public.can_medical('VIEW')));

revoke insert, update, delete on public.medical_visit_items from anon, authenticated;
revoke all on public.medical_visit_items from anon;

notify pgrst, 'reload schema';
