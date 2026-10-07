-- Roles per (staff, branch) and a permission check the database can enforce.
--
-- Before: a user had one global role (users.role, copied into the JWT as user_role) and
-- role_permissions was reference data only; RLS checked is_admin()/is_staff() by role name.
-- After: a staff member gets a role at each branch they work in (staff_branches). The
-- grants of that role (role_permissions) are checked by has_permission(), which RLS
-- policies and RPCs can call. users.role stays as the account type that opens the admin
-- area, so every existing policy keeps working while modules move to has_permission().

-- ------------------------------------------------------------------ roles
-- System roles cannot be renamed or deleted: the signup trigger needs 'customer' and
-- is_super_admin() needs 'superAdmin'.
alter table public.roles add column is_system boolean not null default false;
update public.roles set is_system = true where name in ('superAdmin', 'customer');

drop policy "super admin delete" on public.roles;
create policy "super admin delete" on public.roles
  for delete to authenticated
  using ((select public.is_super_admin()) and not is_system);

-- Grouping and ordering for the permission screens. Existing rows keep working without them.
alter table public.permissions
  add column module     text,
  add column sort_order integer not null default 0;

-- --------------------------------------------------------- staff_branches
create table public.staff_branches (
  user_id    uuid not null references public.users(id) on delete cascade,
  branch_id  uuid not null references public.branches(id) on delete cascade,
  role       text not null references public.roles(name) on update cascade on delete restrict
             check (role <> 'customer'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, branch_id)
);
create index staff_branches_branch_idx on public.staff_branches (branch_id);
create index staff_branches_role_idx on public.staff_branches (role);

create trigger set_updated_at before update on public.staff_branches
  for each row execute function public.set_updated_at();

-- Today every staff account works at the single branch, with the role it already has.
insert into public.staff_branches (user_id, branch_id, role)
select u.id, b.id, u.role
from public.users u
cross join public.branches b
where u.role <> 'customer'
on conflict do nothing;

alter table public.staff_branches enable row level security;

create policy "own or admin read" on public.staff_branches
  for select to authenticated
  using (user_id = (select auth.uid()) or (select public.is_admin()));
create policy "super admin insert" on public.staff_branches
  for insert to authenticated with check ((select public.is_super_admin()));
create policy "super admin update" on public.staff_branches
  for update to authenticated
  using ((select public.is_super_admin())) with check ((select public.is_super_admin()));
create policy "super admin delete" on public.staff_branches
  for delete to authenticated using ((select public.is_super_admin()));

grant select on table public.staff_branches to supabase_auth_admin;
create policy "auth hook read" on public.staff_branches
  for select to supabase_auth_admin
  using (true);

-- ---------------------------------------------------------- permission check
-- True when the caller may do p_method on p_permission, at p_branch or (when null) at any
-- branch they work in. A superAdmin may do everything. 'ALL' in a grant means every method.
-- SECURITY DEFINER so policies on other tables can call it without granting reads on
-- staff_branches; it only ever answers for auth.uid().
create function public.has_permission(
  p_permission text,
  p_method     text,
  p_branch     uuid default null
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select public.is_super_admin()) or exists (
    select 1
    from public.staff_branches sb
    join public.role_permissions rp on rp.role = sb.role
    where sb.user_id = (select auth.uid())
      and (p_branch is null or sb.branch_id = p_branch)
      and rp.permission = p_permission
      and rp.methods && array[upper(p_method), 'ALL']
  );
$$;

revoke execute on function public.has_permission(text, text, uuid) from public, anon;
grant execute on function public.has_permission(text, text, uuid) to authenticated;

-- What the caller may do, for hiding buttons and menu items in the admin UI. One row per
-- (branch, permission); the database still enforces through RLS.
create function public.my_permissions(p_branch uuid default null)
returns table (branch_id uuid, role text, permission text, methods text[])
language sql
stable
security definer
set search_path = ''
as $$
  select b.id, 'superAdmin', p.name, p.methods
  from public.branches b
  cross join public.permissions p
  where (select public.is_super_admin())
    and (p_branch is null or b.id = p_branch)
  union all
  select sb.branch_id, sb.role, rp.permission, rp.methods
  from public.staff_branches sb
  join public.role_permissions rp on rp.role = sb.role
  where not (select public.is_super_admin())
    and sb.user_id = (select auth.uid())
    and (p_branch is null or sb.branch_id = p_branch);
$$;

revoke execute on function public.my_permissions(uuid) from public, anon;
grant execute on function public.my_permissions(uuid) to authenticated;

-- ------------------------------------------------------- staff assignment
-- Replaces a staff member's branch roles in one call.
-- p: [{ "branch_id": "<uuid>", "role": "cashier" }, ...]
-- SECURITY INVOKER: the superAdmin-only policies on staff_branches apply.
create function public.save_staff_branches(p_user uuid, p jsonb) returns void
language plpgsql
set search_path = ''
as $$
begin
  delete from public.staff_branches where user_id = p_user;
  insert into public.staff_branches (user_id, branch_id, role)
  select p_user, (e ->> 'branch_id')::uuid, e ->> 'role'
  from jsonb_array_elements(coalesce(p, '[]'::jsonb)) as t(e);
end;
$$;

revoke execute on function public.save_staff_branches(uuid, jsonb) from public, anon;
grant execute on function public.save_staff_branches(uuid, jsonb) to authenticated;

-- --------------------------------------------------------------- save_role
-- Same contract as before, plus: a system role keeps its name.
create or replace function public.save_role(p jsonb, p_id text default null) returns text
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

-- ---------------------------------------------------------------- JWT claim
-- Adds branch_ids (the branches the user works in) next to user_role, so RLS on
-- branch-scoped tables can filter without a lookup. Takes effect at the next token refresh.
create or replace function public.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  claims     jsonb;
  user_role  text;
  branch_ids jsonb;
begin
  select role into user_role
  from public.users
  where id = (event ->> 'user_id')::uuid;

  select coalesce(jsonb_agg(branch_id), '[]'::jsonb) into branch_ids
  from public.staff_branches
  where user_id = (event ->> 'user_id')::uuid;

  claims := jsonb_set(event -> 'claims', '{user_role}', to_jsonb(coalesce(user_role, 'customer')));
  claims := jsonb_set(claims, '{branch_ids}', branch_ids);
  return jsonb_set(event, '{claims}', claims);
end;
$$;
