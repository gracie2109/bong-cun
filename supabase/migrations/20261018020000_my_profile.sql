-- Customer account profile (docs/giao-dien-khach-hang.md, step 4).
--
--  customers.birth_date  optional, filled by the customer in their profile.
--  my_profile()          the signed-in account's name, phone, birth date and customer id.
--  save_my_profile(p)    edits name, phone and birth date on the account and on its customer record;
--                        the record is created on the first save when the phone is free.
--
-- A web account is never linked to a customer record that already exists with the same phone (anyone
-- can type someone else's number): that answers `phone_in_use` and staff link the account in the admin.
-- Safe to run more than once.

alter table public.customers add column if not exists birth_date date;

create or replace function public.my_profile() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_row jsonb;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  select jsonb_build_object(
           'email', u.email,
           'full_name', coalesce(nullif(btrim(c.full_name), ''), u.full_name, u.display_name),
           'phone', coalesce(c.phone, u.phone_number),
           'birth_date', c.birth_date,
           'customer_id', c.id
         )
    into v_row
  from public.users u
  left join public.customers c on c.user_id = u.id
  where u.id = v_uid;
  return coalesce(v_row, jsonb_build_object('email', null, 'full_name', null, 'phone', null,
                                            'birth_date', null, 'customer_id', null));
end;
$$;

revoke execute on function public.my_profile() from public, anon;
grant execute on function public.my_profile() to authenticated;

-- p: { full_name, phone, birth_date? }. Errors (hint): invalid_name, invalid_phone, invalid_birth_date, phone_in_use.
create or replace function public.save_my_profile(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := auth.uid();
  v_name   text := btrim(coalesce(p ->> 'full_name', ''));
  v_phone  text := btrim(coalesce(p ->> 'phone', ''));
  v_digits text := regexp_replace(coalesce(p ->> 'phone', ''), '\D', '', 'g');
  v_birth  date;
  v_email  text;
  v_cust   uuid;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if length(v_name) = 0 or length(v_name) > 120 then
    raise exception 'name is required' using errcode = '22023', hint = 'invalid_name';
  end if;
  if length(v_digits) not between 8 and 15 then
    raise exception 'phone must have 8 to 15 digits' using errcode = '22023', hint = 'invalid_phone';
  end if;
  begin
    v_birth := nullif(btrim(coalesce(p ->> 'birth_date', '')), '')::date;
  exception when others then
    raise exception 'birth date is not a date' using errcode = '22023', hint = 'invalid_birth_date';
  end;
  if v_birth is not null and (v_birth > current_date or v_birth < date '1900-01-01') then
    raise exception 'birth date is out of range' using errcode = '22023', hint = 'invalid_birth_date';
  end if;

  select email into v_email from public.users where id = v_uid;
  select id into v_cust from public.customers where user_id = v_uid;

  -- The phone must not belong to another customer record or another account.
  if exists (
    select 1 from public.customers c
    where c.phone_digits = v_digits and c.id is distinct from v_cust
  ) or exists (
    select 1 from public.users u
    where u.phone_number = v_phone and u.id <> v_uid
  ) then
    raise exception 'phone is already used' using errcode = '22023', hint = 'phone_in_use';
  end if;

  begin
    update public.users set full_name = v_name, phone_number = v_phone, updated_at = now() where id = v_uid;
    if v_cust is null then
      insert into public.customers (full_name, phone, email, user_id, birth_date)
      values (v_name, v_phone, v_email, v_uid, v_birth)
      returning id into v_cust;
    else
      update public.customers
         set full_name = v_name, phone = v_phone, birth_date = v_birth, updated_at = now()
       where id = v_cust;
    end if;
  exception when unique_violation then
    raise exception 'phone is already used' using errcode = '22023', hint = 'phone_in_use';
  end;

  return public.my_profile();
end;
$$;

revoke execute on function public.save_my_profile(jsonb) from public, anon;
grant execute on function public.save_my_profile(jsonb) to authenticated;

notify pgrst, 'reload schema';
