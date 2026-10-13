-- Revenue reports, step 1 (3/3): the overview numbers and the revenue-by-day series
-- (docs: bao-cao-doanh-thu.md, sections 3.2 to 3.6 and 5.3). Safe to run more than once.
-- Runs after 20261014010000_reports_access.sql and 20261014010100_reports_sales_lines.sql.

-- Every overview figure of one range (internal; report_overview calls it for the range and
-- for the range before it).
create or replace function public.report_overview_core(p_branches uuid[], p_range tstzrange)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with inv as (
    select id, status, subtotal, discount_amount, total, change_amount
    from public.invoices
    where branch_id = any(p_branches)
      and status = 'paid'
      and created_at >= lower(p_range) and created_at < upper(p_range)
  ), cancelled as (
    select total
    from public.invoices
    where branch_id = any(p_branches)
      and status = 'cancelled'
      and cancelled_at >= lower(p_range) and cancelled_at < upper(p_range)
  ), pay as (
    select p.method, sum(p.amount) as amount
    from public.payments p
    join inv on inv.id = p.invoice_id
    group by p.method
  ), ret as (
    select id, refund_amount, refund_method
    from public.sales_returns
    where branch_id = any(p_branches)
      and created_at >= lower(p_range) and created_at < upper(p_range)
  ), ret_cost as (
    select coalesce(sum(m.qty * m.unit_cost), 0) as cost
    from public.stock_movements m
    join ret on ret.id = m.return_id
    where m.reason = 'return'
  ), lines as (
    select * from public.report_sales_lines(p_branches, lower(p_range), upper(p_range))
  ), t as (
    select
      coalesce((select sum(subtotal) from inv), 0)          as gross,
      coalesce((select sum(discount_amount) from inv), 0)   as discount,
      coalesce((select sum(total) from inv), 0)             as net_sales,
      coalesce((select sum(refund_amount) from ret), 0)     as refunds,
      (select count(*) from inv)                            as invoice_count,
      (select count(*) from cancelled)                      as cancelled_count,
      coalesce((select sum(total) from cancelled), 0)       as cancelled_amount,
      (select count(*) from ret)                            as return_count,
      coalesce((select sum(line_net) from lines where segment = 'shop'), 0) as shop,
      coalesce((select sum(line_net) from lines where segment = 'spa'), 0)  as spa,
      coalesce((select sum(line_net) from lines
                where segment = 'spa' and appointment_item_id is not null), 0) as spa_appointment,
      coalesce((select amount from pay where method = 'cash'), 0)
        - coalesce((select sum(change_amount) from inv), 0) as cash,
      coalesce((select amount from pay where method = 'transfer'), 0) as transfer,
      coalesce((select amount from pay where method = 'card'), 0)     as card,
      coalesce((select sum(refund_amount) from ret where refund_method = 'cash'), 0)     as refund_cash,
      coalesce((select sum(refund_amount) from ret where refund_method = 'transfer'), 0) as refund_transfer,
      coalesce((select sum(cost_amount) from lines where segment = 'shop'), 0) as cost_sold,
      (select cost from ret_cost)                                              as cost_returned,
      (select count(*) from lines where segment = 'shop' and cost_amount is null) as missing_cost_lines
  )
  select jsonb_build_object(
    'gross',         round(gross),
    'discount',      round(discount),
    'net_sales',     round(net_sales),
    'refunds',       round(refunds),
    'net_revenue',   round(net_sales - refunds),
    'invoice_count', invoice_count,
    'avg_ticket',    case when invoice_count = 0 then 0 else round(net_sales / invoice_count) end,
    'cancelled_count',  cancelled_count,
    'cancelled_amount', round(cancelled_amount),
    'return_count',  return_count,
    'segments', jsonb_build_object(
      'shop', round(shop),
      'spa', round(spa),
      'spa_appointment', round(spa_appointment),
      'spa_walk_in', round(spa - spa_appointment)
    ),
    'payments', jsonb_build_object(
      'cash', round(cash),
      'transfer', round(transfer),
      'card', round(card),
      'refund_cash', round(refund_cash),
      'refund_transfer', round(refund_transfer)
    ),
    'gross_profit',  round((shop - refunds) - (cost_sold - cost_returned)),
    'missing_cost_lines', missing_cost_lines
  )
  from t;
$$;

revoke execute on function public.report_overview_core(uuid[], tstzrange)
  from public, anon, authenticated;

