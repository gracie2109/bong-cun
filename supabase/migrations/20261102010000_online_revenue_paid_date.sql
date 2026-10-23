-- Revenue is counted on the day the money is taken, not the day the invoice was made.
--
-- Online orders get an invoice when they are packed (unpaid) and it turns paid on delivery (cash on
-- delivery) or at the counter (pickup). Until now the reports used invoices.created_at, so the number of
-- a past day grew when the order was delivered later, and the cash collected today was not in today's
-- figure. POS invoices are paid when they are made, so for them nothing changes.
--
-- Also: an online order that came back from delivery is a "return", not a "cancellation", and the
-- overview reports the cash on delivery still to come (unpaid delivery invoices) next to revenue.

alter table public.invoices add column if not exists paid_at timestamptz;

-- paid_at: when the invoice became paid (its creation for a counter sale, the delivery or counter payment
-- for an online order). Reports count revenue on this date.

create or replace function public.invoice_set_paid_at() returns trigger
  language plpgsql
  set search_path to ''
as $$
begin
  if new.status = 'paid' and new.paid_at is null then
    new.paid_at := case when tg_op = 'INSERT' then new.created_at else now() end;
  end if;
  return new;
end;
$$;

revoke execute on function public.invoice_set_paid_at() from public, anon, authenticated;

create or replace trigger invoices_set_paid_at
  before insert or update of status on public.invoices
  for each row execute function public.invoice_set_paid_at();

-- Invoices that are already paid: the first payment is when the money came in (the invoice itself for a
-- counter sale). The updated_at trigger is paused so the history does not look edited today.
alter table public.invoices disable trigger set_updated_at;
update public.invoices i
set paid_at = coalesce((select min(p.created_at) from public.payments p where p.invoice_id = i.id), i.created_at)
where i.status = 'paid' and i.paid_at is null;
alter table public.invoices enable trigger set_updated_at;

create index if not exists invoices_branch_paid_idx on public.invoices (branch_id, paid_at) where status = 'paid';

CREATE OR REPLACE FUNCTION "public"."report_overview_core"("p_branches" "uuid"[], "p_range" "tstzrange") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with inv as (
    select id, status, subtotal, discount_amount, total, change_amount
    from public.invoices
    where branch_id = any(p_branches)
      and status = 'paid'
      and paid_at >= lower(p_range) and paid_at < upper(p_range)
  ), cancelled as (
    -- An online order that came back from delivery is a return, not a cancellation.
    select i.total
    from public.invoices i
    where i.branch_id = any(p_branches)
      and i.status = 'cancelled'
      and i.cancelled_at >= lower(p_range) and i.cancelled_at < upper(p_range)
      and not exists (select 1 from public.shop_orders so where so.invoice_id = i.id and so.status = 'returned')
  ), returned_online as (
    select i.total
    from public.invoices i
    where i.branch_id = any(p_branches)
      and i.status = 'cancelled'
      and i.cancelled_at >= lower(p_range) and i.cancelled_at < upper(p_range)
      and exists (select 1 from public.shop_orders so where so.invoice_id = i.id and so.status = 'returned')
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
      (select count(*) from returned_online)                as returned_online_count,
      coalesce((select sum(total) from returned_online), 0) as returned_online_amount,
      (select count(*) from ret)                            as return_count,
      coalesce((select sum(line_net) from lines where segment = 'shop'), 0) as shop,
      coalesce((select sum(line_net) from lines where segment = 'spa'), 0)  as spa,
      coalesce((select sum(line_net) from lines where segment = 'boarding'), 0) as boarding,
      coalesce((select sum(line_net) from lines where segment = 'medical'), 0) as medical,
      coalesce((select sum(line_net) from lines where segment = 'medical' and item_type = 'product'), 0) as medical_goods,
      coalesce((select sum(line_net) from lines
                where segment = 'spa' and appointment_item_id is not null), 0) as spa_appointment,
      coalesce((select amount from pay where method = 'cash'), 0)
        - coalesce((select sum(change_amount) from inv), 0) as cash,
      coalesce((select amount from pay where method = 'transfer'), 0) as transfer,
      coalesce((select amount from pay where method = 'card'), 0)     as card,
      coalesce((select amount from pay where method = 'cod'), 0)      as cod,
      coalesce((select sum(refund_amount) from ret where refund_method = 'cash'), 0)     as refund_cash,
      coalesce((select sum(refund_amount) from ret where refund_method = 'transfer'), 0) as refund_transfer,
      coalesce((select sum(cost_amount) from lines where segment = 'shop' or (segment = 'medical' and item_type = 'product')), 0) as cost_sold,
      (select cost from ret_cost)                                              as cost_returned,
      (select count(*) from lines where (segment = 'shop' or (segment = 'medical' and item_type = 'product')) and cost_amount is null) as missing_cost_lines
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
    'returned_online_count',  returned_online_count,
    'returned_online_amount', round(returned_online_amount),
    'return_count',  return_count,
    'segments', jsonb_build_object(
      'shop', round(shop),
      'spa', round(spa),
      'spa_appointment', round(spa_appointment),
      'spa_walk_in', round(spa - spa_appointment),
      'boarding', round(boarding),
      'medical', round(medical)
    ),
    'payments', jsonb_build_object(
      'cash', round(cash),
      'transfer', round(transfer),
      'card', round(card),
      'cod', round(cod),
      'refund_cash', round(refund_cash),
      'refund_transfer', round(refund_transfer)
    ),
    'gross_profit',  round((shop + medical_goods - refunds) - (cost_sold - cost_returned)),
    'missing_cost_lines', missing_cost_lines
  )
  from t;
