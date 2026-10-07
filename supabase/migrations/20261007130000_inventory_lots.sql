-- Inventory by lot and expiry, first-expiry-first-out (docs: pet-care-plan/ke-hoach-ba-kien-truc.md,
-- M6 and section 1.3 case 1).
--
--  1. Stock lives in lots per branch: (branch, product, lot number, expiry date) with a quantity
--     on hand and a unit cost. The catalog stays shared; stock is per branch.
--  2. Stock only changes through documents, each one leaving a row in stock_movements (the
--     stock card): goods receipts (NK), write-offs (XH), stock counts (KK), counter sales and
--     their cancellation, and customer returns (TH).
--  3. A counter sale takes stock FEFO: the lot that expires first goes first, expired lots are
--     never sold, and a sale fails when the branch does not have enough unexpired stock. Stock
--     never goes negative.
--  4. Returns after a shift is closed: the refund comes out of the returning cashier's open
--     shift and the goods go back into the lots they were sold from.
--  5. A product with track_stock = false (a bag, a service supply) sells without stock.
--
-- Permission code "inventory": VIEW = see stock and documents, CREATE = draft documents and post
-- goods receipts, UPDATE = post write-offs and stock counts (manager approval) and set minimum
-- stock, DELETE = cancel a posted receipt. Admin accounts keep full access, as elsewhere.
-- Runs after 20261007120000_pos_invoices.sql. Safe to run more than once.

-- --------------------------------------------------------------- permissions
insert into public.permissions (name, description, methods, module, sort_order) values
  ('inventory', 'Kho: tồn theo lô và hạn dùng, phiếu nhập, xuất hủy, kiểm kê, nhà cung cấp',
   array['CREATE','VIEW','DELETE','UPDATE','EXPORT','ALL'], 'Kho & sản phẩm', 30)
on conflict (name) do nothing;

insert into public.roles (name, description) values ('inventory', 'Thủ kho')
on conflict (name) do nothing;

insert into public.role_permissions (role, permission, methods)
select r.role, r.permission, r.methods
from (values
  ('inventory', 'inventory', array['VIEW','CREATE']),
  ('inventory', 'products',  array['VIEW']),
  ('admin',     'inventory', array['ALL'])
) as r(role, permission, methods)
where exists (select 1 from public.roles where name = r.role)
on conflict do nothing;

-- Inventory check used by the RPCs and policies: the "inventory" grant at that branch, or an
-- admin account.
create or replace function public.can_inventory(p_method text, p_branch uuid default null) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('inventory', p_method, p_branch));
$$;

revoke execute on function public.can_inventory(text, uuid) from public, anon;
grant execute on function public.can_inventory(text, uuid) to authenticated;

-- Expiry is judged by the calendar day in Vietnam, not UTC.
create or replace function public.business_date() returns date
language sql
stable
set search_path = ''
as $$
  select (now() at time zone 'Asia/Ho_Chi_Minh')::date;
$$;

-- ------------------------------------------------------------------ products
alter table public.products
  add column if not exists track_stock boolean not null default true;

-- ----------------------------------------------------------------- suppliers
create table if not exists public.suppliers (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(btrim(name)) > 0),
  phone      text,
  email      text,
  address    text,
  tax_code   text,
  note       text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Minimum stock per branch, for the "low stock" alert.
