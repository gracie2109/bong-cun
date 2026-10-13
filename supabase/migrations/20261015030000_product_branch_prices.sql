-- Product module, step 3 (1/2): per-branch prices (docs/module-san-pham.md, 3.3 and 5.2).
-- products.price stays the general price; a row here overrides it at one branch.
-- Safe to run more than once.

create table if not exists public.product_branch_prices (
  product_id uuid not null references public.products(id) on delete cascade,
  branch_id  uuid not null references public.branches(id) on delete cascade,
  price      numeric(14,2) not null check (price >= 0),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (product_id, branch_id)
);
create index if not exists product_branch_prices_branch_idx on public.product_branch_prices (branch_id);

-- Prices are not secret; writes only go through set_product_branch_prices.
alter table public.product_branch_prices enable row level security;
drop policy if exists "public read" on public.product_branch_prices;
create policy "public read" on public.product_branch_prices for select to anon, authenticated using (true);
revoke insert, update, delete on public.product_branch_prices from anon, authenticated;

-- The one place a price is worked out: the branch price when there is one, else the general
-- price. No branch (the online shop) means the general price. p_unit is reserved for the unit
-- conversion step and ignored for now.
create or replace function public.product_unit_price(
  p_product uuid,
  p_branch  uuid default null,
  p_unit    uuid default null
) returns numeric
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select bp.price from public.product_branch_prices bp
     where bp.product_id = p_product and bp.branch_id = p_branch),
    (select p.price from public.products p where p.id = p_product)
  );
$$;

revoke execute on function public.product_unit_price(uuid, uuid, uuid) from public;
grant execute on function public.product_unit_price(uuid, uuid, uuid) to anon, authenticated;

-- p_prices: [{ branch_id, price }]; a null or missing price removes the branch price.
-- Every branch in the list needs "products: Sửa" at that branch (or an admin).
create or replace function public.set_product_branch_prices(p_product uuid, p_prices jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     jsonb;
  v_branch  uuid;
  v_price   numeric;
begin
  if jsonb_typeof(coalesce(p_prices, 'null'::jsonb)) <> 'array' then
    raise exception 'prices must be an array' using errcode = '22023';
  end if;
  if not exists (select 1 from public.products where id = p_product) then
    raise exception 'product % not found', p_product using errcode = 'P0002';
  end if;

  for v_row in select * from jsonb_array_elements(p_prices) loop
    v_branch := nullif(v_row ->> 'branch_id', '')::uuid;
    v_price := nullif(btrim(coalesce(v_row ->> 'price', '')), '')::numeric;

    if v_branch is null or not exists (select 1 from public.branches where id = v_branch) then
      raise exception 'branch not found' using errcode = 'P0002';
    end if;
    if not (coalesce((select public.is_admin()), false)
            or coalesce((select public.has_permission('products', 'UPDATE', v_branch)), false)) then
      raise exception 'not allowed to edit prices at this branch' using errcode = '42501';
    end if;
    if v_price is not null and v_price < 0 then
      raise exception 'price cannot be negative' using errcode = '22023', hint = 'price_negative';
    end if;

    if v_price is null then
      delete from public.product_branch_prices where product_id = p_product and branch_id = v_branch;
    else
      insert into public.product_branch_prices (product_id, branch_id, price, updated_by)
      values (p_product, v_branch, v_price, (select auth.uid()))
      on conflict (product_id, branch_id)
      do update set price = excluded.price, updated_by = excluded.updated_by, updated_at = now();
    end if;
  end loop;
end;
$$;

revoke execute on function public.set_product_branch_prices(uuid, jsonb) from public, anon;
grant execute on function public.set_product_branch_prices(uuid, jsonb) to authenticated;

-- The branch prices of one branch for a list of products (only products that have one), so
-- the POS can lay them over the catalogue.
create or replace function public.branch_prices(p_branch uuid, p_products uuid[])
returns table (product_id uuid, price numeric)
language sql
stable
set search_path = ''
as $$
  select bp.product_id, bp.price
  from public.product_branch_prices bp
  where bp.branch_id = p_branch and bp.product_id = any(coalesce(p_products, '{}'::uuid[]));
$$;

revoke execute on function public.branch_prices(uuid, uuid[]) from public;
grant execute on function public.branch_prices(uuid, uuid[]) to anon, authenticated;

notify pgrst, 'reload schema';
