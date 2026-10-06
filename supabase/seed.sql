-- Dev seed — replaces scripts/seed.mjs. Re-runnable (ON CONFLICT DO NOTHING).
-- REFERENCE data: permissions, role_permissions, pet_weights.
-- SAMPLE data: pets, pet_services — replace before production.
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

-- ids kept verbatim from src/data/pet-weights.json (including 'from15to14').
insert into public.pet_weights (id, label_vi, label_en, sort_order) values
  ('lessthan2',  'Dưới 2kg',   'Less than 2kg',   1),
  ('from2to4',   'Từ 2-4kg',   'From 2-4kg',      2),
  ('morethan5',  'Trên 5kg',   'More than 5kg',   3),
  ('from10to14', 'Từ 10-14kg', 'From 10-14kg',    4),
  ('from15to14', 'Từ 15-20kg', 'From 15-20kg',    5)
on conflict (id) do nothing;

insert into public.pets (name, icon) values
  ('Dog', 'lucide:dog'),
  ('Cat', 'lucide:cat')
on conflict (name) do nothing;

insert into public.pet_services (name, description, unit, type) values
  ('Grooming', 'Sample service — replace with real data', 'unit1', 'by_weight'),
  ('Boarding', 'Sample service — replace with real data', 'unit2', 'all')
on conflict (name) do nothing;

insert into public.pet_service_pets (service_id, pet_id)
select s.id, p.id
from public.pet_services s
cross join public.pets p
where s.name in ('Grooming', 'Boarding') and p.name in ('Dog', 'Cat')
on conflict do nothing;
