-- Merge profiles + user_roles into a single public.users table that holds the
-- account info copied from Supabase Auth AND the role (same shape idea as the
-- old Firestore `users` collection). Safe to run now: no users exist yet.

-- 1. profiles -> users
alter table public.profiles rename to users;
alter table public.users rename constraint profiles_pkey to users_pkey;
alter table public.users rename constraint profiles_id_fkey to users_id_fkey;
alter table public.users rename constraint profiles_display_name_key to users_display_name_key;
alter table public.users rename constraint profiles_phone_number_key to users_phone_number_key;
alter table public.users rename constraint profiles_gender_check to users_gender_check;

-- 2. role lives on the user row
alter table public.users
  add column role text not null default 'customer'
  references public.roles(name) on update cascade on delete restrict;
create index users_role_idx on public.users (role);

update public.users u set role = ur.role from public.user_roles ur where ur.user_id = u.id;
drop table public.user_roles;

-- 3. Auth hook reads the role from users
create or replace function public.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  claims    jsonb;
  user_role text;
begin
  select role into user_role
  from public.users
  where id = (event ->> 'user_id')::uuid;

  claims := jsonb_set(event -> 'claims', '{user_role}', to_jsonb(coalesce(user_role, 'customer')));
  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant select on table public.users to supabase_auth_admin;
create policy "auth hook read" on public.users
  for select to supabase_auth_admin
  using (true);

-- 4. New Supabase Auth account -> row in public.users (role defaults to
-- 'customer'; it is never read from user metadata, which is client-controlled).
create or replace function public.handle_new_user() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, email, display_name, full_name, phone_number, photo_url)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''),
             nullif(new.raw_user_meta_data ->> 'name', '')),
    nullif(new.phone, ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url',
             new.raw_user_meta_data ->> 'picture')
  );
  return new;
end;
$$;

-- Keep users.email in sync when the auth email changes.
create function public.sync_user_email() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.users set email = new.email where id = new.id;
  return new;
end;
$$;
revoke execute on function public.sync_user_email() from public, anon, authenticated;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.sync_user_email();

-- 5. Column guard. Policies are row-level, so without this a user could update
-- their own `role` column (self-promotion). Only a superAdmin may change a role,
-- and email is owned by Supabase Auth. Server-side callers (service_role / SQL
-- editor / the auth service) have no JWT uid and are not restricted here.
create function public.guard_user_columns() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if (select auth.uid()) is not null then
    if new.role is distinct from old.role and not (select public.is_super_admin()) then
      raise exception 'only a superAdmin can change a role' using errcode = '42501';
    end if;
    if new.email is distinct from old.email then
      raise exception 'email is managed by authentication' using errcode = '42501';
    end if;
    if new.id is distinct from old.id then
      raise exception 'id is immutable' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create trigger guard_user_columns
  before update on public.users
  for each row execute function public.guard_user_columns();

-- 6. Pre-signup uniqueness check. Anonymous callers cannot read public.users,
-- so the signup form asks this instead of relying on an opaque DB error.
create function public.is_display_name_available(p_display_name text) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1 from public.users where lower(display_name) = lower(p_display_name)
  );
$$;
revoke execute on function public.is_display_name_available(text) from public;
grant execute on function public.is_display_name_available(text) to anon, authenticated;
