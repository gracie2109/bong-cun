-- Shop checkout, step 1 (1/4): online shop settings and the "shop_orders" permission
-- (docs/checkout-shop.md, sections 3.2, 3.4, 4 and 5). Safe to run more than once.
--
-- shop_settings is a single row: which branch sells online, which payment / delivery methods
-- are on, the shipping defaults and the warehouse address GHN ships from. Everything in it is
-- safe to show the public (shop_public_settings); writes go through save_shop_settings only.
--
-- Permission "shop_orders" (module "Bán online"): VIEW = see online orders at the branch,
-- UPDATE = move them along, ALL = also edit these settings.

-- --------------------------------------------------------------- permissions
insert into public.permissions (name, description, methods, module, sort_order) values
  ('shop_orders', 'Đơn hàng online và cài đặt bán online', array['VIEW','UPDATE','ALL'], 'Bán online', 15)
on conflict (name) do nothing;

insert into public.role_permissions (role, permission, methods)
select r.role, r.permission, r.methods
from (values
  ('admin',   'shop_orders', array['ALL']),
  ('cashier', 'shop_orders', array['VIEW','UPDATE'])
) as r(role, permission, methods)
where exists (select 1 from public.roles where name = r.role)
on conflict do nothing;

create or replace function public.can_shop_orders(p_method text, p_branch uuid default null) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('shop_orders', p_method, p_branch));
$$;

revoke execute on function public.can_shop_orders(text, uuid) from public, anon;
grant execute on function public.can_shop_orders(text, uuid) to authenticated;

-- ------------------------------------------------------------------- table
create table if not exists public.shop_settings (
  id                   boolean primary key default true check (id),
  online_branch_id     uuid not null references public.branches(id) on delete restrict,
  allow_cod            boolean not null default true,
  allow_pickup         boolean not null default true,
  cod_max              numeric(14,0) not null default 10000000 check (cod_max > 0),
  default_weight_g     int not null default 500 check (default_weight_g > 0),
  flat_shipping_fee    numeric(14,0) not null default 30000 check (flat_shipping_fee >= 0),
  free_ship_from       numeric(14,0) check (free_ship_from > 0),
  ghn_from_province_id int,
  ghn_from_district_id int,
  ghn_from_ward_code   text,
  from_address_text    text,
  pickup_address       text,
  pickup_note          text,
  updated_at           timestamptz not null default now()
);

insert into public.shop_settings (online_branch_id)
select id from public.branches where code = 'CS01'
on conflict (id) do nothing;

alter table public.shop_settings enable row level security;

drop policy if exists "shop settings read" on public.shop_settings;
create policy "shop settings read" on public.shop_settings for select to authenticated
  using ((select public.can_shop_orders('VIEW', online_branch_id)));

revoke insert, update, delete on public.shop_settings from anon, authenticated;
revoke all on public.shop_settings from anon;

-- ---------------------------------------------------------------------- RPC
-- What the checkout needs. Nothing secret lives in the table, but the warehouse ward code is
-- left out because the public has no use for it.
create or replace function public.shop_public_settings() returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'online_branch_id', s.online_branch_id,
      'allow_cod', s.allow_cod,
      'allow_pickup', s.allow_pickup,
      'cod_max', s.cod_max,
      'default_weight_g', s.default_weight_g,
      'flat_shipping_fee', s.flat_shipping_fee,
      'free_ship_from', s.free_ship_from,
      'ghn_from_district_id', s.ghn_from_district_id,
      'ghn_from_ward_code', s.ghn_from_ward_code,
      'pickup_address', s.pickup_address,
      'pickup_note', s.pickup_note
    )
    from public.shop_settings s
    where s.id
  ), '{}'::jsonb);
$$;

revoke execute on function public.shop_public_settings() from public;
grant execute on function public.shop_public_settings() to anon, authenticated;

