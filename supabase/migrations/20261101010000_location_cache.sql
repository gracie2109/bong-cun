-- Read-only cache of the Location Service catalog (provinces and communes in force since 2025-07-01)
-- and of its GHN code mapping, plus the RPCs the address pickers read.
--
--  The three tables are written only by migrations (the "Location sync" workflow generates the
--  data ones, docs/ke-hoach-noi-dia-gioi.md section 5). They are empty until the first sync.
--  Row level security is on with no policy and no grant: the app reads through the location_*
--  functions below, which are security definer. The GHN codes have no read function here.
--  Safe to run more than once.

-- One normalised form for search: lower case, no accents, "đ" as "d", single spaces.
create or replace function public.location_search_key(p_text text) returns text
    language sql immutable parallel safe
    set search_path to ''
    as $$
  select regexp_replace(lower(public.immutable_unaccent(btrim(coalesce(p_text, '')))), '\s+', ' ', 'g');
$$;

create table if not exists public.location_catalogs (
  id            text primary key,
  source        text not null,
  source_ref    text,
  effective_on  date not null,
  extracted_at  timestamptz,
  checksum      text,
  is_current    boolean not null default false,
  record_counts jsonb not null default '{}'::jsonb,
  synced_at     timestamptz not null default now()
);
create unique index if not exists location_catalogs_current on public.location_catalogs (is_current) where is_current;

create table if not exists public.location_units (
  code           text primary key check (code ~ '^vn_[0-9a-z]{20}$'),
  level          text not null check (level in ('province', 'commune')),
  unit_type      text not null,
  official_code  text,
  name           text not null,
  full_name      text not null,
  parent_code    text references public.location_units (code),
  status         text not null check (status in ('active', 'retired')),
  effective_from date not null,
  effective_to   date,
  catalog_id     text not null references public.location_catalogs (id),
  search_key     text generated always as (public.location_search_key(full_name || ' ' || name)) stored,
  updated_at     timestamptz not null default now(),
  check ((level = 'province') = (parent_code is null))
);
create index if not exists location_units_parent_active on public.location_units (parent_code) where status = 'active';
create index if not exists location_units_search on public.location_units using gin (search_key extensions.gin_trgm_ops);

create table if not exists public.location_provider_codes (
  code                 text not null references public.location_units (code),
  provider             text not null check (provider in ('ghn')),
  provider_model       text not null check (provider_model in ('ghn_v2')),
  provider_environment text not null check (provider_environment in ('production', 'test')),
  provider_code        text not null,
  provider_parent_code text,
  provider_name        text not null,
  match_method         text not null,
  verified_at          timestamptz,
  active               boolean not null default true,
  catalog_id           text not null references public.location_catalogs (id),
  primary key (provider, provider_model, code)
);

alter table public.location_catalogs enable row level security;
alter table public.location_units enable row level security;
alter table public.location_provider_codes enable row level security;
revoke all on public.location_catalogs, public.location_units, public.location_provider_codes from anon, authenticated;

-- ---------------------------------------------------------------- reads

create or replace function public.location_provinces() returns jsonb
    language sql stable security definer
    set search_path to ''
    as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'code', u.code, 'official_code', u.official_code, 'name', u.name,
           'full_name', u.full_name, 'unit_type', u.unit_type
         ) order by u.full_name), '[]'::jsonb)
  from public.location_units u
  where u.level = 'province' and u.status = 'active';
$$;

create or replace function public.location_communes(
  p_province text, p_search text default null, p_page integer default 1, p_page_size integer default 500
) returns jsonb
    language plpgsql stable security definer
    set search_path to ''
    as $$
declare
  v_size int := coalesce(p_page_size, 500);
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_key  text := public.location_search_key(p_search);
  v_like text;
  v_total bigint;
  v_items jsonb;
