-- Revenue reports, step 2: top items and revenue per staff member
-- (docs: bao-cao-doanh-thu.md, sections 3.3 to 3.7 and 5.3). Safe to run more than once.
-- Runs after 20261014010200_reports_overview.sql.

-- Items ranked by revenue, quantity or gross profit. Products and services/combos in one list;
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
           sum(rl.qty) as qty,
           sum(rl.amount) as amount
    from public.sales_returns r
    join public.sales_return_lines rl on rl.return_id = r.id
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

-- Revenue per cashier (who rang the sale) or per spa staff member (who did the ticket).
-- Cashier columns: invoice_count, net_sales, refunds, cancelled_count, avg_ticket.
-- Spa columns: ticket_count, pet_count, net_sales, share (percent of all spa revenue). A null staff_id is "not assigned".
create or replace function public.report_staff_revenue(
  p_branch uuid,
  p_from   date,
  p_to     date,
  p_role   text default 'cashier',
  p_search text default null,
  p_limit  int default 20,
  p_offset int default 0
) returns table (
  staff_id        uuid,
  name            text,
  invoice_count   bigint,
  ticket_count    bigint,
  pet_count       bigint,
  net_sales       numeric,
  refunds         numeric,
  cancelled_count bigint,
  avg_ticket      numeric,
  share           numeric,
  total_count     bigint
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
  if coalesce(p_role, 'cashier') not in ('cashier', 'spa') then
    raise exception 'role must be cashier or spa' using errcode = '22023';
  end if;

  if coalesce(p_role, 'cashier') = 'spa' then
    return query
    with lines as (
      select * from public.report_sales_lines(v_branches, lower(v_range), upper(v_range))
      where segment = 'spa'
    ), grouped as (
      select l.staff_id as sid,
             count(*) as tickets,
             count(distinct l.pet_id) as pets,
             sum(l.line_net) as net,
             sum(sum(l.line_net)) over () as everyone
      from lines l
      group by 1
    )
    select g.sid,
           public.staff_display_name(g.sid),
           null::bigint,
           g.tickets,
           g.pets,
           round(g.net),
           null::numeric,
           null::bigint,
           null::numeric,
           case when g.everyone = 0 then 0 else round(g.net / g.everyone * 100, 1) end,
           count(*) over ()
    from grouped g
    where v_term is null or public.staff_display_name(g.sid) ilike '%' || v_term || '%'
    order by g.net desc, 2
    limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
    return;
  end if;

  return query
  with sales as (
    select i.created_by as sid, max(i.cashier_name) as cname, count(*) as n, sum(i.total) as net
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.created_at >= lower(v_range) and i.created_at < upper(v_range)
    group by 1
  ), ret as (
    select r.created_by as sid, max(r.created_by_name) as cname, sum(r.refund_amount) as amount
    from public.sales_returns r
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), cancelled as (
    select i.created_by as sid, max(i.cashier_name) as cname, count(*) as n
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'cancelled'
      and i.cancelled_at >= lower(v_range) and i.cancelled_at < upper(v_range)
    group by 1
  ), people as (
    select sid from sales union select sid from ret union select sid from cancelled
  ), rows_ as (
    select p.sid,
           coalesce(public.staff_display_name(p.sid), s.cname, r.cname, c.cname) as nm,
           coalesce(s.n, 0) as n,
           coalesce(s.net, 0) as net,
           coalesce(r.amount, 0) as refunds,
           coalesce(c.n, 0) as cancelled
    from people p
    left join sales s on s.sid = p.sid
    left join ret r on r.sid = p.sid
    left join cancelled c on c.sid = p.sid
  )
  select x.sid,
         x.nm,
         x.n,
         null::bigint,
         null::bigint,
         round(x.net),
         round(x.refunds),
         x.cancelled,
         case when x.n = 0 then 0 else round(x.net / x.n) end,
         null::numeric,
         count(*) over ()
  from rows_ x
  where v_term is null or x.nm ilike '%' || v_term || '%'
  order by x.net desc, x.nm
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke execute on function public.report_staff_revenue(uuid, date, date, text, text, int, int) from public, anon;
grant execute on function public.report_staff_revenue(uuid, date, date, text, text, int, int) to authenticated;

notify pgrst, 'reload schema';
