-- Shop checkout, step 7 (2/2): the revenue overview splits out cash collected by couriers.
-- Safe to run more than once.
--
-- A copy of report_overview_core of 20261014010200_reports_overview.sql with one more figure,
-- payments.cod: the 'cod' payments of paid invoices in the range. Courier cash is not in the
-- till, so it stays out of "cash"; it lets the owner tick the COD column off against the GHN
-- statement (GHN pays out 1 to 3 days after delivery).

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
      coalesce((select amount from pay where method = 'cod'), 0)      as cod,
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
      'cod', round(cod),
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

notify pgrst, 'reload schema';
