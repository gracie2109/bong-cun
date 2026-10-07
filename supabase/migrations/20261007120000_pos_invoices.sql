-- POS at the counter (docs: pet-care-plan/ke-hoach-ba-kien-truc.md, M7 and section 3.2).
--
--  1. Products get what the counter needs to sell them: SKU, barcode, unit, price, archive flag.
--     Stock by lot and expiry (FEFO) comes with the inventory module; create_invoice marks the
--     spot where it will deduct stock.
--  2. Cash shifts per (branch, cashier): opening cash, then a count at close compared with what
--     the system expects.
--  3. Invoices follow the customer (walk-in allowed), lines are polymorphic (product, service,
--     combo) and keep the price at the time of sale, payments can mix cash, transfer and card.
--  4. Document codes are numbered per branch: CS01-HD-000123 (invoice), CS01-CA-000007 (shift).
--  5. Writes go through RPCs only. Prices are computed in the database, never taken from the
--     client. Combos sell at their fixed price.
--
-- Permission codes: "pos" (VIEW = see invoices and shifts, CREATE = sell and run one's own
-- shift, UPDATE = discount above 10% and close someone else's shift, DELETE = cancel an
-- invoice) and "products" (the product catalog). Admin accounts keep full access, as elsewhere.
-- Safe to run more than once.

-- --------------------------------------------------------------- permissions
insert into public.permissions (name, description, methods, module, sort_order) values
  ('pos',      'Bán hàng tại quầy, hóa đơn, ca thu ngân', array['CREATE','VIEW','DELETE','UPDATE','EXPORT','ALL'], 'Bán hàng', 10),
  ('products', 'Danh mục sản phẩm',                     array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','ALL'], 'Kho & sản phẩm', 20)
on conflict (name) do nothing;

-- Cashiers sell and see invoices; admins get everything. Existing grants are left alone.
insert into public.role_permissions (role, permission, methods)
select r.role, r.permission, r.methods
from (values
  ('cashier', 'pos',      array['VIEW','CREATE']),
  ('cashier', 'products', array['VIEW']),
  ('admin',   'pos',      array['ALL']),
  ('admin',   'products', array['ALL'])
) as r(role, permission, methods)
where exists (select 1 from public.roles where name = r.role)
on conflict do nothing;

-- ------------------------------------------------------------------ products
alter table public.products
  add column if not exists sku       text,
  add column if not exists barcode   text,
  add column if not exists unit      text not null default 'cái',
  add column if not exists price     numeric(14,2) not null default 0,
  add column if not exists is_active boolean not null default true;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'products_price_check') then
    alter table public.products add constraint products_price_check check (price >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_sku_key') then
    alter table public.products add constraint products_sku_key unique (sku);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'products_barcode_key') then
    alter table public.products add constraint products_barcode_key unique (barcode);
  end if;
end;
$$;

-- The catalog stays public (the shop reads it); writes follow the "products" permission.
do $$
begin
  drop policy if exists "permission insert" on public.products;
  drop policy if exists "permission update" on public.products;
  drop policy if exists "permission delete" on public.products;
  create policy "permission insert" on public.products for insert to authenticated
    with check ((select public.has_permission('products', 'CREATE')));
  create policy "permission update" on public.products for update to authenticated
    using ((select public.has_permission('products', 'UPDATE')))
    with check ((select public.has_permission('products', 'UPDATE')));
  create policy "permission delete" on public.products for delete to authenticated
    using ((select public.has_permission('products', 'DELETE')));
end;
$$;

-- ------------------------------------------------------- document numbering
create table if not exists public.doc_sequences (
  branch_id uuid not null references public.branches(id) on delete cascade,
  doc_type  text not null check (doc_type ~ '^[A-Z]{2,4}$'),
  last_no   bigint not null default 0,
  primary key (branch_id, doc_type)
);
-- Only the functions below touch it.
alter table public.doc_sequences enable row level security;

-- Next code for a document type at a branch: <branch code>-<type>-<6 digits>. The row lock
-- of the upsert serializes concurrent callers, so codes never repeat.
create or replace function public.next_doc_code(p_branch uuid, p_type text) returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_no   bigint;
begin
  select code into v_code from public.branches where id = p_branch;
  if v_code is null then
    raise exception 'branch % not found', p_branch using errcode = 'P0002';
  end if;

  insert into public.doc_sequences as s (branch_id, doc_type, last_no)
  values (p_branch, p_type, 1)
  on conflict (branch_id, doc_type) do update set last_no = s.last_no + 1
  returning last_no into v_no;

  return v_code || '-' || p_type || '-' || lpad(v_no::text, 6, '0');