$$;

CREATE OR REPLACE FUNCTION "public"."report_revenue_series"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_bucket" "text" DEFAULT 'day'::"text") RETURNS TABLE("bucket" "date", "invoice_count" integer, "gross" numeric, "discount" numeric, "net_sales" numeric, "refunds" numeric, "net_revenue" numeric, "shop" numeric, "spa" numeric, "boarding" numeric, "medical" numeric, "cash" numeric, "transfer" numeric, "card" numeric)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    select (i.paid_at at time zone 'Asia/Ho_Chi_Minh')::date as day,
           count(*) as n, sum(i.subtotal) as gross, sum(i.discount_amount) as discount,
           sum(i.total) as net_sales, sum(i.change_amount) as change
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.paid_at >= lower(v_range) and i.paid_at < upper(v_range)
    group by 1
  ), pay as (
    select (i.paid_at at time zone 'Asia/Ho_Chi_Minh')::date as day,
           sum(p.amount) filter (where p.method = 'cash') as cash,
           sum(p.amount) filter (where p.method = 'transfer') as transfer,
           sum(p.amount) filter (where p.method = 'card') as card
    from public.invoices i
    join public.payments p on p.invoice_id = i.id
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.paid_at >= lower(v_range) and i.paid_at < upper(v_range)
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
           sum(s.line_net) filter (where s.segment = 'spa') as spa,
           sum(s.line_net) filter (where s.segment = 'boarding') as boarding,
           sum(s.line_net) filter (where s.segment = 'medical') as medical
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
    coalesce(round(sum(seg.boarding)), 0),
    coalesce(round(sum(seg.medical)), 0),
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

CREATE OR REPLACE FUNCTION "public"."report_sales_lines"("p_branches" "uuid"[], "p_from" timestamp with time zone, "p_to" timestamp with time zone) RETURNS TABLE("invoice_id" "uuid", "branch_id" "uuid", "biz_date" "date", "cashier_id" "uuid", "cashier_name" "text", "line_id" "uuid", "item_type" "text", "product_id" "uuid", "service_id" "uuid", "combo_id" "uuid", "name" "text", "qty" numeric, "amount" numeric, "line_net" numeric, "cost_amount" numeric, "segment" "text", "appointment_item_id" "uuid", "staff_id" "uuid", "pet_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select
    i.id,
    i.branch_id,
    (i.paid_at at time zone 'Asia/Ho_Chi_Minh')::date,
    i.created_by,
    i.cashier_name,
    l.id,
    l.item_type,
    l.product_id,
    l.service_id,
    l.combo_id,
    case when l.item_type = 'boarding' then 'boarding' else l.name end,
    l.base_qty,
    l.amount,
    case when i.subtotal = 0 then 0 else l.amount * i.total / i.subtotal end,
    l.cost_amount,
    case
      when l.item_type = 'boarding' then 'boarding'
      when mi.id is not null then 'medical'
      when l.item_type = 'product' then 'shop'
      else 'spa'
    end,
    ai.id,
    ai.staff_id,
    coalesce(l.pet_id, ai.pet_id)
  from public.invoices i
  join public.invoice_lines l on l.invoice_id = i.id
  left join public.appointment_items ai on ai.invoice_line_id = l.id
  left join public.medical_visit_items mi on mi.invoice_line_id = l.id
  where i.status = 'paid'
    and i.branch_id = any(p_branches)
    and i.paid_at >= p_from
    and i.paid_at < p_to;
$$;

CREATE OR REPLACE FUNCTION "public"."report_staff_revenue"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_role" "text" DEFAULT 'cashier'::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("staff_id" "uuid", "name" "text", "invoice_count" bigint, "ticket_count" bigint, "pet_count" bigint, "net_sales" numeric, "refunds" numeric, "cancelled_count" bigint, "avg_ticket" numeric, "share" numeric, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
      and i.paid_at >= lower(v_range) and i.paid_at < upper(v_range)
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

CREATE OR REPLACE FUNCTION "public"."report_overview"("p_branch" "uuid", "p_from" "date", "p_to" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    -- Delivery orders packed but not yet paid: cash on delivery still to come, not revenue yet.
    'pending_cod', (
      select jsonb_build_object('count', count(*), 'amount', coalesce(round(sum(i.total)), 0))
      from public.invoices i
      join public.shop_orders so on so.invoice_id = i.id
      where i.branch_id = any(v_branches) and i.status = 'unpaid' and so.delivery_method = 'delivery'
    ),
    'previous', jsonb_build_object(
      'net_revenue',   v_prev -> 'net_revenue',
      'invoice_count', v_prev -> 'invoice_count',
      'avg_ticket',    v_prev -> 'avg_ticket',
      'refunds',       v_prev -> 'refunds'
    )
  );
end;
$$;
