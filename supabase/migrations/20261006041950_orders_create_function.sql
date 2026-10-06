-- Who made a booking is decided by the database from the caller's JWT, not sent
-- by the client. Anonymous visitors get NULL; a signed-in user gets their own id.
alter table public.bookings alter column user_id set default auth.uid();

-- Atomic order + lines. SECURITY INVOKER: the owner-only RLS policies apply, and
-- user_id is always the caller (a client cannot create an order for someone else).
-- p: { name, phone_number, pet_num, scheduled_at,
--      services: [{ id, type: 'combo' | 'service', name, price, duration_minutes }] }
create function public.create_order(p jsonb) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.orders (name, phone_number, pet_num, scheduled_at, user_id)
  values (
    p ->> 'name',
    p ->> 'phone_number',
    nullif(p ->> 'pet_num', '')::int,
    nullif(p ->> 'scheduled_at', '')::timestamptz,
    auth.uid()
  )
  returning id into v_id;

  insert into public.order_items (order_id, service_id, combo_id, name, price, duration_minutes)
  select
    v_id,
    case when e ->> 'type' = 'combo' then null else (e ->> 'id')::uuid end,
    case when e ->> 'type' = 'combo' then (e ->> 'id')::uuid else null end,
    e ->> 'name',
    (e ->> 'price')::numeric,
    nullif(e ->> 'duration_minutes', '')::int
  from jsonb_array_elements(coalesce(p -> 'services', '[]'::jsonb)) as t(e);

  return v_id;
end;
$$;

revoke execute on function public.create_order(jsonb) from public, anon;
grant execute on function public.create_order(jsonb) to authenticated;
