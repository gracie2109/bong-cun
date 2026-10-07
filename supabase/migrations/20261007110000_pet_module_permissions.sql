-- Customers and pets followed the account type: any staff account (is_staff) could read,
-- add and edit them, so a cashier granted only "pets: Xem" could still add and edit.
-- Replace those policies so the permission grants decide: the "permission ..." policies
-- from 20261007100000 cover staff roles, and admin accounts keep full access as before.
-- Safe to run more than once.

do $$
declare t text;
begin
  foreach t in array array['customers', 'pets', 'pet_owners', 'pet_weight_logs'] loop
    if to_regclass(format('public.%I', t)) is null then
      raise notice 'skip %: table not found', t;
      continue;
    end if;
    execute format('drop policy if exists "staff read" on public.%I', t);
    execute format('drop policy if exists "staff insert" on public.%I', t);
    execute format('drop policy if exists "staff update" on public.%I', t);
    execute format('drop policy if exists "admin read" on public.%I', t);
    execute format('drop policy if exists "admin insert" on public.%I', t);
    execute format('drop policy if exists "admin update" on public.%I', t);
    execute format('drop policy if exists "admin delete" on public.%I', t);
    execute format(
      'create policy "admin read" on public.%I for select to authenticated
         using ((select public.is_admin()))', t);
    execute format(
      'create policy "admin insert" on public.%I for insert to authenticated
         with check ((select public.is_admin()))', t);
    execute format(
      'create policy "admin update" on public.%I for update to authenticated
         using ((select public.is_admin())) with check ((select public.is_admin()))', t);
    execute format(
      'create policy "admin delete" on public.%I for delete to authenticated
         using ((select public.is_admin()))', t);
  end loop;
end;
$$;

-- Logging a weight edits the pet's profile, so it needs "pets: Sửa" rather than "Thêm".
do $$
begin
  if to_regclass('public.pet_weight_logs') is not null then
    drop policy if exists "permission insert" on public.pet_weight_logs;
    create policy "permission insert" on public.pet_weight_logs for insert to authenticated
      with check ((select public.has_permission('pets', 'UPDATE')));
  end if;
end;
$$;

notify pgrst, 'reload schema';
