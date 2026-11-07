-- The attendance ("Nhân sự") permission lets someone see and manage OTHER people's shifts, registrations
-- and timesheets. Only the admin roles may hold it; every other role sees its own published schedule
-- and registers for itself (own-row policies already allow that without any permission).
--  1. Remove the permission from every role that is not an admin role (e.g. the test role "hr").
--  2. save_role refuses to grant it to any other role from now on.

delete from public.role_permissions
where permission = 'attendance' and role not in ('admin', 'superAdmin', 'super_admin');

create or replace function public.save_role(p jsonb, p_id text default null)
returns text
language plpgsql
set search_path to ''
as $$
declare
  v_name text;
begin
  if p_id is null then
    insert into public.roles (name, description)
    values (p ->> 'name', nullif(p ->> 'description', ''))
    returning name into v_name;
  else
    if exists (select 1 from public.roles where name = p_id and is_system)
       and p ->> 'name' is distinct from p_id then
      raise exception 'system role % cannot be renamed', p_id using errcode = '42501';
    end if;

    update public.roles
    set name = p ->> 'name', description = nullif(p ->> 'description', '')
    where name = p_id
    returning name into v_name;

    if v_name is null then
      raise exception 'role % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  if v_name not in ('admin', 'superAdmin', 'super_admin')
     and exists (
       select 1 from jsonb_array_elements(coalesce(p -> 'permissions', '[]'::jsonb)) as t(e)
       where e ->> 'id' = 'attendance'
         and jsonb_array_length(coalesce(e -> 'methods', '[]'::jsonb)) > 0
     ) then
    raise exception 'attendance permission is only for admin roles'
      using errcode = '42501', hint = 'attendance_admin_only';
  end if;

  delete from public.role_permissions where role = v_name;
  insert into public.role_permissions (role, permission, methods)
  select
    v_name,
    e ->> 'id',
    array(select jsonb_array_elements_text(coalesce(e -> 'methods', '[]'::jsonb)))
  from jsonb_array_elements(coalesce(p -> 'permissions', '[]'::jsonb)) as t(e)
  where jsonb_array_length(coalesce(e -> 'methods', '[]'::jsonb)) > 0;

  return v_name;
end;
$$;