-- KPI cards, the mix and the comparison with the period right before.
create or replace function public.report_overview(p_branch uuid, p_from date, p_to date)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
  v_days     int := p_to - p_from + 1;
  v_now      jsonb;
  v_prev     jsonb;
begin
  v_now  := public.report_overview_core(v_branches, v_range);
  v_prev := public.report_overview_core(v_branches, public.report_range(p_from - v_days, p_from - 1));

  return v_now || jsonb_build_object(
    'previous', jsonb_build_object(
      'net_revenue',   v_prev -> 'net_revenue',
      'invoice_count', v_prev -> 'invoice_count',
      'avg_ticket',    v_prev -> 'avg_ticket',
      'refunds',       v_prev -> 'refunds'
    )
  );
end;
$$;

revoke execute on function public.report_overview(uuid, date, date) from public, anon;
grant execute on function public.report_overview(uuid, date, date) to authenticated;

-- Revenue per day, week (Monday first) or month, every bucket of the range included.
-- At most 366 rows, so no paging (a bounded time series, not a list).
create or replace function public.report_revenue_series(
  p_branch uuid,
  p_from   date,
  p_to     date,
  p_bucket text default 'day'
) returns table (
  bucket        date,
  invoice_count int,
  gross         numeric,
  discount      numeric,
  net_sales     numeric,
  refunds       numeric,
  net_revenue   numeric,
  shop          numeric,
  spa           numeric,
  cash          numeric,
  transfer      numeric,
  card          numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
begin
  if coalesce(p_bucket, 'day') not in ('day', 'week', 'month') then
    raise exception 'bucket must be day, week or month' using errcode = '22023';
  end if;

  return query
  with days as (
    select d::date as day,
           case coalesce(p_bucket, 'day')
             when 'week'  then date_trunc('week', d)::date
             when 'month' then date_trunc('month', d)::date
             else d::date
           end as bkt
    from generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') d
  ), inv as (
    select (i.created_at at time zone 'Asia/Ho_Chi_Minh')::date as day,
           count(*) as n, sum(i.subtotal) as gross, sum(i.discount_amount) as discount,
           sum(i.total) as net_sales, sum(i.change_amount) as change
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.created_at >= lower(v_range) and i.created_at < upper(v_range)
    group by 1
  ), pay as (
    select (i.created_at at time zone 'Asia/Ho_Chi_Minh')::date as day,
           sum(p.amount) filter (where p.method = 'cash') as cash,
           sum(p.amount) filter (where p.method = 'transfer') as transfer,
           sum(p.amount) filter (where p.method = 'card') as card
    from public.invoices i
    join public.payments p on p.invoice_id = i.id
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.created_at >= lower(v_range) and i.created_at < upper(v_range)
    group by 1
  ), ret as (
    select (r.created_at at time zone 'Asia/Ho_Chi_Minh')::date as day, sum(r.refund_amount) as refunds
    from public.sales_returns r
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), seg as (
    select s.biz_date as day,
           sum(s.line_net) filter (where s.segment = 'shop') as shop,
           sum(s.line_net) filter (where s.segment = 'spa') as spa
    from public.report_sales_lines(v_branches, lower(v_range), upper(v_range)) s
    group by 1
  )
  select
    d.bkt,
    coalesce(sum(inv.n), 0)::int,
    coalesce(round(sum(inv.gross)), 0),
    coalesce(round(sum(inv.discount)), 0),
    coalesce(round(sum(inv.net_sales)), 0),
    coalesce(round(sum(ret.refunds)), 0),
    coalesce(round(sum(inv.net_sales)), 0) - coalesce(round(sum(ret.refunds)), 0),
    coalesce(round(sum(seg.shop)), 0),
    coalesce(round(sum(seg.spa)), 0),
    coalesce(round(sum(pay.cash)), 0) - coalesce(round(sum(inv.change)), 0),
    coalesce(round(sum(pay.transfer)), 0),
    coalesce(round(sum(pay.card)), 0)
  from days d
  left join inv on inv.day = d.day
  left join pay on pay.day = d.day
  left join ret on ret.day = d.day
  left join seg on seg.day = d.day
  group by d.bkt
  order by d.bkt;
end;
$$;

revoke execute on function public.report_revenue_series(uuid, date, date, text) from public, anon;
grant execute on function public.report_revenue_series(uuid, date, date, text) to authenticated;

notify pgrst, 'reload schema';