end;
$$;

revoke execute on function public.next_doc_code(uuid, text) from public, anon, authenticated;

-- The name printed for a staff member on invoices and shifts.
create or replace function public.staff_display_name(p_user uuid) returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(nullif(btrim(full_name), ''), nullif(btrim(display_name), ''), email)
  from public.users
  where id = p_user;
$$;

revoke execute on function public.staff_display_name(uuid) from public, anon, authenticated;

-- -------------------------------------------------------------- permissions
-- POS check used by the RPCs: the "pos" grant at that branch, or an admin account.
create or replace function public.can_pos(p_method text, p_branch uuid) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('pos', p_method, p_branch));
$$;

revoke execute on function public.can_pos(text, uuid) from public, anon;
grant execute on function public.can_pos(text, uuid) to authenticated;

-- --------------------------------------------------------------- cash shifts
create table if not exists public.cash_shifts (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,
  branch_id     uuid not null references public.branches(id) on delete restrict,
  status        text not null default 'open' check (status in ('open', 'closed')),
  opened_by     uuid not null references auth.users(id) on delete restrict,
  opened_by_name text,
  opened_at     timestamptz not null default now(),
  opening_cash  numeric(14,2) not null check (opening_cash >= 0),
  open_note     text,
  closed_by     uuid references auth.users(id) on delete restrict,
  closed_by_name text,
  closed_at     timestamptz,
  expected_cash numeric(14,2),
  counted_cash  numeric(14,2) check (counted_cash >= 0),
  close_note    text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check ((status = 'open') = (closed_at is null))
);
-- One open shift per cashier per branch.
create unique index if not exists cash_shifts_one_open_idx
  on public.cash_shifts (branch_id, opened_by) where status = 'open';
create index if not exists cash_shifts_branch_opened_idx on public.cash_shifts (branch_id, opened_at desc);

-- ------------------------------------------------------------------ invoices
create table if not exists public.invoices (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  branch_id       uuid not null references public.branches(id) on delete restrict,
  shift_id        uuid not null references public.cash_shifts(id) on delete restrict,
  -- Invoices follow the customer; null for an anonymous walk-in sale.
  customer_id     uuid references public.customers(id) on delete restrict,
  -- Copied at the time of sale so the invoice prints the same later, and reads without
  -- needing access to the customer or staff records.
  customer_name   text,
  customer_phone  text,
  cashier_name    text,
  status          text not null default 'paid' check (status in ('paid', 'cancelled')),
  subtotal        numeric(14,2) not null check (subtotal >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  total           numeric(14,2) not null check (total >= 0),
  paid_amount     numeric(14,2) not null default 0 check (paid_amount >= 0),
  change_amount   numeric(14,2) not null default 0 check (change_amount >= 0),
  note            text,
  -- Room for the e-invoice integration later.
  einvoice_no     text,
  created_by      uuid not null references auth.users(id) on delete restrict,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  cancelled_at    timestamptz,
  cancelled_by    uuid references auth.users(id) on delete restrict,
  cancel_reason   text,
  check (discount_amount <= subtotal),
  check (total = subtotal - discount_amount),
  check ((status = 'cancelled') = (cancelled_at is not null))
);
create index if not exists invoices_branch_created_idx on public.invoices (branch_id, created_at desc);
create index if not exists invoices_shift_idx on public.invoices (shift_id);
create index if not exists invoices_customer_idx on public.invoices (customer_id) where customer_id is not null;

-- One line per product, service or combo. Name and price are copied at the time of sale.
create table if not exists public.invoice_lines (
  id          uuid primary key default gen_random_uuid(),
  invoice_id  uuid not null references public.invoices(id) on delete cascade,
  line_no     int not null,
  item_type   text not null check (item_type in ('product', 'service', 'combo')),
  product_id  uuid references public.products(id) on delete restrict,
  service_id  uuid references public.pet_services(id) on delete restrict,
  combo_id    uuid references public.pet_service_combos(id) on delete restrict,
  pet_id      uuid references public.pets(id) on delete set null,
  pet_name    text,
  name        text not null,
  unit        text,
  qty         numeric(10,2) not null check (qty > 0),
  unit_price  numeric(14,2) not null check (unit_price >= 0),
  amount      numeric(14,2) not null check (amount >= 0),
  -- The weight a by-weight price was resolved with.
  weight_kg   numeric(6,2),
  unique (invoice_id, line_no),
  check (
    (item_type = 'product' and product_id is not null and service_id is null and combo_id is null)
    or (item_type = 'service' and service_id is not null and product_id is null and combo_id is null)
    or (item_type = 'combo' and combo_id is not null and product_id is null and service_id is null)
  )
);
create index if not exists invoice_lines_product_idx on public.invoice_lines (product_id) where product_id is not null;
create index if not exists invoice_lines_service_idx on public.invoice_lines (service_id) where service_id is not null;
create index if not exists invoice_lines_combo_idx   on public.invoice_lines (combo_id) where combo_id is not null;
create index if not exists invoice_lines_pet_idx     on public.invoice_lines (pet_id) where pet_id is not null;

-- Cash is recorded as received; the change given back is on the invoice.
create table if not exists public.payments (
  id         uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  method     text not null check (method in ('cash', 'transfer', 'card')),
  amount     numeric(14,2) not null check (amount > 0),
  bank_ref   text,
  created_at timestamptz not null default now()
);
create index if not exists payments_invoice_idx on public.payments (invoice_id);

do $$
declare t text;
begin
  foreach t in array array['cash_shifts', 'invoices'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ----------------------------------------------------------------------- RLS
-- Read only from the client; every write goes through the RPCs below.
alter table public.cash_shifts   enable row level security;
alter table public.invoices      enable row level security;
alter table public.invoice_lines enable row level security;
alter table public.payments      enable row level security;

drop policy if exists "pos read" on public.cash_shifts;
create policy "pos read" on public.cash_shifts for select to authenticated
  using (opened_by = (select auth.uid()) or (select public.can_pos('VIEW', branch_id)));

drop policy if exists "pos read" on public.invoices;
create policy "pos read" on public.invoices for select to authenticated
  using (created_by = (select auth.uid()) or (select public.can_pos('VIEW', branch_id)));

-- Lines and payments are visible with their invoice (the invoices policy applies in the subquery).
drop policy if exists "pos read" on public.invoice_lines;
create policy "pos read" on public.invoice_lines for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id));

