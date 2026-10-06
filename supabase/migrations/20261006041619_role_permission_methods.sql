-- The admin UI grants a role a set of methods PER permission
-- ({ id: <permission>, method: ['CREATE','VIEW',...] }), not just a permission
-- name, so role_permissions needs a methods column.
alter table public.role_permissions
  add column methods text[] not null default '{}',
  add constraint role_permissions_methods_valid check (
    methods <@ array['CREATE','VIEW','DELETE','UPDATE','IMPORT','EXPORT','SETTING','ALL']
  );

-- Seeded reference grants meant "everything on that permission".
update public.role_permissions rp
set methods = p.methods
from public.permissions p
where p.name = rp.permission and rp.methods = '{}';

-- Atomic role save. SECURITY INVOKER: the superAdmin-only policies still apply.
-- p: { name, description, permissions: [{ id: <permission name>, methods: [...] }] }
create function public.save_role(p jsonb, p_id text default null) returns text
language plpgsql
set search_path = ''
as $$
declare
  v_name text;
begin
  if p_id is null then
    insert into public.roles (name, description)
    values (p ->> 'name', nullif(p ->> 'description', ''))
    returning name into v_name;
  else
    update public.roles
    set name = p ->> 'name', description = nullif(p ->> 'description', '')
    where name = p_id
    returning name into v_name;

    if v_name is null then
      raise exception 'role % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  delete from public.role_permissions where role = v_name;
  insert into public.role_permissions (role, permission, methods)
  select
    v_name,
    e ->> 'id',
    array(select jsonb_array_elements_text(coalesce(e -> 'methods', '[]'::jsonb)))
  from jsonb_array_elements(coalesce(p -> 'permissions', '[]'::jsonb)) as t(e);

  return v_name;
end;
$$;

revoke execute on function public.save_role(jsonb, text) from public, anon;
grant execute on function public.save_role(jsonb, text) to authenticated;
