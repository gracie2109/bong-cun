-- Online orders nobody confirmed hold stock for ever (pending and confirmed orders count against
-- sellable stock). This cancels the ones left pending for too long and runs it every night.
-- Safe to run more than once. See docs/ke-hoach-viec-con-lai-kien-truc.md (4.6).
--
-- Only 'pending' orders without an invoice are touched: once staff confirm an order it stays theirs.

create or replace function public.auto_cancel_stale_shop_orders(p_days integer default 7)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reason text := format('Tự hủy: quá %s ngày chưa được xác nhận', p_days);
  v_count  integer;
begin
  if p_days is null or p_days < 1 then
    raise exception 'p_days must be at least 1' using errcode = '22023', hint = 'bad_days';
  end if;

  with stale as (
    update public.shop_orders
    set status = 'cancelled', cancelled_at = now(), cancel_reason = v_reason
    where status = 'pending'
      and invoice_id is null
      and placed_at < now() - make_interval(days => p_days)
    returning id
  ), logged as (
    insert into public.shop_order_events (order_id, status, note, actor_name)
    select id, 'cancelled', v_reason, 'Hệ thống' from stale
    returning 1
  )
  select count(*) into v_count from logged;

  return v_count;
end;
$$;

revoke all on function public.auto_cancel_stale_shop_orders(integer) from public, anon, authenticated;
grant execute on function public.auto_cancel_stale_shop_orders(integer) to service_role;

-- Every night at 02:00 Vietnam time (19:00 UTC).
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('auto-cancel-stale-shop-orders')
  where exists (select 1 from cron.job where jobname = 'auto-cancel-stale-shop-orders');
  perform cron.schedule(
    'auto-cancel-stale-shop-orders',
    '0 19 * * *',
    'select public.auto_cancel_stale_shop_orders(7)'
  );
end;
$$;
