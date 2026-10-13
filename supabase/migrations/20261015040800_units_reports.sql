-- Product module, step 4 (9/9): report quantities in base units (docs/module-san-pham.md, 3.4).
-- report_sales_lines of 20261014010100 with qty = base_qty, so "2 hộp" and "5 viên" add up
-- (services and combos have factor 1). Safe to run more than once.
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
    l.base_qty,
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


-- Items ranked by revenue, quantity or gross profit (quantities in base units, see 20261015040800). Products and services/combos in one list;
-- net_revenue spreads the invoice discount over lines, refunds are the money handed back for
-- returned goods in the range (returns count on the day they were made).
create or replace function public.report_top_items(
  p_branch uuid,
  p_from   date,
  p_to     date,
  p_kind   text default 'all',
  p_search text default null,
  p_sort   text default 'revenue',
  p_limit  int default 20,
  p_offset int default 0
) returns table (
  item_type     text,
  item_id       uuid,
  name          text,
  sku           text,
  unit          text,
  qty_sold      numeric,
  qty_returned  numeric,
  invoice_count bigint,
  net_revenue   numeric,
  refunds       numeric,
  cost          numeric,
  gross_profit  numeric,
  share         numeric,
  total_count   bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
  v_term     text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if coalesce(p_kind, 'all') not in ('all', 'product', 'service') then
    raise exception 'kind must be all, product or service' using errcode = '22023';
  end if;
  if coalesce(p_sort, 'revenue') not in ('revenue', 'qty', 'profit') then
    raise exception 'sort must be revenue, qty or profit' using errcode = '22023';
  end if;

  return query
  with lines as (
    select * from public.report_sales_lines(v_branches, lower(v_range), upper(v_range))
  ), sold as (
    select l.item_type as kind,
           coalesce(l.product_id, l.service_id, l.combo_id) as id,
           sum(l.qty) as qty,
           count(distinct l.invoice_id) as invoices,
           sum(l.line_net) as net,
           sum(l.cost_amount) as cost,
           max(l.name) as line_name
    from lines l
    group by 1, 2
  ), grand as (
    select coalesce(sum(line_net), 0) as total from lines
  ), ret as (
    select rl.product_id as id,
           sum(rl.qty * il.unit_factor) as qty,
           sum(rl.amount) as amount
    from public.sales_returns r
    join public.sales_return_lines rl on rl.return_id = r.id
    join public.invoice_lines il on il.id = rl.invoice_line_id
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), ret_cost as (
    select m.product_id as id, sum(m.qty * m.unit_cost) as cost
    from public.sales_returns r
    join public.stock_movements m on m.return_id = r.id and m.reason = 'return'
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), merged as (
    select coalesce(s.kind, 'product') as kind,
           coalesce(s.id, r.id) as id,
           coalesce(s.qty, 0) as qty_sold,
           coalesce(r.qty, 0) as qty_returned,
           coalesce(s.invoices, 0) as invoices,
           coalesce(s.net, 0) as net,
           coalesce(r.amount, 0) as refunds,
           s.cost as cost_sold,
           s.line_name,
           coalesce(rc.cost, 0) as cost_returned
    from sold s
    full join ret r on s.kind = 'product' and r.id = s.id
    left join ret_cost rc on rc.id = coalesce(s.id, r.id) and coalesce(s.kind, 'product') = 'product'
  ), named as (
    select m.kind,
           m.id,
           coalesce(p.name, sv.name, cb.name, m.line_name, '') as name,
           p.sku,
           p.barcode,
           coalesce(p.unit, sv.unit) as unit,
           m.qty_sold, m.qty_returned, m.invoices, m.net, m.refunds,
           case when m.kind = 'product' then coalesce(m.cost_sold, 0) - m.cost_returned end as cost,
           case when m.kind = 'product'
                then (m.net - m.refunds) - (coalesce(m.cost_sold, 0) - m.cost_returned)
           end as profit
    from merged m
    left join public.products p on m.kind = 'product' and p.id = m.id
    left join public.pet_services sv on m.kind = 'service' and sv.id = m.id
    left join public.pet_service_combos cb on m.kind = 'combo' and cb.id = m.id
  )
  select n.kind,
         n.id,
         n.name,
         n.sku,
         n.unit,
         n.qty_sold,
         n.qty_returned,
         n.invoices,
         round(n.net),
         round(n.refunds),
         round(n.cost),
         round(n.profit),
         case when g.total = 0 then 0 else round(n.net / g.total * 100, 1) end,
         count(*) over ()
  from named n
  cross join grand g
  where case coalesce(p_kind, 'all')
          when 'product' then n.kind = 'product'
          when 'service' then n.kind in ('service', 'combo')
          else true
        end
    and (v_term is null
         or n.name ilike '%' || v_term || '%'
         or n.sku ilike '%' || v_term || '%'
         or n.barcode = v_term)
  order by
    case coalesce(p_sort, 'revenue') when 'qty' then n.qty_sold when 'profit' then n.profit else n.net end desc nulls last,
    n.name
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke execute on function public.report_top_items(uuid, date, date, text, text, text, int, int) from public, anon;
grant execute on function public.report_top_items(uuid, date, date, text, text, text, int, int) to authenticated;

notify pgrst, 'reload schema';