-- Staff view of the same row, including the warehouse address text.
create or replace function public.shop_admin_settings() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row public.shop_settings;
begin
  select * into v_row from public.shop_settings where id;
  if not found then
    return '{}'::jsonb;
  end if;
  if not public.can_shop_orders('VIEW', v_row.online_branch_id) then
    raise exception 'not allowed to see shop settings' using errcode = '42501';
  end if;
  return to_jsonb(v_row);
end;
$$;

revoke execute on function public.shop_admin_settings() from public, anon;
grant execute on function public.shop_admin_settings() to authenticated;

-- Edits the settings. Only the keys present in p change; the caller needs shop_orders: ALL at
-- the branch that sells online (and at the new one when it is switched).
create or replace function public.save_shop_settings(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cur    public.shop_settings;
  v_branch uuid;
  v_cod    numeric;
  v_weight int;
  v_flat   numeric;
  v_free   numeric;
begin
  select * into v_cur from public.shop_settings where id for update;
  if not found then
    raise exception 'shop settings are missing' using errcode = 'P0002';
  end if;
  if not public.can_shop_orders('ALL', v_cur.online_branch_id) then
    raise exception 'not allowed to edit shop settings' using errcode = '42501';
  end if;

  v_branch := coalesce(nullif(p ->> 'online_branch_id', '')::uuid, v_cur.online_branch_id);
  if v_branch is distinct from v_cur.online_branch_id then
    if not exists (select 1 from public.branches where id = v_branch and is_active) then
      raise exception 'branch is not available' using errcode = '22023', hint = 'invalid_branch';
    end if;
    if not public.can_shop_orders('ALL', v_branch) then
      raise exception 'not allowed to sell online from this branch' using errcode = '42501';
    end if;
  end if;

  v_cod    := coalesce(nullif(p ->> 'cod_max', '')::numeric, v_cur.cod_max);
  v_weight := coalesce(nullif(p ->> 'default_weight_g', '')::int, v_cur.default_weight_g);
  v_flat   := coalesce(nullif(p ->> 'flat_shipping_fee', '')::numeric, v_cur.flat_shipping_fee);
  if v_cod <= 0 or v_weight <= 0 or v_flat < 0 then
    raise exception 'invalid shipping or COD limits' using errcode = '22023', hint = 'invalid_limits';
  end if;
  -- An empty or zero threshold switches free shipping off.
  v_free := case
    when p ? 'free_ship_from' then nullif(nullif(p ->> 'free_ship_from', '')::numeric, 0)
    else v_cur.free_ship_from
  end;

  update public.shop_settings s
  set online_branch_id = v_branch,
      allow_cod = coalesce((p ->> 'allow_cod')::boolean, s.allow_cod),
      allow_pickup = coalesce((p ->> 'allow_pickup')::boolean, s.allow_pickup),
      cod_max = v_cod,
      default_weight_g = v_weight,
      flat_shipping_fee = v_flat,
      free_ship_from = v_free,
      ghn_from_province_id = case when p ? 'ghn_from_province_id'
        then nullif(p ->> 'ghn_from_province_id', '')::int else s.ghn_from_province_id end,
      ghn_from_district_id = case when p ? 'ghn_from_district_id'
        then nullif(p ->> 'ghn_from_district_id', '')::int else s.ghn_from_district_id end,
      ghn_from_ward_code = case when p ? 'ghn_from_ward_code'
        then nullif(btrim(p ->> 'ghn_from_ward_code'), '') else s.ghn_from_ward_code end,
      from_address_text = case when p ? 'from_address_text'
        then nullif(btrim(p ->> 'from_address_text'), '') else s.from_address_text end,
      pickup_address = case when p ? 'pickup_address'
        then nullif(btrim(p ->> 'pickup_address'), '') else s.pickup_address end,
      pickup_note = case when p ? 'pickup_note'
        then nullif(btrim(p ->> 'pickup_note'), '') else s.pickup_note end,
      updated_at = now()
  where s.id;

  return public.shop_admin_settings();
end;
$$;

revoke execute on function public.save_shop_settings(jsonb) from public, anon;
grant execute on function public.save_shop_settings(jsonb) to authenticated;

notify pgrst, 'reload schema';
