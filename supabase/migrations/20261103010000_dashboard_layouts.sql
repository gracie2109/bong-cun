-- Personal dashboard layouts. Widget and metric definitions live in code; a row only says which
-- widgets a person placed where, how big, and with which whitelisted settings.
create table if not exists public.dashboard_layouts (
  user_id       uuid        not null references auth.users (id) on delete cascade,
  dashboard_key text        not null check (dashboard_key ~ '^[a-z][a-z0-9_]{0,31}$'),
  layout        jsonb       not null,
  version       integer     not null default 1,
  updated_at    timestamptz not null default now(),
  primary key (user_id, dashboard_key)
);

alter table public.dashboard_layouts enable row level security;
revoke all on public.dashboard_layouts from anon, authenticated;
grant select on public.dashboard_layouts to authenticated;

drop policy if exists "own layout read" on public.dashboard_layouts;
create policy "own layout read" on public.dashboard_layouts
  for select to authenticated using (user_id = (select auth.uid()));

-- Shape check only: the app decides which widget types and metrics exist. One item at a time, with
-- early returns, so a cast never runs before its type check (Postgres does not order OR operands).
create or replace function public.dashboard_layout_item_ok(i jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  k text;
  n numeric;
begin
  if jsonb_typeof(i) is distinct from 'object' then return false; end if;
  if coalesce(i ->> 'id', '') !~ '^[a-z0-9]{8,24}$' then return false; end if;
  if coalesce(i ->> 'type', '') !~ '^[a-zA-Z][a-zA-Z0-9]{0,31}$' then return false; end if;
  foreach k in array array['x', 'y', 'w', 'h'] loop
    if jsonb_typeof(i -> k) is distinct from 'number' then return false; end if;
    n := (i ->> k)::numeric;
    if n % 1 <> 0 then return false; end if;
  end loop;
  if (i ->> 'x')::numeric not between 0 and 3 or (i ->> 'w')::numeric not between 1 and 4 then return false; end if;
  if (i ->> 'y')::numeric not between 0 and 199 or (i ->> 'h')::numeric not between 1 and 12 then return false; end if;
  if (i ->> 'x')::numeric + (i ->> 'w')::numeric > 4 then return false; end if;
  if i ? 'config' and (jsonb_typeof(i -> 'config') is distinct from 'object' or pg_column_size(i -> 'config') > 2048) then
    return false;
  end if;
  return true;
end;
$$;

create or replace function public.dashboard_layout_problem(p_layout jsonb)
returns text language plpgsql immutable set search_path = '' as $$
begin
  if jsonb_typeof(p_layout) is distinct from 'object' or (p_layout ->> 'v') is distinct from '1' then return 'shape'; end if;
  if jsonb_typeof(p_layout -> 'items') is distinct from 'array' then return 'shape'; end if;
  if jsonb_array_length(p_layout -> 'items') > 24 then return 'too_many'; end if;
  if pg_column_size(p_layout) > 32768 then return 'too_big'; end if;
  if exists (select 1 from jsonb_array_elements(p_layout -> 'items') i where not public.dashboard_layout_item_ok(i)) then
    return 'item';
  end if;
  if (select count(distinct i ->> 'id') from jsonb_array_elements(p_layout -> 'items') i)
     <> jsonb_array_length(p_layout -> 'items') then
    return 'duplicate_id';
  end if;
  return null;
end;
$$;

create or replace function public.save_dashboard_layout(
  p_dashboard text, p_layout jsonb, p_expected_version integer
) returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_problem text;
  v_version integer;
begin
  if v_user is null or not (select public.is_staff()) then
    raise exception 'only staff can save a dashboard layout' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_dashboard is null or p_dashboard !~ '^[a-z][a-z0-9_]{0,31}$' then
    raise exception 'bad dashboard key' using errcode = '22023', hint = 'bad_input';
  end if;
  v_problem := public.dashboard_layout_problem(p_layout);
  if v_problem is not null then
    raise exception 'invalid dashboard layout: %', v_problem using errcode = '22023', hint = 'layout_invalid';
  end if;

  if p_expected_version is null or p_expected_version = 0 then
    insert into public.dashboard_layouts (user_id, dashboard_key, layout)
    values (v_user, p_dashboard, p_layout)
    on conflict (user_id, dashboard_key) do nothing
    returning version into v_version;
  else
    update public.dashboard_layouts
    set layout = p_layout, version = version + 1, updated_at = now()
    where user_id = v_user and dashboard_key = p_dashboard and version = p_expected_version
    returning version into v_version;
  end if;

  if v_version is null then
    raise exception 'the layout was changed somewhere else' using errcode = 'P0001', hint = 'layout_conflict';
  end if;
  return v_version;
end;
$$;

create or replace function public.reset_dashboard_layout(p_dashboard text)
returns void language sql security definer set search_path = '' as $$
  delete from public.dashboard_layouts
  where user_id = (select auth.uid()) and dashboard_key = p_dashboard;
$$;

revoke all on function public.save_dashboard_layout(text, jsonb, integer) from public, anon;
revoke all on function public.reset_dashboard_layout(text) from public, anon;
revoke all on function public.dashboard_layout_item_ok(jsonb) from public, anon;
revoke all on function public.dashboard_layout_problem(jsonb) from public, anon;
grant execute on function public.save_dashboard_layout(text, jsonb, integer) to authenticated;
grant execute on function public.reset_dashboard_layout(text) to authenticated;
