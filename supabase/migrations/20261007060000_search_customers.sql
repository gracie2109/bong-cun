-- Basic customer search shared by every screen that needs to pick a customer (counter
-- registration today, appointments and POS later). One text box matches name, email and phone.
-- Accent- and case-insensitive ("nguyen" finds "Nguyễn"); a trigram index keeps substring
-- search fast. A richer search (filters, other screens' data) can extend this function later
-- without changing callers.

create extension if not exists pg_trgm with schema extensions;
create extension if not exists unaccent with schema extensions;

-- unaccent() is only STABLE, so an index needs this IMMUTABLE wrapper bound to one dictionary.
create function public.immutable_unaccent(text) returns text
language sql
immutable
parallel safe
strict
set search_path = ''
as $$ select extensions.unaccent('extensions.unaccent'::regdictionary, $1) $$;

create index customers_search_idx on public.customers
  using gin (lower(public.immutable_unaccent(full_name || ' ' || coalesce(email, ''))) extensions.gin_trgm_ops);

-- SECURITY INVOKER: the staff-only RLS policies on customers still decide who sees what.
create function public.search_customers(p_text text, p_limit int default 5)
returns table (
  id uuid,
  full_name text,
  phone text,
  email text,
  note text,
  pet_count bigint
)
language sql
stable
set search_path = ''
as $$
  with q as (
    select
      lower(public.immutable_unaccent(btrim(p_text))) as term,
      regexp_replace(p_text, '\D', '', 'g') as digits
  )
  select
    c.id, c.full_name, c.phone, c.email, c.note,
    (select count(*) from public.pet_owners po where po.customer_id = c.id and po.to_date is null)
  from public.customers c, q
  where c.is_active
    and length(q.term) >= 2
    and (
      lower(public.immutable_unaccent(c.full_name || ' ' || coalesce(c.email, ''))) like '%' || replace(replace(replace(q.term, '\', '\\'), '%', '\%'), '_', '\_') || '%'
      or (length(q.digits) >= 3 and c.phone_digits like q.digits || '%')
    )
  order by c.full_name
  limit greatest(1, least(coalesce(p_limit, 5), 20));
$$;

revoke execute on function public.search_customers(text, int) from public, anon;
grant execute on function public.search_customers(text, int) to authenticated;
