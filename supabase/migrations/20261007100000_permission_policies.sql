-- Make the permissions set on the "Vai trò & Phân quyền" screens take effect in the database.
-- Until now the admin data was gated by account type (is_admin(): admin, superAdmin), so a
-- cashier granted "schedule" still read nothing. These policies are added next to the
-- existing ones; Postgres ORs permissive policies, so nobody loses access they had.
--
-- Permission codes used (the ones on the permission list):
--   users       -> public.users (customer and staff accounts)
--   pets        -> customers, pets, pet_owners, pet_weight_logs
--   petServices -> species, services, prices, combos, weight brackets
--   schedule    -> bookings, orders, order_items
-- Methods map to VIEW = select, CREATE = insert, UPDATE = update, DELETE = delete.
-- has_permission(code, method) with no branch means "at any branch the caller works in".

-- ------------------------------------------------------------------ is_staff
-- Staff = the old staff account types, or anyone holding a role at a branch (branch_ids
-- comes from the access token hook). Used by the pet module policies and search_customers.
create or replace function public.is_staff() returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(
    (select auth.jwt() ->> 'user_role') in ('admin', 'superAdmin', 'cashier')
      or jsonb_array_length(coalesce((select auth.jwt() -> 'branch_ids'), '[]'::jsonb)) > 0,
    false
  );
$$;

-- ---------------------------------------------------------- permission policies
do $$
declare
  t    text;
  code text;
  grp  record;
begin
  for grp in
    select * from (values
      ('users',       array['users']),
      ('pets',        array['customers', 'pets', 'pet_owners', 'pet_weight_logs']),
      ('petServices', array['species', 'pet_services', 'service_species', 'pet_service_prices',
                            'pet_service_combos', 'combo_species', 'combo_services', 'weight_brackets']),
      ('schedule',    array['bookings', 'orders', 'order_items'])
    ) as g(code, tables)
  loop
    code := grp.code;
    foreach t in array grp.tables loop
      if to_regclass(format('public.%I', t)) is null then
        raise notice 'skip %: table not found', t;
        continue;
      end if;
      execute format(
        'create policy "permission read" on public.%I for select to authenticated
           using ((select public.has_permission(%L, ''VIEW'')))', t, code);
      -- Account rows are created by sign-up only; staff edit them but never insert or delete.
      if code <> 'users' then
        execute format(
          'create policy "permission insert" on public.%I for insert to authenticated
             with check ((select public.has_permission(%L, ''CREATE'')))', t, code);
        execute format(
          'create policy "permission delete" on public.%I for delete to authenticated
             using ((select public.has_permission(%L, ''DELETE'')))', t, code);
      end if;
      -- guard_user_columns still stops anyone but a superAdmin from changing users.role.
      execute format(
        'create policy "permission update" on public.%I for update to authenticated
           using ((select public.has_permission(%L, ''UPDATE'')))
           with check ((select public.has_permission(%L, ''UPDATE'')))', t, code, code);
    end loop;
  end loop;
end;
$$;

notify pgrst, 'reload schema';