create table if not exists public.stock_thresholds (
  branch_id  uuid not null references public.branches(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  min_qty    numeric(12,2) not null check (min_qty > 0),
  updated_at timestamptz not null default now(),
  primary key (branch_id, product_id)
);

-- ---------------------------------------------------------------------- lots
-- One row per (branch, product, lot number, expiry). Receiving the same lot again adds to it
-- at a weighted unit cost. Products without a lot number or expiry use '' and null.
create table if not exists public.stock_lots (
  id          uuid primary key default gen_random_uuid(),
  branch_id   uuid not null references public.branches(id) on delete restrict,
  product_id  uuid not null references public.products(id) on delete restrict,
  lot_no      text not null default '',
  expiry_date date,
  unit_cost   numeric(14,2) not null default 0 check (unit_cost >= 0),
  qty_on_hand numeric(12,2) not null default 0 check (qty_on_hand >= 0),
  received_at timestamptz not null default now(),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint stock_lots_identity_key unique nulls not distinct (branch_id, product_id, lot_no, expiry_date)
);
create index if not exists stock_lots_fefo_idx
  on public.stock_lots (branch_id, product_id, expiry_date nulls last, received_at)
  where qty_on_hand > 0;
create index if not exists stock_lots_product_idx on public.stock_lots (product_id);

-- ------------------------------------------------------------------ documents
create table if not exists public.stock_documents (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  branch_id      uuid not null references public.branches(id) on delete restrict,
  doc_type       text not null check (doc_type in ('receipt', 'writeoff', 'count')),
  status         text not null default 'draft' check (status in ('draft', 'posted', 'cancelled')),
  supplier_id    uuid references public.suppliers(id) on delete restrict,
  -- The supplier's own invoice or delivery note number.
  supplier_ref   text,
  note           text,
  -- Receipt: value received. Write-off: value written off. Count: value of the difference.
  total_cost     numeric(16,2) not null default 0,
  created_by     uuid not null references auth.users(id) on delete restrict,
  created_by_name text,
  posted_by      uuid references auth.users(id) on delete restrict,
  posted_by_name text,
  posted_at      timestamptz,
  cancelled_by   uuid references auth.users(id) on delete restrict,
  cancelled_by_name text,
  cancelled_at   timestamptz,
  cancel_reason  text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (status <> 'posted' or posted_at is not null),
  check ((status = 'cancelled') = (cancelled_at is not null)),
  check (supplier_id is null or doc_type = 'receipt')
);
create index if not exists stock_documents_branch_created_idx
  on public.stock_documents (branch_id, created_at desc);

-- Receipt lines name a lot by number and expiry (the lot is found or created when posted);
-- write-off and count lines point at an existing lot.
create table if not exists public.stock_document_lines (
  id          uuid primary key default gen_random_uuid(),
  document_id uuid not null references public.stock_documents(id) on delete cascade,
  line_no     int not null,
  product_id  uuid not null references public.products(id) on delete restrict,
  lot_id      uuid references public.stock_lots(id) on delete restrict,
  lot_no      text not null default '',
  expiry_date date,
  -- Receipt and write-off: the quantity. Count: the difference, set when posted.
  qty         numeric(12,2) not null default 0,
  unit_cost   numeric(14,2) not null default 0 check (unit_cost >= 0),
  -- Count only: what the system held when posted, and what was counted.
  system_qty  numeric(12,2),
  counted_qty numeric(12,2) check (counted_qty >= 0),
  note        text,
  unique (document_id, line_no)
);
create index if not exists stock_document_lines_lot_idx on public.stock_document_lines (lot_id) where lot_id is not null;
create index if not exists stock_document_lines_product_idx on public.stock_document_lines (product_id);

-- ------------------------------------------------------------------- returns
create table if not exists public.sales_returns (
  id              uuid primary key default gen_random_uuid(),
  code            text not null unique,
  branch_id       uuid not null references public.branches(id) on delete restrict,
  invoice_id      uuid not null references public.invoices(id) on delete restrict,
  -- The shift whose drawer paid the refund (the returning cashier's, not the sale's).
  shift_id        uuid not null references public.cash_shifts(id) on delete restrict,
  refund_method   text not null check (refund_method in ('cash', 'transfer')),
  refund_amount   numeric(14,2) not null check (refund_amount >= 0),
  reason          text not null,
  created_by      uuid not null references auth.users(id) on delete restrict,
  created_by_name text,
  created_at      timestamptz not null default now()
);
create index if not exists sales_returns_invoice_idx on public.sales_returns (invoice_id);
create index if not exists sales_returns_shift_idx on public.sales_returns (shift_id);

create table if not exists public.sales_return_lines (
  id              uuid primary key default gen_random_uuid(),
  return_id       uuid not null references public.sales_returns(id) on delete cascade,
  invoice_line_id uuid not null references public.invoice_lines(id) on delete restrict,
  product_id      uuid not null references public.products(id) on delete restrict,
  name            text not null,
  qty             numeric(10,2) not null check (qty > 0),
  amount          numeric(14,2) not null check (amount >= 0)
);
create index if not exists sales_return_lines_return_idx on public.sales_return_lines (return_id);
create index if not exists sales_return_lines_invoice_line_idx on public.sales_return_lines (invoice_line_id);

-- What the goods sold on an invoice line cost, from the lots they came out of.
alter table public.invoice_lines add column if not exists cost_amount numeric(14,2);

-- ----------------------------------------------------------------- movements
-- The stock card: append-only, one row per change of one lot. qty is signed.
create table if not exists public.stock_movements (
  id               uuid primary key default gen_random_uuid(),
  branch_id        uuid not null references public.branches(id) on delete restrict,
  product_id       uuid not null references public.products(id) on delete restrict,
  lot_id           uuid not null references public.stock_lots(id) on delete restrict,
  qty              numeric(12,2) not null check (qty <> 0),
  unit_cost        numeric(14,2) not null,
  reason           text not null check (reason in (
                     'receipt', 'receipt_cancel', 'sale', 'sale_cancel', 'return', 'writeoff', 'count')),
  -- The lot's quantity right after this movement.
  balance_after    numeric(12,2) not null,
  document_id      uuid references public.stock_documents(id) on delete restrict,
  document_line_id uuid references public.stock_document_lines(id) on delete restrict,
  invoice_id       uuid references public.invoices(id) on delete restrict,
  invoice_line_id  uuid references public.invoice_lines(id) on delete restrict,
  return_id        uuid references public.sales_returns(id) on delete restrict,
  created_by       uuid references auth.users(id) on delete restrict,
  created_at       timestamptz not null default now()
);
create index if not exists stock_movements_product_idx on public.stock_movements (branch_id, product_id, created_at desc);
create index if not exists stock_movements_lot_idx on public.stock_movements (lot_id, created_at);
create index if not exists stock_movements_document_idx on public.stock_movements (document_id) where document_id is not null;
create index if not exists stock_movements_invoice_idx on public.stock_movements (invoice_id) where invoice_id is not null;
create index if not exists stock_movements_invoice_line_idx on public.stock_movements (invoice_line_id) where invoice_line_id is not null;
create index if not exists stock_movements_return_idx on public.stock_movements (return_id) where return_id is not null;

do $$
declare t text;
begin
  foreach t in array array['suppliers', 'stock_lots', 'stock_documents', 'stock_thresholds'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ----------------------------------------------------------------------- RLS
alter table public.suppliers            enable row level security;
alter table public.stock_thresholds     enable row level security;
alter table public.stock_lots           enable row level security;
alter table public.stock_documents      enable row level security;
alter table public.stock_document_lines enable row level security;
alter table public.stock_movements      enable row level security;
alter table public.sales_returns        enable row level security;
alter table public.sales_return_lines   enable row level security;

-- Suppliers are shared reference data, written straight from the admin screen.
drop policy if exists "inventory read" on public.suppliers;
create policy "inventory read" on public.suppliers for select to authenticated
  using ((select public.can_inventory('VIEW')));
drop policy if exists "inventory insert" on public.suppliers;
create policy "inventory insert" on public.suppliers for insert to authenticated
  with check ((select public.can_inventory('CREATE')));
drop policy if exists "inventory update" on public.suppliers;
create policy "inventory update" on public.suppliers for update to authenticated
  using ((select public.can_inventory('UPDATE')))
  with check ((select public.can_inventory('UPDATE')));

drop policy if exists "inventory read" on public.stock_thresholds;
create policy "inventory read" on public.stock_thresholds for select to authenticated
  using ((select public.can_inventory('VIEW', branch_id)));

-- Cashiers see the lots of their branch: the counter shows what is in stock.
drop policy if exists "inventory read" on public.stock_lots;
create policy "inventory read" on public.stock_lots for select to authenticated
  using ((select public.can_inventory('VIEW', branch_id)) or (select public.can_pos('CREATE', branch_id)));

drop policy if exists "inventory read" on public.stock_documents;
create policy "inventory read" on public.stock_documents for select to authenticated
  using ((select public.can_inventory('VIEW', branch_id)));

drop policy if exists "inventory read" on public.stock_document_lines;
create policy "inventory read" on public.stock_document_lines for select to authenticated
  using (exists (select 1 from public.stock_documents d where d.id = document_id));

drop policy if exists "inventory read" on public.stock_movements;
create policy "inventory read" on public.stock_movements for select to authenticated
  using ((select public.can_inventory('VIEW', branch_id)));

-- Returns are visible with their invoice.
drop policy if exists "pos read" on public.sales_returns;
create policy "pos read" on public.sales_returns for select to authenticated
  using (exists (select 1 from public.invoices i where i.id = invoice_id));

drop policy if exists "pos read" on public.sales_return_lines;
create policy "pos read" on public.sales_return_lines for select to authenticated
  using (exists (select 1 from public.sales_returns r where r.id = return_id));

revoke delete on public.suppliers from anon, authenticated;
revoke insert, update, delete on
  public.stock_thresholds, public.stock_lots, public.stock_documents, public.stock_document_lines,
  public.stock_movements, public.sales_returns, public.sales_return_lines
  from anon, authenticated;
revoke all on
  public.suppliers, public.stock_thresholds, public.stock_lots, public.stock_documents,
  public.stock_document_lines, public.stock_movements, public.sales_returns, public.sales_return_lines
  from anon;

-- ------------------------------------------------------------ moving stock
-- The only writer of stock_lots.qty_on_hand: changes one lot by p_qty (signed) and records the
-- movement. Refuses to take a lot below zero. Returns the unit cost recorded.
create or replace function public.move_stock(
  p_lot           uuid,
  p_qty           numeric,
  p_reason        text,
  p_document      uuid default null,
  p_document_line uuid default null,
  p_invoice       uuid default null,
  p_invoice_line  uuid default null,
  p_return        uuid default null,
  p_unit_cost     numeric default null
) returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lot  public.stock_lots;
  v_name text;
begin
  select * into v_lot from public.stock_lots where id = p_lot for update;
  if not found then
    raise exception 'lot % not found', p_lot using errcode = 'P0002';
  end if;
  if v_lot.qty_on_hand + p_qty < 0 then
    select name into v_name from public.products where id = v_lot.product_id;
    raise exception 'lot "%" of % holds only %', v_lot.lot_no, v_name, v_lot.qty_on_hand
      using errcode = 'P0001', hint = 'lot_short', detail = v_name;
  end if;

  update public.stock_lots set qty_on_hand = qty_on_hand + p_qty where id = p_lot;

  insert into public.stock_movements (
    branch_id, product_id, lot_id, qty, unit_cost, reason, balance_after,
    document_id, document_line_id, invoice_id, invoice_line_id, return_id, created_by
  ) values (
    v_lot.branch_id, v_lot.product_id, p_lot, p_qty, coalesce(p_unit_cost, v_lot.unit_cost), p_reason,
    v_lot.qty_on_hand + p_qty, p_document, p_document_line, p_invoice, p_invoice_line, p_return,
    (select auth.uid())
  );
  return coalesce(p_unit_cost, v_lot.unit_cost);
end;
$$;

revoke execute on function public.move_stock(uuid, numeric, text, uuid, uuid, uuid, uuid, uuid, numeric)
  from public, anon, authenticated;

-- Takes p_qty of a product out of a branch for an invoice line, earliest expiry first, skipping
-- expired lots. Returns the cost of what was taken, or null for a product without stock.
create or replace function public.take_stock_fefo(
  p_branch       uuid,
  p_product      uuid,
  p_qty          numeric,
  p_invoice      uuid,
  p_invoice_line uuid
) returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_track boolean;
  v_name  text;
  v_left  numeric := p_qty;
  v_take  numeric;
  v_cost  numeric := 0;
  v_lot   record;
begin
  select track_stock, name into v_track, v_name from public.products where id = p_product;
  if not coalesce(v_track, false) then
    return null;
  end if;

  for v_lot in
    select id, qty_on_hand, unit_cost
    from public.stock_lots
    where branch_id = p_branch
      and product_id = p_product
      and qty_on_hand > 0
      and (expiry_date is null or expiry_date >= public.business_date())
    order by expiry_date asc nulls last, received_at, id
    for update
  loop
    exit when v_left <= 0;
    v_take := least(v_left, v_lot.qty_on_hand);
    perform public.move_stock(v_lot.id, -v_take, 'sale', p_invoice => p_invoice, p_invoice_line => p_invoice_line);
    v_cost := v_cost + v_take * v_lot.unit_cost;
    v_left := v_left - v_take;
  end loop;

  if v_left > 0 then
    raise exception 'not enough stock for %: % short', v_name, v_left
      using errcode = 'P0001', hint = 'out_of_stock', detail = v_name;
  end if;
  return round(v_cost, 2);
end;
$$;

revoke execute on function public.take_stock_fefo(uuid, uuid, numeric, uuid, uuid) from public, anon, authenticated;

-- ------------------------------------------------------- the sale takes stock
-- create_invoice inserts the lines; each product line takes its stock here, in the same
-- transaction, so a sale without stock fails as a whole.
create or replace function public.invoice_line_take_stock() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid;
  v_cost   numeric;
begin
  select branch_id into v_branch from public.invoices where id = new.invoice_id;
  v_cost := public.take_stock_fefo(v_branch, new.product_id, new.qty, new.invoice_id, new.id);
  if v_cost is not null then
    update public.invoice_lines set cost_amount = v_cost where id = new.id;
  end if;
  return null;
end;
$$;

revoke execute on function public.invoice_line_take_stock() from public, anon, authenticated;

drop trigger if exists take_stock on public.invoice_lines;
create trigger take_stock after insert on public.invoice_lines
  for each row when (new.item_type = 'product')
  execute function public.invoice_line_take_stock();

-- Cancelling an invoice puts every lot back. An invoice with returns cannot be cancelled: the
-- returned goods were already refunded.
create or replace function public.invoice_cancel_restock() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  if exists (select 1 from public.sales_returns where invoice_id = new.id) then
    raise exception 'invoice % has returns', new.code using errcode = 'P0001', hint = 'has_returns';
  end if;

  for v_row in
    select lot_id, invoice_line_id, -sum(qty) as qty
    from public.stock_movements
    where invoice_id = new.id
    group by lot_id, invoice_line_id
    having sum(qty) < 0
  loop
    perform public.move_stock(
      v_row.lot_id, v_row.qty, 'sale_cancel', p_invoice => new.id, p_invoice_line => v_row.invoice_line_id
    );
  end loop;
  return null;
end;
$$;

revoke execute on function public.invoice_cancel_restock() from public, anon, authenticated;

drop trigger if exists restock_on_cancel on public.invoices;
create trigger restock_on_cancel after update of status on public.invoices
  for each row when (old.status = 'paid' and new.status = 'cancelled')
  execute function public.invoice_cancel_restock();

-- ------------------------------------------------------------ stock documents
-- Creates or replaces a draft document and returns its id.
-- p: {
--   id?, branch_id, doc_type: 'receipt' | 'writeoff' | 'count', supplier_id?, supplier_ref?, note?,
--   lines: [
--     receipt:  { product_id, lot_no?, expiry_date?, qty, unit_cost, note? }
--     writeoff: { lot_id, qty, note? }
--     count:    { lot_id, counted_qty, note? }
--   ]
-- }
create or replace function public.save_stock_document(p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id       uuid := nullif(p ->> 'id', '')::uuid;
  v_doc      public.stock_documents;
  v_branch   uuid;
  v_type     text;
  v_supplier uuid := nullif(p ->> 'supplier_id', '')::uuid;
  v_line     jsonb;
  v_line_no  int := 0;
  v_product  public.products;
  v_lot      public.stock_lots;
  v_qty      numeric;
  v_cost     numeric;
  v_total    numeric := 0;
begin
  if v_id is null then
    v_branch := nullif(p ->> 'branch_id', '')::uuid;
    v_type := p ->> 'doc_type';
    if v_type is null or v_type not in ('receipt', 'writeoff', 'count') then
      raise exception 'unknown document type %', v_type using errcode = '22023';
    end if;
    if (select auth.uid()) is null or v_branch is null or not public.can_inventory('CREATE', v_branch) then
      raise exception 'not allowed to write stock documents at this branch' using errcode = '42501';
    end if;
    insert into public.stock_documents (code, branch_id, doc_type, created_by, created_by_name)
    values (
      public.next_doc_code(v_branch, case v_type when 'receipt' then 'NK' when 'writeoff' then 'XH' else 'KK' end),
      v_branch, v_type, (select auth.uid()), public.staff_display_name((select auth.uid()))
    )
    returning * into v_doc;
  else
    select * into v_doc from public.stock_documents where id = v_id for update;
    if not found then
      raise exception 'document % not found', v_id using errcode = 'P0002';
    end if;
    if not public.can_inventory('CREATE', v_doc.branch_id) then
      raise exception 'not allowed to write stock documents at this branch' using errcode = '42501';
    end if;
    if v_doc.status <> 'draft' then
      raise exception 'only a draft can be edited' using errcode = '22023', hint = 'not_draft';
    end if;
  end if;

  if v_supplier is not null and v_doc.doc_type <> 'receipt' then
    v_supplier := null;
  end if;
  if v_supplier is not null and not exists (select 1 from public.suppliers where id = v_supplier) then
    raise exception 'supplier % not found', v_supplier using errcode = 'P0002';
  end if;

  delete from public.stock_document_lines where document_id = v_doc.id;

  for v_line in select * from jsonb_array_elements(coalesce(p -> 'lines', '[]'::jsonb)) loop
    v_line_no := v_line_no + 1;

    if v_doc.doc_type = 'receipt' then
      select * into v_product from public.products where id = nullif(v_line ->> 'product_id', '')::uuid;
      if not found then
        raise exception 'line %: product not found', v_line_no using errcode = 'P0002';
      end if;
      if not v_product.track_stock then
        raise exception 'line %: % does not track stock', v_line_no, v_product.name
          using errcode = '22023', hint = 'untracked_product', detail = v_product.name;
      end if;
      v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
      v_cost := coalesce(nullif(v_line ->> 'unit_cost', '')::numeric, 0);
      if v_qty <= 0 or v_cost < 0 then
        raise exception 'line %: quantity must be more than zero and cost zero or more', v_line_no
          using errcode = '22023';
      end if;
      insert into public.stock_document_lines (
        document_id, line_no, product_id, lot_no, expiry_date, qty, unit_cost, note
      ) values (
        v_doc.id, v_line_no, v_product.id,
        coalesce(btrim(v_line ->> 'lot_no'), ''),
        nullif(v_line ->> 'expiry_date', '')::date,
        v_qty, v_cost, nullif(btrim(v_line ->> 'note'), '')
      );
      v_total := v_total + round(v_qty * v_cost, 2);
    else
      select * into v_lot from public.stock_lots
      where id = nullif(v_line ->> 'lot_id', '')::uuid and branch_id = v_doc.branch_id;
      if not found then
        raise exception 'line %: lot not found at this branch', v_line_no using errcode = 'P0002';
      end if;
      if exists (
        select 1 from public.stock_document_lines where document_id = v_doc.id and lot_id = v_lot.id
      ) then
        raise exception 'line %: the lot is listed twice', v_line_no using errcode = '22023';
      end if;
      if v_doc.doc_type = 'writeoff' then
        v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
        if v_qty <= 0 then
          raise exception 'line %: quantity must be more than zero', v_line_no using errcode = '22023';
        end if;
        insert into public.stock_document_lines (
          document_id, line_no, product_id, lot_id, lot_no, expiry_date, qty, unit_cost, note
        ) values (
          v_doc.id, v_line_no, v_lot.product_id, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
          v_qty, v_lot.unit_cost, nullif(btrim(v_line ->> 'note'), '')
        );
      else
        v_qty := nullif(v_line ->> 'counted_qty', '')::numeric;
        if v_qty is null or v_qty < 0 then
          raise exception 'line %: counted quantity must be zero or more', v_line_no using errcode = '22023';
        end if;
        insert into public.stock_document_lines (
          document_id, line_no, product_id, lot_id, lot_no, expiry_date, unit_cost, system_qty, counted_qty, note
        ) values (
          v_doc.id, v_line_no, v_lot.product_id, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
          v_lot.unit_cost, v_lot.qty_on_hand, v_qty, nullif(btrim(v_line ->> 'note'), '')
        );
      end if;
    end if;
  end loop;

  update public.stock_documents
  set supplier_id = v_supplier,
      supplier_ref = case when v_doc.doc_type = 'receipt' then nullif(btrim(p ->> 'supplier_ref'), '') end,
      note = nullif(btrim(p ->> 'note'), ''),
      total_cost = v_total
  where id = v_doc.id;

  return v_doc.id;
end;
$$;

revoke execute on function public.save_stock_document(jsonb) from public, anon;
grant execute on function public.save_stock_document(jsonb) to authenticated;

-- Posts a draft: the stock changes now. A receipt needs "inventory: CREATE"; a write-off or a
-- count changes stock without goods arriving, so it needs a manager ("inventory: UPDATE").
create or replace function public.post_stock_document(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doc    public.stock_documents;
  v_line   public.stock_document_lines;
  v_lot    public.stock_lots;
  v_lot_id uuid;
  v_diff   numeric;
  v_total  numeric := 0;
begin
  select * into v_doc from public.stock_documents where id = p_id for update;
  if not found then
    raise exception 'document % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_inventory(case when v_doc.doc_type = 'receipt' then 'CREATE' else 'UPDATE' end, v_doc.branch_id) then
    raise exception 'not allowed to post this document' using errcode = '42501', hint = 'needs_manager';
  end if;
  if v_doc.status <> 'draft' then
    raise exception 'only a draft can be posted' using errcode = '22023', hint = 'not_draft';
  end if;
  if not exists (select 1 from public.stock_document_lines where document_id = p_id) then
    raise exception 'the document has no lines' using errcode = '22023', hint = 'no_lines';
  end if;

  for v_line in select * from public.stock_document_lines where document_id = p_id order by line_no loop
    if v_doc.doc_type = 'receipt' then
      insert into public.stock_lots as l (branch_id, product_id, lot_no, expiry_date, unit_cost)
      values (v_doc.branch_id, v_line.product_id, v_line.lot_no, v_line.expiry_date, v_line.unit_cost)
      on conflict on constraint stock_lots_identity_key do update set updated_at = now()
      returning id into v_lot_id;

      -- Weighted cost when the lot already holds stock.
      update public.stock_lots
      set unit_cost = round((qty_on_hand * unit_cost + v_line.qty * v_line.unit_cost) / (qty_on_hand + v_line.qty), 2)
      where id = v_lot_id;

      perform public.move_stock(
        v_lot_id, v_line.qty, 'receipt', p_document => p_id, p_document_line => v_line.id,
        p_unit_cost => v_line.unit_cost
      );
      update public.stock_document_lines set lot_id = v_lot_id where id = v_line.id;
      v_total := v_total + round(v_line.qty * v_line.unit_cost, 2);

    elsif v_doc.doc_type = 'writeoff' then
      perform public.move_stock(v_line.lot_id, -v_line.qty, 'writeoff', p_document => p_id, p_document_line => v_line.id);
      select * into v_lot from public.stock_lots where id = v_line.lot_id;
      update public.stock_document_lines set unit_cost = v_lot.unit_cost where id = v_line.id;
      v_total := v_total + round(v_line.qty * v_lot.unit_cost, 2);

    else
      -- The difference is taken against the lot as it stands now, not when the draft was saved.
      select * into v_lot from public.stock_lots where id = v_line.lot_id for update;
      v_diff := v_line.counted_qty - v_lot.qty_on_hand;
      update public.stock_document_lines
      set system_qty = v_lot.qty_on_hand, qty = v_diff, unit_cost = v_lot.unit_cost
      where id = v_line.id;
      if v_diff <> 0 then
        perform public.move_stock(v_line.lot_id, v_diff, 'count', p_document => p_id, p_document_line => v_line.id);
      end if;
      v_total := v_total + round(v_diff * v_lot.unit_cost, 2);
    end if;
  end loop;

  update public.stock_documents
  set status = 'posted',
      posted_by = (select auth.uid()),
      posted_by_name = public.staff_display_name((select auth.uid())),
      posted_at = now(),
      total_cost = v_total
  where id = p_id;
end;
$$;

revoke execute on function public.post_stock_document(uuid) from public, anon;
grant execute on function public.post_stock_document(uuid) to authenticated;

-- Cancels a draft, or takes back a posted receipt while its goods are still all in stock
-- ("inventory: DELETE"). Posted write-offs and counts are corrected with a new count.
create or replace function public.cancel_stock_document(p_id uuid, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_doc  public.stock_documents;
  v_line public.stock_document_lines;
begin
  select * into v_doc from public.stock_documents where id = p_id for update;
  if not found then
    raise exception 'document % not found', p_id using errcode = 'P0002';
  end if;

  if v_doc.status = 'draft' then
    if not public.can_inventory('CREATE', v_doc.branch_id) then
      raise exception 'not allowed to cancel this document' using errcode = '42501';
    end if;
  elsif v_doc.status = 'posted' then
    if v_doc.doc_type <> 'receipt' then
      raise exception 'a posted write-off or count is corrected with a new count'
        using errcode = '22023', hint = 'posted_not_receipt';
    end if;
    if not public.can_inventory('DELETE', v_doc.branch_id) then
      raise exception 'not allowed to cancel a posted receipt' using errcode = '42501', hint = 'needs_manager';
    end if;
    if length(btrim(coalesce(p_reason, ''))) = 0 then
      raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
    end if;
    for v_line in select * from public.stock_document_lines where document_id = p_id order by line_no loop
      perform public.move_stock(
        v_line.lot_id, -v_line.qty, 'receipt_cancel', p_document => p_id, p_document_line => v_line.id,
        p_unit_cost => v_line.unit_cost
      );
    end loop;
  else
    raise exception 'document is already cancelled' using errcode = '22023', hint = 'not_draft';
  end if;

  update public.stock_documents
  set status = 'cancelled',
      cancelled_by = (select auth.uid()),
      cancelled_by_name = public.staff_display_name((select auth.uid())),
      cancelled_at = now(),
      cancel_reason = nullif(btrim(p_reason), '')
  where id = p_id;
end;
$$;

revoke execute on function public.cancel_stock_document(uuid, text) from public, anon;
grant execute on function public.cancel_stock_document(uuid, text) to authenticated;

-- Minimum stock of a product at a branch; null or zero clears it.
create or replace function public.set_min_stock(p_branch uuid, p_product uuid, p_min numeric) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_inventory('UPDATE', p_branch) then
    raise exception 'not allowed to set minimum stock' using errcode = '42501';
  end if;
  if coalesce(p_min, 0) <= 0 then
    delete from public.stock_thresholds where branch_id = p_branch and product_id = p_product;
  else
    insert into public.stock_thresholds (branch_id, product_id, min_qty)
    values (p_branch, p_product, p_min)
    on conflict (branch_id, product_id) do update set min_qty = excluded.min_qty;
  end if;
end;
$$;

revoke execute on function public.set_min_stock(uuid, uuid, numeric) from public, anon;
grant execute on function public.set_min_stock(uuid, uuid, numeric) to authenticated;

-- --------------------------------------------------------------- stock views
-- One row per stock-tracked product at a branch (active ones, and archived ones still holding
-- stock). sellable = unexpired stock, the only stock a sale can take.
create or replace function public.stock_rows(p_branch uuid, p_expiry_days int)
returns table (
  product_id  uuid,
  name        text,
  sku         text,
  barcode     text,
  unit        text,
  is_active   boolean,
  on_hand     numeric,
  sellable    numeric,
  expired     numeric,
  expiring    numeric,
  next_expiry date,
  stock_value numeric,
  min_qty     numeric
)
language sql
stable
security definer
set search_path = ''
as $$
  with today as (
    select public.business_date() as d
  ), lots as (
    select
      l.product_id,
      sum(l.qty_on_hand) as on_hand,
      coalesce(sum(l.qty_on_hand) filter (where l.expiry_date is null or l.expiry_date >= t.d), 0) as sellable,
      coalesce(sum(l.qty_on_hand) filter (where l.expiry_date < t.d), 0) as expired,
      coalesce(sum(l.qty_on_hand) filter (
        where l.expiry_date >= t.d and l.expiry_date < t.d + greatest(p_expiry_days, 0)), 0) as expiring,
      min(l.expiry_date) filter (where l.expiry_date >= t.d) as next_expiry,
      sum(l.qty_on_hand * l.unit_cost) as stock_value
    from public.stock_lots l
    cross join today t
    where l.branch_id = p_branch and l.qty_on_hand > 0
    group by l.product_id
  )
  select
    p.id, p.name, p.sku, p.barcode, p.unit, p.is_active,
    coalesce(l.on_hand, 0), coalesce(l.sellable, 0), coalesce(l.expired, 0), coalesce(l.expiring, 0),
    l.next_expiry, coalesce(l.stock_value, 0), th.min_qty
  from public.products p
  left join lots l on l.product_id = p.id
  left join public.stock_thresholds th on th.branch_id = p_branch and th.product_id = p.id
  where p.track_stock and (p.is_active or l.product_id is not null);
$$;

revoke execute on function public.stock_rows(uuid, int) from public, anon, authenticated;

-- The stock screen: filter 'all' | 'low' (below minimum) | 'out' (nothing sellable) |
-- 'expiring' (within p_expiry_days) | 'expired'. total_count is the size of the filtered list.
create or replace function public.stock_summary(
  p_branch      uuid,
  p_search      text default null,
  p_status      text default 'all',
  p_expiry_days int default 60,
  p_limit       int default 20,
  p_offset      int default 0
) returns table (
  product_id  uuid,
  name        text,
  sku         text,
  barcode     text,
  unit        text,
  is_active   boolean,
  on_hand     numeric,
  sellable    numeric,
  expired     numeric,
  expiring    numeric,
  next_expiry date,
  stock_value numeric,
  min_qty     numeric,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if not public.can_inventory('VIEW', p_branch) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  return query
  select s.*, count(*) over ()
  from public.stock_rows(p_branch, p_expiry_days) s
  where (v_term is null
         or s.name ilike '%' || v_term || '%'
         or s.sku ilike '%' || v_term || '%'
         or s.barcode = v_term)
    and case coalesce(p_status, 'all')
          when 'low' then s.min_qty is not null and s.sellable < s.min_qty
          when 'out' then s.sellable = 0
          when 'expiring' then s.expiring > 0
          when 'expired' then s.expired > 0
          else true
        end
  order by s.name
  limit greatest(coalesce(p_limit, 20), 1) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke execute on function public.stock_summary(uuid, text, text, int, int, int) from public, anon;
grant execute on function public.stock_summary(uuid, text, text, int, int, int) to authenticated;

-- Counts for the alert chips: { low, out, expiring, expired }.
create or replace function public.stock_alert_counts(p_branch uuid, p_expiry_days int default 60) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not public.can_inventory('VIEW', p_branch) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'low',      count(*) filter (where s.min_qty is not null and s.sellable < s.min_qty),
    'out',      count(*) filter (where s.sellable = 0),
    'expiring', count(*) filter (where s.expiring > 0),
    'expired',  count(*) filter (where s.expired > 0)
  ) into v_result
  from public.stock_rows(p_branch, p_expiry_days) s;
  return v_result;
end;
$$;

revoke execute on function public.stock_alert_counts(uuid, int) from public, anon;
grant execute on function public.stock_alert_counts(uuid, int) to authenticated;

-- What the counter can sell now of each product: unexpired stock at the branch. Products that
-- do not track stock are left out (they sell without limit).
create or replace function public.sellable_stock(p_branch uuid, p_products uuid[])
returns table (product_id uuid, qty numeric)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (public.can_pos('CREATE', p_branch) or public.can_inventory('VIEW', p_branch)) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  return query
  select p.id, coalesce(sum(l.qty_on_hand) filter (
           where l.expiry_date is null or l.expiry_date >= public.business_date()), 0)
  from public.products p
  left join public.stock_lots l on l.product_id = p.id and l.branch_id = p_branch and l.qty_on_hand > 0
  where p.id = any(p_products) and p.track_stock
  group by p.id;
end;
$$;

revoke execute on function public.sellable_stock(uuid, uuid[]) from public, anon;
grant execute on function public.sellable_stock(uuid, uuid[]) to authenticated;

-- ------------------------------------------------------------------- returns
-- Takes goods back on a paid invoice and refunds them from the caller's open shift.
-- p: { invoice_id, reason, refund_method: 'cash' | 'transfer', lines: [{ invoice_line_id, qty }] }
-- Only product lines are returned. Each line is refunded at what the customer paid for it,
-- the invoice discount spread over the lines. The goods go back into the lots they came from.
-- Needs "pos: DELETE", like cancelling an invoice. Returns { id, code, refund_amount }.
create or replace function public.create_sales_return(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_invoice  public.invoices;
  v_shift    uuid;
  v_method   text := coalesce(p ->> 'refund_method', 'cash');
  v_reason   text := btrim(coalesce(p ->> 'reason', ''));
  v_id       uuid;
  v_code     text;
  v_line     jsonb;
  v_inv_line public.invoice_lines;
  v_qty      numeric;
  v_returned numeric;
  v_amount   numeric;
  v_refund   numeric := 0;
  v_left     numeric;
  v_take     numeric;
  v_lot      record;
begin
  select * into v_invoice from public.invoices where id = nullif(p ->> 'invoice_id', '')::uuid for update;
  if not found then
    raise exception 'invoice not found' using errcode = 'P0002';
  end if;
  if v_uid is null or not public.can_pos('DELETE', v_invoice.branch_id) then
    raise exception 'not allowed to take returns' using errcode = '42501';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'invoice is cancelled' using errcode = '22023';
  end if;
  if v_method not in ('cash', 'transfer') then
    raise exception 'unknown refund method %', v_method using errcode = '22023';
  end if;
  if length(v_reason) = 0 then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  if jsonb_array_length(coalesce(p -> 'lines', '[]'::jsonb)) = 0 then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  select id into v_shift
  from public.cash_shifts
  where branch_id = v_invoice.branch_id and opened_by = v_uid and status = 'open';
  if v_shift is null then
    raise exception 'open a cash shift before refunding' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  v_code := public.next_doc_code(v_invoice.branch_id, 'TH');
  insert into public.sales_returns (
    code, branch_id, invoice_id, shift_id, refund_method, refund_amount, reason, created_by, created_by_name
  ) values (
    v_code, v_invoice.branch_id, v_invoice.id, v_shift, v_method, 0, v_reason, v_uid,
    public.staff_display_name(v_uid)
  )
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p -> 'lines') loop
    v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
    if v_qty <= 0 then
      continue;
    end if;

    select * into v_inv_line from public.invoice_lines
    where id = nullif(v_line ->> 'invoice_line_id', '')::uuid and invoice_id = v_invoice.id
    for update;
    if not found then
      raise exception 'the line is not on this invoice' using errcode = 'P0002';
    end if;
    if v_inv_line.item_type <> 'product' then
      raise exception '% is not a product', v_inv_line.name using errcode = '22023', hint = 'return_products_only';
    end if;

    select coalesce(sum(qty), 0) into v_returned
    from public.sales_return_lines where invoice_line_id = v_inv_line.id;
    if v_qty > v_inv_line.qty - v_returned then
      raise exception 'only % of % can still be returned', v_inv_line.qty - v_returned, v_inv_line.name
        using errcode = '22023', hint = 'return_too_much', detail = v_inv_line.name;
    end if;

    v_amount := case when v_invoice.subtotal > 0
      then round(v_inv_line.amount * v_qty / v_inv_line.qty * v_invoice.total / v_invoice.subtotal, 2)
      else 0 end;
    insert into public.sales_return_lines (return_id, invoice_line_id, product_id, name, qty, amount)
    values (v_id, v_inv_line.id, v_inv_line.product_id, v_inv_line.name, v_qty, v_amount);
    v_refund := v_refund + v_amount;

    -- Back into the lots this line still has out, the latest taken first. A line sold before
    -- the product tracked stock has none and returns nothing to stock.
    v_left := v_qty;
    for v_lot in
      select lot_id, -sum(qty) as out_qty
      from public.stock_movements
      where invoice_line_id = v_inv_line.id
      group by lot_id
      having sum(qty) < 0
      order by max(created_at) desc, lot_id
    loop
      exit when v_left <= 0;
      v_take := least(v_left, v_lot.out_qty);
      perform public.move_stock(
        v_lot.lot_id, v_take, 'return', p_invoice => v_invoice.id, p_invoice_line => v_inv_line.id, p_return => v_id
      );
      v_left := v_left - v_take;
    end loop;
  end loop;

  if not exists (select 1 from public.sales_return_lines where return_id = v_id) then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  update public.sales_returns set refund_amount = v_refund where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'refund_amount', v_refund);
end;
$$;

revoke execute on function public.create_sales_return(jsonb) from public, anon;
grant execute on function public.create_sales_return(jsonb) to authenticated;

-- ------------------------------------------------------------- shift totals
-- As in 20261007120000_pos_invoices.sql, plus the refunds paid from this shift: cash refunds
-- come out of the drawer.
create or replace function public.cash_shift_summary(p_shift uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_shift  public.cash_shifts;
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
  ), ret as (
    select refund_method, count(*) as n, sum(refund_amount) as amount
    from public.sales_returns
    where shift_id = p_shift
    group by refund_method
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
    'return_count',    coalesce((select sum(n) from ret), 0),
    'refund_cash',     coalesce((select amount from ret where refund_method = 'cash'), 0),
    'refund_transfer', coalesce((select amount from ret where refund_method = 'transfer'), 0),
    'expected_cash',   v_shift.opening_cash
                         + coalesce((select amount from pay where method = 'cash'), 0)
                         - (select coalesce(sum(change_amount), 0) from inv where status = 'paid')
                         - coalesce((select amount from ret where refund_method = 'cash'), 0)
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.cash_shift_summary(uuid) from public, anon;
grant execute on function public.cash_shift_summary(uuid) to authenticated;

notify pgrst, 'reload schema';
