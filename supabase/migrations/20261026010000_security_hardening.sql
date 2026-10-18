-- Security hardening after the anti-clone review (docs/security-anti-clone.md, section 3).
-- Forward-only and safe to re-run.

-- M1. The old public "Đặt lịch" form is gone: anonymous visitors may no longer insert into
-- bookings. Staff keep the "permission insert" policy.
drop policy if exists "public create" on public.bookings;

-- M3. Only staff upload into their own folder of the public images bucket (admin screens);
-- customers could otherwise use it as free public image hosting.
drop policy if exists "images: upload into own folder" on storage.objects;
create policy "images: upload into own folder" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'images'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (select public.is_staff())
  );

-- M2. Online orders reserve online stock while pending/confirmed, so one account must not
-- be able to lock the shop's stock with a burst of orders.
create or replace function public.shop_orders_throttle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_waiting int;
  v_recent  int;
begin
  select count(*) filter (where o.status = 'pending'),
         count(*) filter (where o.placed_at > now() - interval '1 hour')
    into v_waiting, v_recent
  from public.shop_orders o
  where o.user_id = new.user_id;

  if v_waiting >= 5 or v_recent >= 10 then
    raise exception 'too many online orders, try again later'
      using errcode = '22023', hint = 'too_many_orders';
  end if;
  return new;
end;
$$;

revoke execute on function public.shop_orders_throttle() from public, anon, authenticated;

drop trigger if exists shop_orders_throttle on public.shop_orders;
create trigger shop_orders_throttle
  before insert on public.shop_orders
  for each row execute function public.shop_orders_throttle();

-- I1. Trigger functions cannot be called directly anyway; drop the stray grants.
revoke execute on function public.pets_deceased_before() from public, anon, authenticated;
revoke execute on function public.pets_deceased_after() from public, anon, authenticated;

-- I1. pet_overview is security_invoker (RLS applies) but anon has no reason to see it.
revoke all on public.pet_overview from anon;
