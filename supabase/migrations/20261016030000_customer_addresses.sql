-- Shop checkout, step 3 (1/2): the delivery address book (docs/checkout-shop.md, sections 3.3
-- and 5.1). Safe to run more than once.
--
-- An address belongs to the shop ACCOUNT (user_id), not to a customers row. The plan hung it on
-- the customer, but saving a first address would then have to create a customer for the account,
-- and customers.phone is unique: a shopper whose phone already belongs to a walk-in customer
-- could not save an address, and linking the two automatically would let anyone claim another
-- person's customer record by typing their number. The customer row is found or created when an
-- order is placed (step 5), and the order keeps its own copy of the address.
--
-- Each account keeps up to 10 addresses with exactly one default. The names are for printing
-- and the ghn_* ids are for shipping fees; both are stored (GHN may change the codes later).
-- Writes go through RPCs only (20261016030100); the client may read its own rows.

create table if not exists public.customer_addresses (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  receiver_name   text not null check (length(btrim(receiver_name)) > 0),
  phone           text not null check (length(regexp_replace(phone, '\D', '', 'g')) between 8 and 15),
  street          text not null check (length(btrim(street)) > 0),
  province_name   text not null check (length(btrim(province_name)) > 0),
  district_name   text not null check (length(btrim(district_name)) > 0),
  ward_name       text not null check (length(btrim(ward_name)) > 0),
  ghn_province_id int not null,
  ghn_district_id int not null,
  ghn_ward_code   text not null check (length(btrim(ghn_ward_code)) > 0),
  is_default      boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists customer_addresses_user_idx on public.customer_addresses (user_id, created_at desc);
create unique index if not exists customer_addresses_one_default
  on public.customer_addresses (user_id) where is_default;

drop trigger if exists customer_addresses_set_updated_at on public.customer_addresses;
create trigger customer_addresses_set_updated_at before update on public.customer_addresses
  for each row execute function public.set_updated_at();

alter table public.customer_addresses enable row level security;

drop policy if exists "own addresses read" on public.customer_addresses;
create policy "own addresses read" on public.customer_addresses for select to authenticated
  using (user_id = (select auth.uid()));

revoke insert, update, delete on public.customer_addresses from anon, authenticated;
revoke all on public.customer_addresses from anon;

notify pgrst, 'reload schema';
