-- Revenue reports, step 3: returns and cancellations, and the cash shift reconciliation
-- (docs: bao-cao-doanh-thu.md, sections 5.3 and 6.5 to 6.6). Safe to run more than once.
-- Runs after 20261014010300_reports_rankings.sql.

-- Every goods return and every cancelled invoice in the range, newest first. A return is
-- dated by when it was made, a cancellation by when the invoice was cancelled.
create or replace function public.report_adjustments(
  p_branch uuid,
  p_from   date,
  p_to     date,
  p_kind   text default 'all',
  p_search text default null,
  p_limit  int default 20,
  p_offset int default 0
) returns table (
  kind          text,
  id            uuid,
  branch_id     uuid,
  code          text,
  invoice_id    uuid,
  invoice_code  text,
  at            timestamptz,
  amount        numeric,
  method        text,
  reason        text,
  by_name       text,
  item_summary  text,
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
  if coalesce(p_kind, 'all') not in ('all', 'return', 'cancel') then
    raise exception 'kind must be all, return or cancel' using errcode = '22023';
  end if;

  return query
  with returns_ as (
    select 'return'::text as kind,
           r.id,
           r.branch_id,
           r.code,
           r.invoice_id,
           i.code as invoice_code,
           r.created_at as at,
           r.refund_amount as amount,
           r.refund_method as method,
           r.reason,
           r.created_by_name as by_name,
           (select string_agg(x.name || ' x' || trim_scale(x.qty)::text, ', ' order by x.name)
            from (select l.name, l.qty from public.sales_return_lines l
                  where l.return_id = r.id order by l.name limit 3) x) as item_summary
    from public.sales_returns r
    join public.invoices i on i.id = r.invoice_id
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
  ), cancels as (
    select 'cancel'::text,
           i.id,
           i.branch_id,
           i.code,
           i.id,
           i.code,
           i.cancelled_at,
           i.total,
           null::text,
           i.cancel_reason,
           public.staff_display_name(i.cancelled_by),
           (select string_agg(x.name || ' x' || trim_scale(x.qty)::text, ', ' order by x.name)
            from (select l.name, l.qty from public.invoice_lines l
                  where l.invoice_id = i.id order by l.line_no limit 3) x)
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'cancelled'
      and i.cancelled_at >= lower(v_range) and i.cancelled_at < upper(v_range)
  ), merged as (
    select * from returns_ where coalesce(p_kind, 'all') in ('all', 'return')
    union all
    select * from cancels where coalesce(p_kind, 'all') in ('all', 'cancel')
  )
  select m.kind, m.id, m.branch_id, m.code, m.invoice_id, m.invoice_code, m.at, m.amount, m.method,
         m.reason, m.by_name, m.item_summary, count(*) over ()
  from merged m
  where v_term is null
     or m.code ilike '%' || v_term || '%'
     or m.invoice_code ilike '%' || v_term || '%'
     or m.reason ilike '%' || v_term || '%'
  order by m.at desc
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke execute on function public.report_adjustments(uuid, date, date, text, text, int, int) from public, anon;
grant execute on function public.report_adjustments(uuid, date, date, text, text, int, int) to authenticated;

-- Cash shifts opened in the range with what the system expected in the drawer against what
-- was counted. A closed shift keeps the figures fixed at closing; an open one is computed now
-- with the same formula as cash_shift_summary (which needs the pos permission, so it is not
-- called here).
create or replace function public.report_shifts(
  p_branch uuid,
  p_from   date,
  p_to     date,
  p_status text default 'all',
  p_search text default null,
  p_limit  int default 20,
  p_offset int default 0
) returns table (
  id             uuid,
  code           text,
  branch_code    text,
  status         text,
  opened_by_name text,
  opened_at      timestamptz,
  closed_by_name text,
  closed_at      timestamptz,
  opening_cash   numeric,
  invoice_count  bigint,
  sales_total    numeric,
  cash_in        numeric,
  transfer_in    numeric,
  card_in        numeric,
  refund_cash    numeric,
  expected_cash  numeric,
  counted_cash   numeric,
  difference     numeric,
  total_count    bigint
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
  if coalesce(p_status, 'all') not in ('all', 'open', 'closed', 'mismatch') then
    raise exception 'status must be all, open, closed or mismatch' using errcode = '22023';
  end if;

  return query
  with sh as (
    select s.*, b.code as bcode
    from public.cash_shifts s
    join public.branches b on b.id = s.branch_id
    where s.branch_id = any(v_branches)
      and s.opened_at >= lower(v_range) and s.opened_at < upper(v_range)
  ), inv as (
    select i.shift_id,
           count(*) as n,
           sum(i.total) as total,
           sum(i.change_amount) as change
    from public.invoices i
    join sh on sh.id = i.shift_id
    where i.status = 'paid'
    group by 1
  ), pay as (
    select i.shift_id,
           sum(p.amount) filter (where p.method = 'cash') as cash,
           sum(p.amount) filter (where p.method = 'transfer') as transfer,
           sum(p.amount) filter (where p.method = 'card') as card
    from public.invoices i
    join sh on sh.id = i.shift_id
    join public.payments p on p.invoice_id = i.id
    where i.status = 'paid'
    group by 1
  ), ret as (
    select r.shift_id, sum(r.refund_amount) as cash
    from public.sales_returns r
    join sh on sh.id = r.shift_id
    where r.refund_method = 'cash'
    group by 1
  ), calc as (
    select sh.id,
           sh.code,
           sh.bcode,
           sh.status,
           sh.opened_by_name,
           sh.opened_at,
           sh.closed_by_name,
           sh.closed_at,
           sh.opening_cash,
           coalesce(inv.n, 0) as n,
           coalesce(inv.total, 0) as sales,
           coalesce(pay.cash, 0) as cash,
           coalesce(pay.transfer, 0) as transfer,
           coalesce(pay.card, 0) as card,
           coalesce(ret.cash, 0) as refund_cash,
           case when sh.status = 'closed' then sh.expected_cash
                else sh.opening_cash + coalesce(pay.cash, 0) - coalesce(inv.change, 0) - coalesce(ret.cash, 0)
           end as expected,
           sh.counted_cash as counted
    from sh
    left join inv on inv.shift_id = sh.id
    left join pay on pay.shift_id = sh.id
    left join ret on ret.shift_id = sh.id
  )
  select c.id, c.code, c.bcode, c.status, c.opened_by_name, c.opened_at, c.closed_by_name, c.closed_at,
         c.opening_cash, c.n, c.sales, c.cash, c.transfer, c.card, c.refund_cash, c.expected, c.counted,
         case when c.status = 'closed' then c.counted - c.expected end,
         count(*) over ()
  from calc c
  where case coalesce(p_status, 'all')
          when 'open' then c.status = 'open'
          when 'closed' then c.status = 'closed'
          when 'mismatch' then c.status = 'closed' and c.counted is distinct from c.expected
          else true
        end
    and (v_term is null
         or c.code ilike '%' || v_term || '%'
         or c.opened_by_name ilike '%' || v_term || '%')
  order by c.opened_at desc
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

revoke execute on function public.report_shifts(uuid, date, date, text, text, int, int) from public, anon;
grant execute on function public.report_shifts(uuid, date, date, text, text, int, int) to authenticated;

notify pgrst, 'reload schema';
