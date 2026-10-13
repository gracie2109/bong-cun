-- Shop checkout, step 5 (2/4): "can be sold" holds back what open online orders reserved
-- (docs/checkout-shop.md, section 3.2). Safe to run more than once.
--
-- Redefines shop_available_qty of 20261016020000: the stock at the online branch that is not
-- expired, minus the base units of orders still 'pending' or 'confirmed' (not packed yet, so the
-- stock has not been taken). Never below zero. Products that do not track stock have no row.

create or replace function public.shop_available_qty(p_products uuid[])
returns table (product_id uuid, qty numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id,
         greatest(0,
           coalesce(sum(l.qty_on_hand) filter (
             where l.expiry_date is null or l.expiry_date >= public.business_date()), 0)
           - coalesce((
               select sum(ol.qty * ol.unit_factor)
               from public.shop_order_lines ol
               join public.shop_orders o on o.id = ol.order_id
               where ol.product_id = p.id
                 and o.branch_id = s.online_branch_id
                 and o.status in ('pending', 'confirmed')
             ), 0))
  from public.products p
  join public.shop_settings s on s.id
  left join public.stock_lots l
    on l.product_id = p.id and l.branch_id = s.online_branch_id and l.qty_on_hand > 0
  where p.id = any(p_products) and p.track_stock
  group by p.id, s.online_branch_id;
$$;

revoke execute on function public.shop_available_qty(uuid[]) from public, anon, authenticated;

notify pgrst, 'reload schema';
