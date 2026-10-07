-- Dev seed — replaces scripts/seed.mjs. Re-runnable (ON CONFLICT DO NOTHING).
-- REFERENCE data: permissions, role_permissions. (branches: CS01 comes from the migration.)
-- SAMPLE data: species, weight_brackets, pet_services — replace before production.
-- Not seeded (no shape evidence): products, banners, service_providers, combos,
-- prices, bookings, orders. No admin user: see "first admin" in the docs.
-- (roles are inserted by the schema migration; the signup trigger needs them.)

insert into public.permissions (name, description, methods) values
  ('users',       'Quản lý người dùng', array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','SETTING','ALL']),
  ('pets',        'Quản lý thú cưng',   array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','SETTING','ALL']),
  ('petServices', 'Quản lý dịch vụ',    array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','SETTING','ALL']),
  ('schedule',    'Quản lý lịch hẹn',   array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','SETTING','ALL']),
  ('settings',    'Cấu hình hệ thống',  array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','SETTING','ALL'])
on conflict (name) do nothing;

-- Reference data for the admin UI. Enforcement is done by RLS via the JWT
-- user_role claim, not by this table. Each grant is "all methods" of the permission.
insert into public.role_permissions (role, permission, methods)
select r.role, p.name, p.methods
from (values
  ('superAdmin', 'users'), ('superAdmin', 'pets'), ('superAdmin', 'petServices'),
  ('superAdmin', 'schedule'), ('superAdmin', 'settings'),
  ('admin', 'users'), ('admin', 'pets'), ('admin', 'petServices'), ('admin', 'schedule'),
  ('cashier', 'schedule')
) as r(role, permission)
join public.permissions p on p.name = r.permission
on conflict do nothing;

insert into public.species (name, icon) values
  ('Chó', 'lucide:dog'),
  ('Mèo', 'lucide:cat')
on conflict (name) do nothing;

select public.seed_default_weight_brackets(id) from public.species;

insert into public.pet_services (name, description, unit, type) values
  ('Grooming', 'Sample service — replace with real data', 'unit1', 'by_weight'),
  ('Boarding', 'Sample service — replace with real data', 'unit2', 'all')
on conflict (name) do nothing;

insert into public.service_species (service_id, species_id)
select s.id, p.id
from public.pet_services s
cross join public.species p
where s.name in ('Grooming', 'Boarding') and p.name in ('Chó', 'Mèo')
on conflict do nothing;
