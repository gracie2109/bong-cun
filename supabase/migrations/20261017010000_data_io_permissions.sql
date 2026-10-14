-- Data import/export, step 1 (docs/nhap-xuat-du-lieu.md, section 4). Safe to run more than once.
--
-- The IMPORT and EXPORT methods already exist; this only makes sure the permission codes that
-- get an export button (or an import for inventory) list them, so the permission screen can
-- tick them. No role is granted anything here: admin has ALL, others are set by the superAdmin.

update public.permissions p
set methods = p.methods || array['EXPORT']
where p.name in (
    'users', 'pets', 'petServices', 'schedule', 'pos', 'products', 'inventory', 'shop_orders', 'reports'
  )
  and not ('EXPORT' = any (p.methods));

update public.permissions p
set methods = p.methods || array['IMPORT']
where p.name in ('pets', 'products', 'inventory')
  and not ('IMPORT' = any (p.methods));

notify pgrst, 'reload schema';
