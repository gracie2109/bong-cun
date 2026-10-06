-- Row Level Security. Every table in public has RLS on; nothing is reachable
-- without an explicit policy. `(select ...)` wrappers let the planner cache
-- auth.uid() / is_admin() once per statement instead of once per row.

-- ------------------------------------------------ catalog: public read, admin write
do $$
declare t text;
begin
  foreach t in array array[
    'pets','pet_weights','pet_services','pet_service_pets','pet_service_prices',
    'pet_service_combos','combo_pets','combo_services','products','banners',
    'service_providers'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "public read" on public.%I for select to anon, authenticated using (true)', t);
    execute format('create policy "admin insert" on public.%I for insert to authenticated with check ((select public.is_admin()))', t);
    execute format('create policy "admin update" on public.%I for update to authenticated using ((select public.is_admin())) with check ((select public.is_admin()))', t);
    execute format('create policy "admin delete" on public.%I for delete to authenticated using ((select public.is_admin()))', t);
  end loop;
end;
$$;

-- ------------------------------- roles / permissions: authenticated read, superAdmin write
do $$
declare t text;
begin
  foreach t in array array['roles','permissions','role_permissions'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "authenticated read" on public.%I for select to authenticated using (true)', t);
    execute format('create policy "super admin insert" on public.%I for insert to authenticated with check ((select public.is_super_admin()))', t);
    execute format('create policy "super admin update" on public.%I for update to authenticated using ((select public.is_super_admin())) with check ((select public.is_super_admin()))', t);
    execute format('create policy "super admin delete" on public.%I for delete to authenticated using ((select public.is_super_admin()))', t);
  end loop;
end;
$$;

-- ------------------------------------------------------------------- profiles
-- Rows are created by the signup trigger; there is no insert or delete policy.
alter table public.profiles enable row level security;

create policy "own or admin read" on public.profiles
  for select to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()));

create policy "own or admin update" on public.profiles
  for update to authenticated
  using (id = (select auth.uid()) or (select public.is_admin()))
  with check (id = (select auth.uid()) or (select public.is_admin()));

-- ----------------------------------------------------------------- user_roles
-- Only a superAdmin may assign roles. The role column is never writable by the
-- row's own user, so there is no self-service escalation path.
alter table public.user_roles enable row level security;

create policy "own or admin read" on public.user_roles
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy "auth hook read" on public.user_roles
  for select to supabase_auth_admin
  using (true);

create policy "super admin insert" on public.user_roles
  for insert to authenticated with check ((select public.is_super_admin()));
create policy "super admin update" on public.user_roles
  for update to authenticated
  using ((select public.is_super_admin())) with check ((select public.is_super_admin()));
create policy "super admin delete" on public.user_roles
  for delete to authenticated using ((select public.is_super_admin()));

-- ------------------------------------------------------------------- bookings
-- Anonymous INSERT is intentional: the public home page embeds the booking form
-- (src/components/RegisterForm.vue). Anonymous callers get no SELECT, so the
-- client must generate the id itself instead of reading it back.
alter table public.bookings enable row level security;

create policy "public create" on public.bookings
  for insert to anon, authenticated
  with check (
    (user_id is null or user_id = (select auth.uid()))
    and status = 'PENDING'
    and not is_cancel
    and not is_moving_time
    and cancel_date is null
    and cancel_by is null
    and cancel_reason is null
    and confirm_changed_by is null
    and confirm_from_time is null
    and confirm_to_time is null
    and char_length(name) between 1 and 200
    and char_length(email) between 3 and 320
    and char_length(phone_number) between 6 and 20
    and (content is null or char_length(content) <= 2000)
  );

create policy "owner or admin read" on public.bookings
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy "admin update" on public.bookings
  for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admin delete" on public.bookings
  for delete to authenticated using ((select public.is_admin()));

-- --------------------------------------------------------------- orders / items
alter table public.orders enable row level security;

create policy "owner create" on public.orders
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy "owner or admin read" on public.orders
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));

create policy "admin update" on public.orders
  for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admin delete" on public.orders
  for delete to authenticated using ((select public.is_admin()));

alter table public.order_items enable row level security;

create policy "owner create" on public.order_items
  for insert to authenticated
  with check (
    status = 'PENDING'
    and not is_cancel
    and not is_moving_time
    and exists (
      select 1 from public.orders o
      where o.id = order_id and o.user_id = (select auth.uid())
    )
  );

create policy "owner or admin read" on public.order_items
  for select to authenticated
  using (
    (select public.is_admin())
    or exists (
      select 1 from public.orders o
      where o.id = order_id and o.user_id = (select auth.uid())
    )
  );

create policy "admin update" on public.order_items
  for update to authenticated
  using ((select public.is_admin())) with check ((select public.is_admin()));
create policy "admin delete" on public.order_items
  for delete to authenticated using ((select public.is_admin()));