begin
  if v_size < 1 or v_size > 500 then
    raise exception 'page size out of range' using errcode = '22023', hint = 'invalid_input';
  end if;
  if not exists (select 1 from public.location_units where code = p_province and level = 'province' and status = 'active') then
    raise exception 'not an active province' using errcode = '22023', hint = 'invalid_input';
  end if;
  v_like := case when v_key = '' then null
                 else '%' || replace(replace(replace(v_key, '\', '\\'), '%', '\%'), '_', '\_') || '%' end;

  select count(*) into v_total
  from public.location_units u
  where u.parent_code = p_province and u.status = 'active' and (v_like is null or u.search_key like v_like);

  select coalesce(jsonb_agg(row_to_json(x)::jsonb order by x.full_name, x.code), '[]'::jsonb) into v_items
  from (
    select u.code, u.official_code, u.name, u.full_name, u.unit_type
    from public.location_units u
    where u.parent_code = p_province and u.status = 'active' and (v_like is null or u.search_key like v_like)
    order by u.full_name, u.code
    limit v_size offset (v_page - 1) * v_size
  ) x;

  return jsonb_build_object('items', v_items, 'total', v_total);
end;
$$;

create or replace function public.location_unit(p_code text) returns jsonb
    language plpgsql stable security definer
    set search_path to ''
    as $$
declare
  v_result jsonb;
begin
  select jsonb_build_object(
           'code', u.code, 'level', u.level, 'official_code', u.official_code, 'name', u.name,
           'full_name', u.full_name, 'unit_type', u.unit_type, 'status', u.status,
           'province', case when p.code is null then null
                            else jsonb_build_object('code', p.code, 'full_name', p.full_name) end)
    into v_result
  from public.location_units u
  left join public.location_units p on p.code = u.parent_code
  where u.code = p_code;
  if v_result is null then
    raise exception 'location % not found', p_code using errcode = 'P0002', hint = 'location_not_found';
  end if;
  return v_result;
end;
$$;

create or replace function public.location_search(p_search text, p_page integer default 1, p_page_size integer default 20)
    returns jsonb
    language plpgsql stable security definer
    set search_path to ''
    as $$
declare
  v_size int := coalesce(p_page_size, 20);
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_key  text := public.location_search_key(p_search);
  v_esc  text;
  v_total bigint;
  v_items jsonb;
begin
  if length(v_key) < 2 then
    raise exception 'search text too short' using errcode = '22023', hint = 'location_search_too_short';
  end if;
  if v_size < 1 or v_size > 500 then
    raise exception 'page size out of range' using errcode = '22023', hint = 'invalid_input';
  end if;
  v_esc := replace(replace(replace(v_key, '\', '\\'), '%', '\%'), '_', '\_');

  select count(*) into v_total
  from public.location_units u
  where u.level = 'commune' and u.status = 'active' and u.search_key like '%' || v_esc || '%';

  select coalesce(jsonb_agg(jsonb_build_object(
           'code', x.code, 'full_name', x.full_name, 'unit_type', x.unit_type,
           'province', jsonb_build_object('code', x.province_code, 'full_name', x.province_name)
         ) order by x.rank, x.full_name, x.code), '[]'::jsonb) into v_items
  from (
    select u.code, u.full_name, u.unit_type, p.code as province_code, p.full_name as province_name,
           case when public.location_search_key(u.name) like v_esc || '%' then 0
                when public.location_search_key(u.full_name) like v_esc || '%' then 1
                else 2 end as rank
    from public.location_units u
    join public.location_units p on p.code = u.parent_code
    where u.level = 'commune' and u.status = 'active' and u.search_key like '%' || v_esc || '%'
    order by rank, u.full_name, u.code
    limit v_size offset (v_page - 1) * v_size
  ) x;

  return jsonb_build_object('items', v_items, 'total', v_total);
end;
$$;

create or replace function public.location_catalog() returns jsonb
    language sql stable security definer
    set search_path to ''
    as $$
  select jsonb_build_object(
           'id', c.id, 'source', c.source, 'effective_on', c.effective_on,
           'synced_at', c.synced_at, 'record_counts', c.record_counts)
  from public.location_catalogs c
  where c.is_current;
$$;

revoke all on function public.location_provinces() from public;
revoke all on function public.location_communes(text, text, integer, integer) from public;
revoke all on function public.location_unit(text) from public;
revoke all on function public.location_search(text, integer, integer) from public;
revoke all on function public.location_catalog() from public;
grant execute on function public.location_provinces() to anon, authenticated;
grant execute on function public.location_communes(text, text, integer, integer) to anon, authenticated;
grant execute on function public.location_unit(text) to anon, authenticated;
grant execute on function public.location_search(text, integer, integer) to anon, authenticated;
grant execute on function public.location_catalog() to anon, authenticated;
