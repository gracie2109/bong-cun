-- Customer UI, step 5 (2/2): staff link a web account to a counter customer (docs/giao-dien-khach-hang.md, 3.3 and 6.2).
--
--  search_unlinked_accounts(p_text, p_limit)  web accounts that have no customer record yet, found by
--                                             name, email or phone (an account whose phone was refused
--                                             by save_my_profile has no phone saved, so
--                                             search_customers cannot list it).
--  link_customer_account(p_customer, p_user)  sets customers.user_id. Only staff who may edit pets
--                                             (or admins); both sides must be free.
--
-- Safe to run more than once.

create or replace function public.can_link_accounts() returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or coalesce((select public.has_permission('pets', 'UPDATE')), false);
$$;

revoke execute on function public.can_link_accounts() from public, anon;
grant execute on function public.can_link_accounts() to authenticated;

create or replace function public.search_unlinked_accounts(p_text text, p_limit int default 5)
returns table (user_id uuid, full_name text, phone text, email text)
language sql
stable
security definer
set search_path = ''
as $$
  with q as (
    select
      lower(public.immutable_unaccent(btrim(coalesce(p_text, '')))) as term,
      regexp_replace(coalesce(p_text, ''), '\D', '', 'g') as digits
  )
  select u.id,
         coalesce(nullif(btrim(u.full_name), ''), u.display_name),
         u.phone_number,
         u.email
  from public.users u, q
  where public.can_link_accounts()
    and length(q.term) >= 2
    and not exists (select 1 from public.customers c where c.user_id = u.id)
    and (
      lower(public.immutable_unaccent(
        coalesce(u.full_name, '') || ' ' || coalesce(u.display_name, '') || ' ' || coalesce(u.email, '')
      )) like '%' || replace(replace(replace(q.term, '\', '\\'), '%', '\%'), '_', '\_') || '%'
      or (length(q.digits) >= 3
          and regexp_replace(coalesce(u.phone_number, ''), '\D', '', 'g') like q.digits || '%')
    )
  order by 2
  limit greatest(1, least(coalesce(p_limit, 5), 20));
$$;

revoke execute on function public.search_unlinked_accounts(text, int) from public, anon;
grant execute on function public.search_unlinked_accounts(text, int) to authenticated;

-- Errors (hint): forbidden, customer_not_found, account_not_found, customer_has_account, account_has_customer.
create or replace function public.link_customer_account(p_customer uuid, p_user uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_owner uuid;
begin
  if not public.can_link_accounts() then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  select user_id into v_owner from public.customers where id = p_customer for update;
  if not found then
    raise exception 'customer not found' using errcode = 'P0002', hint = 'customer_not_found';
  end if;
  if v_owner is not null then
    raise exception 'customer already has an account' using errcode = '22023', hint = 'customer_has_account';
  end if;
  if not exists (select 1 from public.users where id = p_user) then
    raise exception 'account not found' using errcode = 'P0002', hint = 'account_not_found';
  end if;
  if exists (select 1 from public.customers where user_id = p_user) then
    raise exception 'account already has a customer record' using errcode = '22023', hint = 'account_has_customer';
  end if;
  update public.customers set user_id = p_user, updated_at = now() where id = p_customer;
end;
$$;

revoke execute on function public.link_customer_account(uuid, uuid) from public, anon;
grant execute on function public.link_customer_account(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
