-- Shop checkout, step 8: the number on the "Đơn online" menu item (docs/checkout-shop.md, 5.2).
-- Safe to run more than once.
--
-- Online orders waiting for confirmation at the branch (null is the online branch). Staff without
-- shop_orders: VIEW get 0, so a menu that is polling never shows an error.

create or replace function public.shop_order_badge(p_branch uuid default null) returns int
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when public.can_shop_orders('VIEW', b.id) then
      (select count(*)::int from public.shop_orders o where o.branch_id = b.id and o.status = 'pending')
    else 0
  end
  from (select coalesce(p_branch, (select online_branch_id from public.shop_settings where id)) as id) b;
$$;

revoke execute on function public.shop_order_badge(uuid) from public, anon;
grant execute on function public.shop_order_badge(uuid) to authenticated;

notify pgrst, 'reload schema';
