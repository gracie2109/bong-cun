-- Medical records, step 5 (1/2): services and medicine of a signed visit can be paid in the POS
-- (docs/ho-so-benh-an.md, section 7). Safe to run more than once.
--
-- Before: the lines of a visit are only a list; nothing turns them into an invoice.
-- After: the POS lists the signed visits of the customer that still have unpaid lines
-- (billable_medical_items); the invoice line keeps the batch (lot) the vet picked, and stock is
-- taken from that batch first, then earliest expiry first. Lines without a batch behave as before.
-- 20261021050100_medical_invoice_rpcs.sql follows.

-- ------------------------------------------------------------ invoice lines
alter table public.invoice_lines
  add column if not exists lot_id uuid references public.stock_lots(id) on delete set null;

-- --------------------------------------------------------- stock, lot first
-- Takes p_qty from the given lot first (when it is of this branch and product), then the rest
-- earliest expiry first. Returns the cost taken, or null for a product without stock.
create or replace function public.take_stock_lot_first(
  p_branch       uuid,
  p_product      uuid,
  p_qty          numeric,
  p_lot          uuid,
  p_invoice      uuid,
  p_invoice_line uuid
) returns numeric
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lot   public.stock_lots;
  v_take  numeric := 0;
  v_cost  numeric := 0;
  v_rest  numeric;
  v_more  numeric;
begin
  if p_lot is null then
    return public.take_stock_fefo(p_branch, p_product, p_qty, p_invoice, p_invoice_line);
  end if;
  if not coalesce((select track_stock from public.products where id = p_product), false) then
    return null;
  end if;

  select * into v_lot from public.stock_lots
  where id = p_lot and branch_id = p_branch and product_id = p_product
  for update;
  if found and v_lot.qty_on_hand > 0 then
    v_take := least(p_qty, v_lot.qty_on_hand);
    perform public.move_stock(v_lot.id, -v_take, 'sale', p_invoice => p_invoice, p_invoice_line => p_invoice_line);
    v_cost := v_take * v_lot.unit_cost;
  end if;

  v_rest := p_qty - v_take;
  if v_rest > 0 then
    v_more := public.take_stock_fefo(p_branch, p_product, v_rest, p_invoice, p_invoice_line);
    v_cost := v_cost + coalesce(v_more, 0);
  end if;
  return round(v_cost, 2);
end;
$$;

revoke execute on function public.take_stock_lot_first(uuid, uuid, numeric, uuid, uuid, uuid)
  from public, anon, authenticated;

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
  v_cost := public.take_stock_lot_first(v_branch, new.product_id, new.base_qty, new.lot_id, new.invoice_id, new.id);
  if v_cost is not null then
    update public.invoice_lines set cost_amount = v_cost where id = new.id;
  end if;
  return null;
end;
$$;

revoke execute on function public.invoice_line_take_stock() from public, anon, authenticated;

-- ----------------------------------------------------------------- billable
-- The signed visits of a customer with lines that are not on an invoice yet, for the POS cart:
-- [{ visit_id, code, pet_name, total, items: [{ id, kind, name, qty, unit_name, unit_price, amount }] }].
create or replace function public.billable_medical_items(p_branch uuid, p_customer uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'visit_id', v.id,
      'code', v.code,
      'pet_name', v.pet_name,
      'total', c.total,
      'items', c.items
    ) order by v.signed_at, v.code)
    from public.medical_visits v
    cross join lateral (
      select sum(i.amount) as total,
             jsonb_agg(jsonb_build_object(
               'id', i.id,
               'kind', i.kind,
               'name', i.name,
               'qty', i.qty,
               'unit_name', i.unit_name,
               'unit_price', i.unit_price,
               'amount', i.amount
             ) order by i.created_at, i.id) as items
      from public.medical_visit_items i
      where i.visit_id = v.id and i.kind in ('service', 'product') and i.invoice_line_id is null
    ) c
    where v.branch_id = p_branch
      and v.customer_id = p_customer
      and v.status = 'done'
      and v.signed_at is not null
      and c.items is not null
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.billable_medical_items(uuid, uuid) from public, anon;
grant execute on function public.billable_medical_items(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