drop policy if exists "pos read" on public.payments;
create policy "pos read" on public.payments for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id));

revoke insert, update, delete on public.cash_shifts, public.invoices, public.invoice_lines, public.payments
  from anon, authenticated;
revoke all on public.cash_shifts, public.invoices, public.invoice_lines, public.payments from anon;

-- ------------------------------------------------------------- shift totals
-- What a shift has taken, and the cash that should be in the drawer:
-- opening cash + cash received - change given, over invoices that were not cancelled.
create or replace function public.cash_shift_summary(p_shift uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_shift public.cash_shifts;
  v_result jsonb;
begin
  select * into v_shift from public.cash_shifts where id = p_shift;
  if not found then
    raise exception 'shift % not found', p_shift using errcode = 'P0002';
  end if;
  if v_shift.opened_by <> (select auth.uid()) and not public.can_pos('VIEW', v_shift.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with inv as (
    select * from public.invoices where shift_id = p_shift
  ), pay as (
    select p.method, sum(p.amount) as amount
    from public.payments p
    join inv on inv.id = p.invoice_id and inv.status = 'paid'
    group by p.method
  )
  select jsonb_build_object(
    'shift_id',        v_shift.id,
    'opening_cash',    v_shift.opening_cash,
    'invoice_count',   (select count(*) from inv where status = 'paid'),
    'cancelled_count', (select count(*) from inv where status = 'cancelled'),
    'sales_total',     (select coalesce(sum(total), 0) from inv where status = 'paid'),
    'discount_total',  (select coalesce(sum(discount_amount), 0) from inv where status = 'paid'),
    'change_total',    (select coalesce(sum(change_amount), 0) from inv where status = 'paid'),
    'cash_in',         coalesce((select amount from pay where method = 'cash'), 0),
    'transfer_in',     coalesce((select amount from pay where method = 'transfer'), 0),
    'card_in',         coalesce((select amount from pay where method = 'card'), 0),
    'expected_cash',   v_shift.opening_cash
                         + coalesce((select amount from pay where method = 'cash'), 0)
                         - (select coalesce(sum(change_amount), 0) from inv where status = 'paid')
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.cash_shift_summary(uuid) from public, anon;
grant execute on function public.cash_shift_summary(uuid) to authenticated;

-- ------------------------------------------------------------- open / close
create or replace function public.open_cash_shift(
  p_branch       uuid,
  p_opening_cash numeric,
  p_note         text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null or not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed to sell at this branch' using errcode = '42501';
  end if;
  if coalesce(p_opening_cash, -1) < 0 then
    raise exception 'opening cash must be zero or more' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.cash_shifts
    where branch_id = p_branch and opened_by = (select auth.uid()) and status = 'open'
  ) then
    raise exception 'a shift is already open' using errcode = '23505';
  end if;

  insert into public.cash_shifts (code, branch_id, opened_by, opened_by_name, opening_cash, open_note)
  values (
    public.next_doc_code(p_branch, 'CA'),
    p_branch,
    (select auth.uid()),
    public.staff_display_name((select auth.uid())),
    p_opening_cash,
    nullif(btrim(p_note), '')
  )
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.open_cash_shift(uuid, numeric, text) from public, anon;
grant execute on function public.open_cash_shift(uuid, numeric, text) to authenticated;

-- The cashier closes their own shift; someone with "pos: Sửa" can close any shift.
create or replace function public.close_cash_shift(
  p_shift        uuid,
  p_counted_cash numeric,
  p_note         text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_shift   public.cash_shifts;
  v_summary jsonb;
begin
  select * into v_shift from public.cash_shifts where id = p_shift for update;
  if not found then
    raise exception 'shift % not found', p_shift using errcode = 'P0002';
  end if;
  if not (
    (v_shift.opened_by = (select auth.uid()) and public.can_pos('CREATE', v_shift.branch_id))
    or public.can_pos('UPDATE', v_shift.branch_id)
  ) then
    raise exception 'not allowed to close this shift' using errcode = '42501';
  end if;
  if v_shift.status <> 'open' then
    raise exception 'shift is already closed' using errcode = '22023';
  end if;
  if coalesce(p_counted_cash, -1) < 0 then
    raise exception 'counted cash must be zero or more' using errcode = '22023';
  end if;

  v_summary := public.cash_shift_summary(p_shift);

  update public.cash_shifts
  set status = 'closed',
      closed_by = (select auth.uid()),
      closed_by_name = public.staff_display_name((select auth.uid())),
      closed_at = now(),
      expected_cash = (v_summary ->> 'expected_cash')::numeric,
      counted_cash = p_counted_cash,
      close_note = nullif(btrim(p_note), '')
  where id = p_shift;

  return v_summary || jsonb_build_object('counted_cash', p_counted_cash);
end;
$$;

revoke execute on function public.close_cash_shift(uuid, numeric, text) from public, anon;
grant execute on function public.close_cash_shift(uuid, numeric, text) to authenticated;

-- ---------------------------------------------------------------- the sale
-- Creates a paid invoice in one transaction and returns { id, code, total, change_amount }.
-- p: {
--   branch_id, discount_amount?, note?,
--   customer_id? | customer?: { id } | { user_id } | { full_name, phone, email? },
--   lines: [{ type: 'product' | 'service' | 'combo', id, qty?, pet_id?, weight_kg? }],
--   payments: [{ method: 'cash' | 'transfer' | 'card', amount, bank_ref? }]
-- }
-- Prices come from the catalog: product price; combo fixed price; service general price, or
-- for a by-weight service the price for the pet's species and weight at this branch (the
-- line's weight_kg, else the pet's latest weight). A pet must belong to the invoice customer.
-- A discount above 10% of the subtotal needs "pos: Sửa".
create or replace function public.create_invoice(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_discount_limit constant numeric := 0.10;
  v_uid       uuid := (select auth.uid());
  v_branch    uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer  uuid := nullif(p ->> 'customer_id', '')::uuid;
  v_discount  numeric := coalesce(nullif(p ->> 'discount_amount', '')::numeric, 0);
  v_shift     uuid;
  v_id        uuid;
  v_code      text;
  v_line      jsonb;
  v_pay       jsonb;
  v_line_no   int := 0;
  v_kind      text;
  v_item      uuid;
  v_pet       uuid;
  v_species   uuid;
  v_weight    numeric;
  v_qty       numeric;
  v_name      text;
  v_unit      text;
  v_price     numeric;
  v_subtotal  numeric := 0;
  v_total     numeric;
  v_paid      numeric := 0;
  v_cash      numeric := 0;
  v_change    numeric;
  v_method    text;
  v_amount    numeric;
  v_product   public.products;
  v_service   public.pet_services;
  v_combo     public.pet_service_combos;
begin
  if v_uid is null or v_branch is null or not public.can_pos('CREATE', v_branch) then
    raise exception 'not allowed to sell at this branch' using errcode = '42501';
  end if;

  select id into v_shift
  from public.cash_shifts
  where branch_id = v_branch and opened_by = v_uid and status = 'open';
  if v_shift is null then
    raise exception 'open a cash shift before selling' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  -- The buyer: a customer, a web account that becomes one, or a new walk-in typed at the
  -- counter (matched by phone, as register_pet does). No customer = anonymous sale.
  v_customer := coalesce(v_customer, nullif(p #>> '{customer,id}', '')::uuid);
  if v_customer is null and nullif(p #>> '{customer,user_id}', '') is not null then
    select id into v_customer from public.customers where user_id = (p #>> '{customer,user_id}')::uuid;
    if v_customer is null then
      insert into public.customers (full_name, phone, email, user_id, created_by)
      select coalesce(nullif(btrim(u.full_name), ''), u.display_name, u.email), u.phone_number, u.email, u.id, v_uid
      from public.users u
      where u.id = (p #>> '{customer,user_id}')::uuid and u.phone_number is not null
      on conflict on constraint customers_phone_digits_key
        do update set user_id = coalesce(public.customers.user_id, excluded.user_id), updated_at = now()
      returning id into v_customer;
    end if;
    if v_customer is null then
      raise exception 'account has no phone number' using errcode = 'P0002';
    end if;
  elsif v_customer is null and nullif(btrim(p #>> '{customer,phone}'), '') is not null then
    insert into public.customers (full_name, phone, email, created_by)
    values (
      btrim(p #>> '{customer,full_name}'),
      btrim(p #>> '{customer,phone}'),
      nullif(btrim(p #>> '{customer,email}'), ''),
      v_uid
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  elsif v_customer is not null and not exists (select 1 from public.customers where id = v_customer) then
    raise exception 'customer % not found', v_customer using errcode = 'P0002';
  end if;

  if jsonb_array_length(coalesce(p -> 'lines', '[]'::jsonb)) = 0 then
    raise exception 'an invoice needs at least one line' using errcode = '22023';
  end if;

  v_code := public.next_doc_code(v_branch, 'HD');
  insert into public.invoices (
    code, branch_id, shift_id, customer_id, customer_name, customer_phone, cashier_name,
    subtotal, discount_amount, total, note, created_by
  )
  select
    v_code, v_branch, v_shift, v_customer, c.full_name, c.phone, public.staff_display_name(v_uid),
    0, 0, 0, nullif(btrim(p ->> 'note'), ''), v_uid
  from (select 1) as one
  left join public.customers c on c.id = v_customer
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p -> 'lines') loop
    v_line_no := v_line_no + 1;
    v_kind := v_line ->> 'type';
    v_item := nullif(v_line ->> 'id', '')::uuid;
    v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 1);
    v_pet := nullif(v_line ->> 'pet_id', '')::uuid;
    v_weight := null;
    v_unit := null;

    if v_qty <= 0 then
      raise exception 'line %: quantity must be more than zero', v_line_no using errcode = '22023';
    end if;

    if v_pet is not null then
      if v_customer is null or not exists (
        select 1 from public.pet_owners
        where pet_id = v_pet and customer_id = v_customer and to_date is null
      ) then
        raise exception 'line %: the pet does not belong to this customer', v_line_no using errcode = '22023';
      end if;
    end if;

    if v_kind = 'product' then
      select * into v_product from public.products where id = v_item and is_active;
      if not found then
        raise exception 'line %: product is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_product.name;
      v_unit := v_product.unit;
      v_price := v_product.price;
      -- Inventory module: deduct stock here by lot, earliest expiry first (FEFO).
    elsif v_kind = 'combo' then
      select * into v_combo from public.pet_service_combos
      where id = v_item and status = 1 and is_active;
      if not found or v_combo.price is null then
        raise exception 'line %: combo is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_combo.name;
      v_price := v_combo.price;
    elsif v_kind = 'service' then
      select * into v_service from public.pet_services where id = v_item and is_active;
      if not found then
        raise exception 'line %: service is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_service.name;
      if v_service.type = 'by_weight' then
        if v_pet is null then
          raise exception 'line %: pick the pet for a by-weight service', v_line_no using errcode = '22023';
        end if;
        select species_id into v_species from public.pets where id = v_pet;
        v_weight := coalesce(
          nullif(v_line ->> 'weight_kg', '')::numeric,
          (select weight_kg from public.pet_weight_logs where pet_id = v_pet order by measured_at desc limit 1)
        );
        if v_weight is null or v_weight <= 0 then
          raise exception 'line %: the pet has no weight yet', v_line_no using errcode = '22023';
        end if;
        v_price := public.get_service_price(v_species, v_service.id, v_weight, v_branch);
      else
        v_price := v_service.general_price;
      end if;
      if v_price is null then
        raise exception 'line %: service has no price for this pet', v_line_no using errcode = 'P0002';
      end if;
    else
      raise exception 'line %: unknown type %', v_line_no, v_kind using errcode = '22023';
    end if;

    insert into public.invoice_lines (
      invoice_id, line_no, item_type, product_id, service_id, combo_id, pet_id, pet_name,
      name, unit, qty, unit_price, amount, weight_kg
    ) values (
      v_id, v_line_no, v_kind,
      case when v_kind = 'product' then v_item end,
      case when v_kind = 'service' then v_item end,
      case when v_kind = 'combo' then v_item end,
      v_pet, (select name from public.pets where id = v_pet), v_name, v_unit, v_qty, v_price, round(v_qty * v_price, 2), v_weight
    );
    v_subtotal := v_subtotal + round(v_qty * v_price, 2);
  end loop;

  if v_discount < 0 or v_discount > v_subtotal then
    raise exception 'discount must be between 0 and the subtotal' using errcode = '22023';
  end if;
  if v_discount > v_subtotal * c_discount_limit and not public.can_pos('UPDATE', v_branch) then
    raise exception 'a discount above 10%% needs a manager' using errcode = '42501', hint = 'discount_limit';
  end if;
  v_total := v_subtotal - v_discount;

  for v_pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
    v_method := v_pay ->> 'method';
    v_amount := coalesce(nullif(v_pay ->> 'amount', '')::numeric, 0);
    if v_amount <= 0 then
      continue;
    end if;
    if v_method not in ('cash', 'transfer', 'card') then
      raise exception 'unknown payment method %', v_method using errcode = '22023';
    end if;
    insert into public.payments (invoice_id, method, amount, bank_ref)
    values (v_id, v_method, v_amount, nullif(btrim(v_pay ->> 'bank_ref'), ''));
    v_paid := v_paid + v_amount;
    if v_method = 'cash' then
      v_cash := v_cash + v_amount;
    end if;
  end loop;

  if v_paid < v_total then
    raise exception 'payments do not cover the total' using errcode = '22023', hint = 'underpaid';
  end if;
  v_change := v_paid - v_total;
  -- Only cash can be overpaid and handed back.
  if v_change > v_cash then
    raise exception 'transfer and card cannot exceed the total' using errcode = '22023', hint = 'overpaid';
  end if;

  update public.invoices
  set subtotal = v_subtotal,
      discount_amount = v_discount,
      total = v_total,
      paid_amount = v_paid,
      change_amount = v_change
  where id = v_id;

  return jsonb_build_object('id', v_id, 'code', v_code, 'total', v_total, 'change_amount', v_change);
end;
$$;

revoke execute on function public.create_invoice(jsonb) from public, anon;
grant execute on function public.create_invoice(jsonb) to authenticated;

-- Cancels a paid invoice while its shift is still open (the refund comes out of that drawer).
-- Returns after a shift is closed belong to the returns flow, which comes later.
create or replace function public.cancel_invoice(p_id uuid, p_reason text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_invoice public.invoices;
begin
  select * into v_invoice from public.invoices where id = p_id for update;
  if not found then
    raise exception 'invoice % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_pos('DELETE', v_invoice.branch_id) then
    raise exception 'not allowed to cancel invoices' using errcode = '42501';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'invoice is already cancelled' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'a reason is required' using errcode = '22023';
  end if;
  if not exists (select 1 from public.cash_shifts where id = v_invoice.shift_id and status = 'open') then
    raise exception 'the shift of this invoice is closed' using errcode = '22023', hint = 'shift_closed';
  end if;

  update public.invoices
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = (select auth.uid()),
      cancel_reason = btrim(p_reason)
  where id = p_id;
end;
$$;

revoke execute on function public.cancel_invoice(uuid, text) from public, anon;
grant execute on function public.cancel_invoice(uuid, text) to authenticated;

notify pgrst, 'reload schema';
