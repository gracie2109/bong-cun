-- Shop checkout, step 5 (1/4): online order tables (docs/checkout-shop.md, sections 3.6, 3.7
-- and 5.1). Safe to run more than once.
--
-- An order belongs to the ACCOUNT that placed it (user_id, for "my orders") and to the CUSTOMER
-- that is billed (customer_id, who may be a walk-in the account is not linked to). It keeps its
-- own copy of the delivery address and of every line, so editing the address book or the
-- catalog later never changes an old order.
--
-- Nobody writes these tables directly: orders are placed by place_shop_order (20261016050200)
-- and moved along by the staff RPCs of step 6. Reading: an account sees its own orders, staff
-- see the orders of branches where they hold shop_orders: VIEW.

create table if not exists public.shop_orders (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique,
  branch_id          uuid not null references public.branches(id) on delete restrict,
  user_id            uuid not null references public.users(id) on delete restrict,
  customer_id        uuid not null references public.customers(id) on delete restrict,
  status             text not null default 'pending' check (status in
                       ('pending', 'confirmed', 'packed', 'shipping', 'completed', 'cancelled', 'returned')),
  delivery_method    text not null check (delivery_method in ('delivery', 'pickup')),
  payment_method     text not null check (payment_method in ('cod', 'pay_at_store')),
  -- Delivery address copied when the order was placed; for pickup only the receiver is filled.
  receiver_name      text not null check (length(btrim(receiver_name)) > 0),
  receiver_phone     text not null,
  ship_street        text,
  ship_ward_name     text,
  ship_district_name text,
  ship_province_name text,
  ghn_district_id    int,
  ghn_ward_code      text,
  weight_g           int not null default 0 check (weight_g >= 0),
  subtotal           numeric(14,2) not null check (subtotal >= 0),
  -- The fee the customer saw; staff fix the real one when they confirm the order.
  shipping_fee_quote numeric(14,0) not null default 0 check (shipping_fee_quote >= 0),
  shipping_fee       numeric(14,0) check (shipping_fee >= 0),
  total              numeric(14,2) not null,
  customer_note      text,
  invoice_id         uuid unique references public.invoices(id) on delete restrict,
  carrier            text check (carrier in ('ghn')),
  tracking_code      text,
  cancel_reason      text,
  -- Made once per press of "Place order": a retry returns the same order.
  client_ref         uuid unique,
  placed_at          timestamptz not null default now(),
  confirmed_at       timestamptz,
  packed_at          timestamptz,
  shipped_at         timestamptz,
  completed_at       timestamptz,
  cancelled_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  check ((delivery_method = 'delivery') = (ghn_district_id is not null and ghn_ward_code is not null)),
  check (delivery_method = 'pickup' or length(btrim(coalesce(ship_street, ''))) > 0),
  check ((delivery_method = 'pickup') = (payment_method = 'pay_at_store')),
  check (total = subtotal + coalesce(shipping_fee, shipping_fee_quote))
);

create index if not exists shop_orders_branch_status_idx on public.shop_orders (branch_id, status, placed_at desc);
create index if not exists shop_orders_user_idx on public.shop_orders (user_id, placed_at desc);

create table if not exists public.shop_order_lines (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references public.shop_orders(id) on delete cascade,
  line_no     int not null,
  product_id  uuid not null references public.products(id) on delete restrict,
  unit_id     uuid references public.product_units(id) on delete restrict,
  unit_factor numeric(12,2) not null default 1 check (unit_factor >= 1),
  name        text not null,
  unit        text,
  image_url   text,
  qty         numeric(10,2) not null check (qty > 0 and qty <= 99),
  unit_price  numeric(14,2) not null check (unit_price >= 0),
  amount      numeric(14,2) not null,
  unique (order_id, line_no)
);

create index if not exists shop_order_lines_product_idx on public.shop_order_lines (product_id);

create table if not exists public.shop_order_events (
  id         bigint generated always as identity primary key,
  order_id   uuid not null references public.shop_orders(id) on delete cascade,
  status     text not null,
  note       text,
  actor_id   uuid references auth.users(id) on delete set null,
  actor_name text,
  created_at timestamptz not null default now()
);

create index if not exists shop_order_events_order_idx on public.shop_order_events (order_id, created_at);

drop trigger if exists shop_orders_set_updated_at on public.shop_orders;
create trigger shop_orders_set_updated_at before update on public.shop_orders
  for each row execute function public.set_updated_at();

-- ------------------------------------------------------------------------ RLS
alter table public.shop_orders       enable row level security;
alter table public.shop_order_lines  enable row level security;
alter table public.shop_order_events enable row level security;

drop policy if exists "shop orders read" on public.shop_orders;
create policy "shop orders read" on public.shop_orders for select to authenticated
  using (user_id = (select auth.uid()) or (select public.can_shop_orders('VIEW', branch_id)));

drop policy if exists "shop order lines read" on public.shop_order_lines;
create policy "shop order lines read" on public.shop_order_lines for select to authenticated
  using (exists (
    select 1 from public.shop_orders o
    where o.id = shop_order_lines.order_id
      and (o.user_id = (select auth.uid()) or (select public.can_shop_orders('VIEW', o.branch_id)))
  ));

-- The timeline is staff-only here: a customer reads it through my_shop_order, which leaves out
-- who did what.
drop policy if exists "shop order events read" on public.shop_order_events;
create policy "shop order events read" on public.shop_order_events for select to authenticated
  using (exists (
    select 1 from public.shop_orders o
    where o.id = shop_order_events.order_id and (select public.can_shop_orders('VIEW', o.branch_id))
  ));

revoke insert, update, delete on public.shop_orders, public.shop_order_lines, public.shop_order_events
  from anon, authenticated;
revoke all on public.shop_orders, public.shop_order_lines, public.shop_order_events from anon;

notify pgrst, 'reload schema';
