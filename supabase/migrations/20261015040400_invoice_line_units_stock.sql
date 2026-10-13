-- Product module, step 4 (5/9): a sale takes stock in base units (docs/module-san-pham.md, 3.4).
-- The trigger function of 20261007130000_inventory_lots.sql with new.base_qty (qty x unit_factor)
-- in place of new.qty. Lines sold before this step have factor 1, so they behave as before.
-- Safe to run more than once.

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
  v_cost := public.take_stock_fefo(v_branch, new.product_id, new.base_qty, new.invoice_id, new.id);
  if v_cost is not null then
    update public.invoice_lines set cost_amount = v_cost where id = new.id;
  end if;
  return null;
end;
$$;

revoke execute on function public.invoice_line_take_stock() from public, anon, authenticated;

notify pgrst, 'reload schema';
