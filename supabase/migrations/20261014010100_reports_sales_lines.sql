-- Revenue reports, step 1 (2/3): the single source for every per-line figure
-- (docs: bao-cao-doanh-thu.md, sections 3.3, 3.4 and 5.2). Safe to run more than once.
--
-- One row per invoice line of a paid invoice in the range. line_net spreads the invoice
-- discount over the lines by their share of the subtotal, so segment, item and staff
-- reports all agree. Internal: called by the report RPCs, never by the client.

create or replace function public.report_sales_lines(
  p_branches uuid[],
  p_from     timestamptz,
  p_to       timestamptz
) returns table (
  invoice_id          uuid,
  branch_id           uuid,
  biz_date            date,
  cashier_id          uuid,
  cashier_name        text,
  line_id             uuid,
  item_type           text,
  product_id          uuid,
  service_id          uuid,
  combo_id            uuid,
  name                text,
  qty                 numeric,
  amount              numeric,
  line_net            numeric,
  cost_amount         numeric,
  segment             text,
  appointment_item_id uuid,
  staff_id            uuid,
  pet_id              uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    i.id,
    i.branch_id,
    (i.created_at at time zone 'Asia/Ho_Chi_Minh')::date,
    i.created_by,
    i.cashier_name,
    l.id,
    l.item_type,
    l.product_id,
    l.service_id,
    l.combo_id,
    l.name,
    l.qty,
    l.amount,
    case when i.subtotal = 0 then 0 else l.amount * i.total / i.subtotal end,
    l.cost_amount,
    case when l.item_type = 'product' then 'shop' else 'spa' end,
    ai.id,
    ai.staff_id,
    coalesce(l.pet_id, ai.pet_id)
  from public.invoices i
  join public.invoice_lines l on l.invoice_id = i.id
  left join public.appointment_items ai on ai.invoice_line_id = l.id
  where i.status = 'paid'
    and i.branch_id = any(p_branches)
    and i.created_at >= p_from
    and i.created_at < p_to;
$$;

revoke execute on function public.report_sales_lines(uuid[], timestamptz, timestamptz)
  from public, anon, authenticated;

notify pgrst, 'reload schema';
