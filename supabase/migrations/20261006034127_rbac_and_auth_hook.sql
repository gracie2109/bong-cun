-- Signup trigger, role helpers and the Custom Access Token Hook.
-- The hook must also be ENABLED in the dashboard:
--   Authentication > Hooks > Custom Access Token > public.custom_access_token_hook

-- New auth user -> profile + default role. Role is NEVER read from user
-- metadata (that is client-controlled at signup).
create function public.handle_new_user() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, display_name, full_name, phone_number, photo_url)
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
  insert into public.user_roles (user_id, role) values (new.id, 'customer');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

revoke execute on function public.handle_new_user() from public, anon, authenticated;

-- Role helpers read the signed JWT claim. A role change takes effect when the
-- user's access token is next refreshed.
create function public.is_admin() returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select auth.jwt() ->> 'user_role') in ('admin', 'superAdmin'), false);
$$;

create function public.is_super_admin() returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select auth.jwt() ->> 'user_role') = 'superAdmin', false);
$$;

-- Custom Access Token Hook: copies user_roles.role into the JWT as `user_role`.
create function public.custom_access_token_hook(event jsonb) returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  claims    jsonb;
  user_role text;
begin
  select role into user_role
  from public.user_roles
  where user_id = (event ->> 'user_id')::uuid;

  claims := jsonb_set(event -> 'claims', '{user_role}', to_jsonb(coalesce(user_role, 'customer')));
  return jsonb_set(event, '{claims}', claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from public, anon, authenticated;
grant select on table public.user_roles to supabase_auth_admin;
