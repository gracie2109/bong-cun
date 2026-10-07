-- search_customers now also finds web accounts (public.users) that have no customer record yet,
-- so staff can pick someone who registered on the website. Choosing one creates the customer
-- record on the spot (register_pet). Staff cannot read public.users directly (RLS: own or admin),
-- so the function runs as definer, refuses non-staff, and returns only name, phone and email.

drop function public.search_customers(text, int);

create function public.search_customers(p_text text, p_limit int default 5)
returns table (
  customer_id uuid,
  user_id uuid,
  full_name text,
  phone text,
  email text,
  note text,
  pet_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  with q as (
    select
      lower(public.immutable_unaccent(btrim(p_text))) as term,
      regexp_replace(p_text, '\D', '', 'g') as digits
  ),
  pattern as (
    select '%' || replace(replace(replace(term, '\', '\\'), '%', '\%'), '_', '\_') || '%' as like_term,
           term, digits
    from q
  ),
  found as (
    select c.id as customer_id, c.user_id, c.full_name, c.phone, c.email, c.note
    from public.customers c, pattern p
    where c.is_active
      and (
        lower(public.immutable_unaccent(c.full_name || ' ' || coalesce(c.email, ''))) like p.like_term
        or (length(p.digits) >= 3 and c.phone_digits like p.digits || '%')
      )
    union all
    -- Web accounts with a usable phone number that are not customers yet.
    select null::uuid, u.id,
           coalesce(nullif(btrim(u.full_name), ''), u.display_name),
           u.phone_number, u.email, null::text
    from public.users u, pattern p
    where u.phone_number is not null
      and length(regexp_replace(u.phone_number, '\D', '', 'g')) between 8 and 15
      and not exists (select 1 from public.customers c where c.user_id = u.id)
      and not exists (
        select 1 from public.customers c
        where c.phone_digits = regexp_replace(u.phone_number, '\D', '', 'g')
      )
      and (
        lower(public.immutable_unaccent(
          coalesce(u.full_name, '') || ' ' || coalesce(u.display_name, '') || ' ' || coalesce(u.email, '')
        )) like p.like_term
        or (length(p.digits) >= 3 and regexp_replace(u.phone_number, '\D', '', 'g') like p.digits || '%')
      )
  )
  select
    f.customer_id, f.user_id, f.full_name, f.phone, f.email, f.note,
    case when f.customer_id is null then 0::bigint
      else (select count(*) from public.pet_owners po
            where po.customer_id = f.customer_id and po.to_date is null) end
  from found f
  where public.is_staff()
    and (select length(term) from q) >= 2
  order by f.full_name
  limit greatest(1, least(coalesce(p_limit, 5), 20));
$$;

revoke execute on function public.search_customers(text, int) from public, anon;
grant execute on function public.search_customers(text, int) to authenticated;

-- register_pet: the owner may also be a web account (customer.user_id). The customer record is
-- created from the account's name, phone and email, or reused when one already has that phone.
create or replace function public.register_pet(p jsonb) returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_customer uuid;
  v_account uuid := nullif(p #>> '{customer,user_id}', '')::uuid;
  v_pet uuid;
  v_weight numeric := nullif(p ->> 'weight_kg', '')::numeric;
begin
  v_customer := nullif(p #>> '{customer,id}', '')::uuid;

  if v_customer is null and v_account is not null then
    select id into v_customer from public.customers where user_id = v_account;
    if v_customer is null then
      insert into public.customers (full_name, phone, email, user_id)
      select coalesce(nullif(btrim(u.full_name), ''), u.display_name, u.email), u.phone_number, u.email, u.id
      from public.users u
      where u.id = v_account
      on conflict on constraint customers_phone_digits_key
        do update set user_id = coalesce(public.customers.user_id, excluded.user_id), updated_at = now()
      returning id into v_customer;
    end if;
    if v_customer is null then
      raise exception 'account % not found or has no phone number', v_account using errcode = 'P0002';
    end if;
  end if;

  if v_customer is null then
    insert into public.customers (full_name, phone, email)
    values (
      p #>> '{customer,full_name}',
      p #>> '{customer,phone}',
      nullif(p #>> '{customer,email}', '')
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  end if;

  insert into public.pets
    (species_id, name, breed, sex, neutered, birth_date, microchip, photo_url, allergies, behavior_notes)
  values (
    (p #>> '{pet,species_id}')::uuid,
    p #>> '{pet,name}',
    nullif(p #>> '{pet,breed}', ''),
    coalesce(nullif(p #>> '{pet,sex}', ''), 'unknown'),
    coalesce((p #>> '{pet,neutered}')::boolean, false),
    nullif(p #>> '{pet,birth_date}', '')::date,
    nullif(p #>> '{pet,microchip}', ''),
    nullif(p #>> '{pet,photo_url}', ''),
    nullif(p #>> '{pet,allergies}', ''),
    nullif(p #>> '{pet,behavior_notes}', '')
  )
  returning id into v_pet;

  insert into public.pet_owners (pet_id, customer_id, role) values (v_pet, v_customer, 'primary');

  if v_weight is not null then
    insert into public.pet_weight_logs (pet_id, weight_kg) values (v_pet, v_weight);
  end if;

  return v_pet;
end;
$$;
