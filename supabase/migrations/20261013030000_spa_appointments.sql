-- Spa appointments, step 1 (docs/lich-hen-spa.md).
--
-- Before: bookings (contact form) and orders / order_items (services as text, no customer,
-- pet, staff or table) were the only "schedule". Nothing stopped two bookings at the same time.
-- After: an appointment belongs to a customer at a branch and has one ticket per pet and
-- service, each with its own staff member, spa table and time slot. The database refuses
-- overlapping tickets for the same staff member or the same table.
--
-- Runs after 20261007140000_product_variants.sql. Every write goes through the RPCs below;
-- the client only reads the tables (RLS: the "schedule" permission at the branch).
--
-- Permission "schedule" at the appointment's branch:
--   VIEW read, CREATE book, UPDATE edit, DELETE cancel, SETTING spa tables / hours / staff.

-- ------------------------------------------------------------ who does services
alter table public.staff_branches add column if not exists does_services boolean not null default false;

-- save_staff_branches used to delete and re-insert every row, which would reset does_services each
-- time the roles screen assigns someone. Branches that stay assigned are now updated in place.
-- Still SECURITY INVOKER: the superAdmin-only policies on staff_branches apply.
create or replace function public.save_staff_branches(p_user uuid, p jsonb) returns void
language plpgsql
set search_path = ''
as $$
begin
  delete from public.staff_branches
  where user_id = p_user
    and branch_id not in (
      select (e ->> 'branch_id')::uuid from jsonb_array_elements(coalesce(p, '[]'::jsonb)) as t(e)
    );
  insert into public.staff_branches (user_id, branch_id, role)
  select p_user, (e ->> 'branch_id')::uuid, e ->> 'role'
  from jsonb_array_elements(coalesce(p, '[]'::jsonb)) as t(e)
  on conflict (user_id, branch_id) do update set role = excluded.role;
end;
$$;

-- --------------------------------------------------------------------- tables
create table if not exists public.spa_resources (
  id         uuid primary key default gen_random_uuid(),
  branch_id  uuid not null references public.branches(id) on delete cascade,
  name       text not null check (length(btrim(name)) > 0),
  is_active  boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (branch_id, name)
);

-- Opening hours per weekday (ISO: 1 = Monday ... 7 = Sunday). No row = 08:00-20:00.
create table if not exists public.branch_hours (
  branch_id  uuid not null references public.branches(id) on delete cascade,
  weekday    smallint not null check (weekday between 1 and 7),
  open_time  time not null default '08:00',
  close_time time not null default '20:00',
  is_closed  boolean not null default false,
  primary key (branch_id, weekday),
  check (is_closed or close_time > open_time)
);

create table if not exists public.appointments (
  id             uuid primary key default gen_random_uuid(),
  code           text not null unique,
  branch_id      uuid not null references public.branches(id) on delete restrict,
  customer_id    uuid not null references public.customers(id) on delete restrict,
  -- Copied at booking time so lists read without joining customers.
  customer_name  text not null,
  customer_phone text not null,
  start_at       timestamptz not null,
  end_at         timestamptz not null,
  status         text not null default 'booked'
                 check (status in ('booked', 'checked_in', 'in_progress', 'done', 'paid', 'cancelled', 'no_show')),
  source         text not null default 'counter' check (source in ('counter', 'phone', 'legacy', 'web')),
  note           text,
  checked_in_at  timestamptz,
  cancelled_at   timestamptz,
  cancel_reason  text,
  created_by     uuid references auth.users(id) on delete set null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (end_at > start_at)
);
create index if not exists appointments_branch_start_idx on public.appointments (branch_id, start_at desc);
create index if not exists appointments_customer_idx on public.appointments (customer_id);

create table if not exists public.appointment_items (
  id               uuid primary key default gen_random_uuid(),
  appointment_id   uuid not null references public.appointments(id) on delete cascade,
  -- Same as the appointment's branch; kept here so RLS and the overlap checks need no join.
  branch_id        uuid not null references public.branches(id) on delete restrict,
  line_no          int not null,
  pet_id           uuid references public.pets(id) on delete restrict,
  item_type        text not null check (item_type in ('service', 'combo')),
  service_id       uuid references public.pet_services(id) on delete restrict,
  combo_id         uuid references public.pet_service_combos(id) on delete restrict,
  name             text not null,
  duration_minutes int not null check (duration_minutes > 0),
  staff_id         uuid references public.users(id) on delete restrict,
  resource_id      uuid references public.spa_resources(id) on delete restrict,
  start_at         timestamptz not null,
  end_at           timestamptz not null,
  status           text not null default 'waiting'
                   check (status in ('waiting', 'in_progress', 'done', 'cancelled')),
  est_price        numeric(14,2) check (est_price >= 0),
  weight_kg        numeric(6,2) check (weight_kg > 0),
  unit_price       numeric(14,2) check (unit_price >= 0),
  invoice_line_id  uuid references public.invoice_lines(id) on delete set null,
  note             text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (appointment_id, line_no),
  check (end_at > start_at),
  check ((item_type = 'service' and service_id is not null and combo_id is null)
      or (item_type = 'combo' and combo_id is not null and service_id is null)),
  -- One staff member / one table cannot have two tickets at the same time.
  constraint appointment_items_staff_no_overlap
    exclude using gist (staff_id with =, tstzrange(start_at, end_at, '[)') with &&)
    where (staff_id is not null and status <> 'cancelled'),
  constraint appointment_items_resource_no_overlap
    exclude using gist (resource_id with =, tstzrange(start_at, end_at, '[)') with &&)
    where (resource_id is not null and status <> 'cancelled')
);
create index if not exists appointment_items_appointment_idx on public.appointment_items (appointment_id);
create index if not exists appointment_items_branch_start_idx on public.appointment_items (branch_id, start_at);
create index if not exists appointment_items_staff_idx on public.appointment_items (staff_id) where staff_id is not null;
create index if not exists appointment_items_pet_idx on public.appointment_items (pet_id) where pet_id is not null;

do $$
declare t text;
begin
  foreach t in array array['spa_resources', 'appointments', 'appointment_items'] loop
    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------- permissions
create or replace function public.can_schedule(p_method text, p_branch uuid) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('schedule', p_method, p_branch));
$$;

revoke execute on function public.can_schedule(text, uuid) from public, anon;
grant execute on function public.can_schedule(text, uuid) to authenticated;

-- ------------------------------------------------------------------------ RLS
alter table public.spa_resources     enable row level security;
alter table public.branch_hours      enable row level security;
alter table public.appointments      enable row level security;
alter table public.appointment_items enable row level security;

drop policy if exists "schedule read" on public.spa_resources;
create policy "schedule read" on public.spa_resources for select to authenticated
  using ((select public.can_schedule('VIEW', branch_id)));

drop policy if exists "schedule read" on public.branch_hours;
create policy "schedule read" on public.branch_hours for select to authenticated
  using ((select public.can_schedule('VIEW', branch_id)));

-- A staff member sees the tickets assigned to them even without "schedule: VIEW".
drop policy if exists "schedule read" on public.appointment_items;
create policy "schedule read" on public.appointment_items for select to authenticated
  using (staff_id = (select auth.uid()) or (select public.can_schedule('VIEW', branch_id)));

drop policy if exists "schedule read" on public.appointments;
create policy "schedule read" on public.appointments for select to authenticated
  using (
    (select public.can_schedule('VIEW', branch_id))
    or exists (
      select 1 from public.appointment_items i
      where i.appointment_id = appointments.id and i.staff_id = (select auth.uid())
    )
  );

revoke insert, update, delete on public.spa_resources, public.branch_hours,
  public.appointments, public.appointment_items from anon, authenticated;
revoke all on public.spa_resources, public.branch_hours, public.appointments, public.appointment_items from anon;

-- ------------------------------------------------------------ opening hours
-- Hours of one day at a branch (internal; the RPCs below use it).
create or replace function public.spa_hours(p_branch uuid, p_date date)
returns table (open_time time, close_time time, is_closed boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(h.open_time, time '08:00'),
         coalesce(h.close_time, time '20:00'),
         coalesce(h.is_closed, false)
  from (select 1) as one
  left join public.branch_hours h
    on h.branch_id = p_branch and h.weekday = extract(isodow from p_date)::int;
$$;

revoke execute on function public.spa_hours(uuid, date) from public, anon, authenticated;

-- Hours of the week for the settings screen: always 7 rows, defaults filled in.
create or replace function public.spa_week_hours(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_agg(jsonb_build_object(
      'weekday', d.weekday,
      'open_time', to_char(coalesce(h.open_time, time '08:00'), 'HH24:MI'),
      'close_time', to_char(coalesce(h.close_time, time '20:00'), 'HH24:MI'),
      'is_closed', coalesce(h.is_closed, false)
    ) order by d.weekday)
    from generate_series(1, 7) as d(weekday)
    left join public.branch_hours h on h.branch_id = p_branch and h.weekday = d.weekday
  );
end;
$$;

revoke execute on function public.spa_week_hours(uuid) from public, anon;
grant execute on function public.spa_week_hours(uuid) to authenticated;

-- p: [{ weekday, open_time: 'HH:MM', close_time: 'HH:MM', is_closed }]
create or replace function public.save_branch_hours(p_branch uuid, p jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb;
  v_closed boolean;
  v_open time;
  v_close time;
begin
  if not public.can_schedule('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  for v_row in select * from jsonb_array_elements(coalesce(p, '[]'::jsonb)) loop
    v_closed := coalesce((v_row ->> 'is_closed')::boolean, false);
    v_open := coalesce(nullif(v_row ->> 'open_time', '')::time, time '08:00');
    v_close := coalesce(nullif(v_row ->> 'close_time', '')::time, time '20:00');
    if not v_closed and v_close <= v_open then
      raise exception 'closing time must be after opening time' using errcode = '22023', hint = 'bad_hours';
    end if;
    insert into public.branch_hours (branch_id, weekday, open_time, close_time, is_closed)
    values (p_branch, (v_row ->> 'weekday')::smallint, v_open, v_close, v_closed)
    on conflict (branch_id, weekday) do update
      set open_time = excluded.open_time, close_time = excluded.close_time, is_closed = excluded.is_closed;
  end loop;
end;
$$;

revoke execute on function public.save_branch_hours(uuid, jsonb) from public, anon;
grant execute on function public.save_branch_hours(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------------ spa tables
-- p: { branch_id, name, is_active?, sort_order? }. Tables are archived (is_active), not deleted.
create or replace function public.save_spa_resource(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_branch uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_id uuid;
begin
  if p_id is not null then
    select branch_id into v_branch from public.spa_resources where id = p_id;
    if v_branch is null then
      raise exception 'spa table % not found', p_id using errcode = 'P0002';
    end if;
  end if;
  if v_branch is null or not public.can_schedule('SETTING', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if p_id is null then
    insert into public.spa_resources (branch_id, name, is_active, sort_order)
    values (
      v_branch,
      btrim(p ->> 'name'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce((p ->> 'sort_order')::int, 0)
    )
    returning id into v_id;
  else
    update public.spa_resources set
      name = coalesce(nullif(btrim(p ->> 'name'), ''), name),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce((p ->> 'sort_order')::int, sort_order)
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;

revoke execute on function public.save_spa_resource(jsonb, uuid) from public, anon;
grant execute on function public.save_spa_resource(jsonb, uuid) to authenticated;

-- ---------------------------------------------------------------- spa staff
-- Staff at a branch with whether they do services. Anyone who may view the schedule can read it
-- (the booking dialog picks from the ones with does_services).
create or replace function public.list_branch_staff(p_branch uuid)
returns table (user_id uuid, name text, role text, does_services boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
    select sb.user_id, public.staff_display_name(sb.user_id), sb.role, sb.does_services
    from public.staff_branches sb
    where sb.branch_id = p_branch
    order by 2;
end;
$$;

revoke execute on function public.list_branch_staff(uuid) from public, anon;
grant execute on function public.list_branch_staff(uuid) to authenticated;

create or replace function public.set_staff_does_services(p_user uuid, p_branch uuid, p_value boolean) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.can_schedule('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.staff_branches set does_services = p_value
  where user_id = p_user and branch_id = p_branch;
  if not found then
    raise exception 'staff member is not assigned to this branch' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.set_staff_does_services(uuid, uuid, boolean) from public, anon;
grant execute on function public.set_staff_does_services(uuid, uuid, boolean) to authenticated;

-- ------------------------------------------------------------ book / edit
-- Creates (p_id null) or replaces a booked appointment, with its tickets, in one transaction.
-- p: {
--   branch_id, note?, source?: 'counter' | 'phone',
--   customer_id? | customer?: { id } | { full_name, phone, email? },
--   items: [{ pet_id, type: 'service' | 'combo', id, start_at, staff_id?, resource_id?, weight_kg? }]
-- }
-- Names, durations and the estimated price come from the catalog, never from the client.
-- A ticket must start on a quarter hour inside the branch's opening hours, not in the past.
-- Returns { id, code }. Hints on failure: slot_staff, slot_resource (time taken), closed,
-- outside_hours, bad_time, in_past, not_editable.
create or replace function public.save_appointment(p jsonb, p_id uuid default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_default_minutes constant int := 30;
  c_late_grace constant interval := interval '15 minutes';
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid        uuid := (select auth.uid());
  v_branch     uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer   uuid := coalesce(nullif(p ->> 'customer_id', '')::uuid, nullif(p #>> '{customer,id}', '')::uuid);
  v_source     text := coalesce(nullif(p ->> 'source', ''), 'counter');
  v_appt       public.appointments;
  v_id         uuid;
  v_code       text;
  v_item       jsonb;
  v_line_no    int := 0;
  v_kind       text;
  v_item_id    uuid;
  v_pet        uuid;
  v_species    uuid;
  v_staff      uuid;
  v_resource   uuid;
  v_start      timestamptz;
  v_end        timestamptz;
  v_local      timestamp;
  v_name       text;
  v_minutes    int;
  v_weight     numeric;
  v_price      numeric;
  v_service    public.pet_services;
  v_combo      public.pet_service_combos;
  v_hours      record;
  v_constraint text;
  v_min_start  timestamptz;
  v_max_end    timestamptz;
  v_cust_name  text;
  v_cust_phone text;
begin
  if p_id is not null then
    select * into v_appt from public.appointments where id = p_id for update;
    if not found then
      raise exception 'appointment % not found', p_id using errcode = 'P0002';
    end if;
    v_branch := v_appt.branch_id;
    if v_appt.status <> 'booked' then
      raise exception 'only a booked appointment can be edited' using errcode = 'P0001', hint = 'not_editable';
    end if;
    if not public.can_schedule('UPDATE', v_branch) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    -- The customer of an appointment does not change; to change it, cancel and book again.
    v_customer := v_appt.customer_id;
  else
    if v_uid is null or v_branch is null or not public.can_schedule('CREATE', v_branch) then
      raise exception 'not allowed to book at this branch' using errcode = '42501';
    end if;
  end if;

  if v_source not in ('counter', 'phone') then
    v_source := 'counter';
  end if;
  if jsonb_array_length(coalesce(p -> 'items', '[]'::jsonb)) = 0 then
    raise exception 'an appointment needs at least one ticket' using errcode = '22023';
  end if;

  -- The customer: an existing one, or a new walk-in matched by phone (as create_invoice does).
  if v_customer is null and nullif(btrim(p #>> '{customer,phone}'), '') is not null then
    insert into public.customers (full_name, phone, email, created_by)
    values (
      btrim(p #>> '{customer,full_name}'),
      btrim(p #>> '{customer,phone}'),
      nullif(btrim(p #>> '{customer,email}'), ''),
      v_uid
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  end if;
  select full_name, phone into v_cust_name, v_cust_phone from public.customers where id = v_customer;
  if v_customer is null or v_cust_name is null then
    raise exception 'pick a customer' using errcode = 'P0002', hint = 'no_customer';
  end if;

  if p_id is null then
    v_code := public.next_doc_code(v_branch, 'LH');
    insert into public.appointments (
      code, branch_id, customer_id, customer_name, customer_phone,
      start_at, end_at, source, note, created_by
    )
    values (
      v_code, v_branch, v_customer, v_cust_name, v_cust_phone,
      now(), now() + interval '1 minute', v_source, nullif(btrim(p ->> 'note'), ''), v_uid
    )
    returning id into v_id;
  else
    v_id := p_id;
    v_code := v_appt.code;
    -- Free the old slots first so the new tickets do not clash with themselves.
    delete from public.appointment_items where appointment_id = v_id;
  end if;

  for v_item in select * from jsonb_array_elements(p -> 'items') loop
    v_line_no := v_line_no + 1;
    v_kind := v_item ->> 'type';
    v_item_id := nullif(v_item ->> 'id', '')::uuid;
    v_pet := nullif(v_item ->> 'pet_id', '')::uuid;
    v_staff := nullif(v_item ->> 'staff_id', '')::uuid;
    v_resource := nullif(v_item ->> 'resource_id', '')::uuid;
    v_start := nullif(v_item ->> 'start_at', '')::timestamptz;
    v_weight := nullif(v_item ->> 'weight_kg', '')::numeric;
    v_price := null;

    if v_start is null then
      raise exception 'line %: pick a time', v_line_no using errcode = '22023', hint = 'bad_time';
    end if;
    if v_pet is null then
      raise exception 'line %: pick the pet', v_line_no using errcode = '22023', hint = 'no_pet';
    end if;
    if not exists (
      select 1 from public.pet_owners
      where pet_id = v_pet and customer_id = v_customer and to_date is null
    ) then
      raise exception 'line %: the pet does not belong to this customer', v_line_no using errcode = '22023';
    end if;
    select species_id into v_species from public.pets where id = v_pet;

    if v_kind = 'combo' then
      select * into v_combo from public.pet_service_combos
      where id = v_item_id and status = 1 and is_active;
      if not found then
        raise exception 'line %: combo is not available', v_line_no using errcode = 'P0002';
      end if;
      if exists (select 1 from public.combo_species where combo_id = v_combo.id)
         and not exists (select 1 from public.combo_species where combo_id = v_combo.id and species_id = v_species) then
        raise exception 'line %: the combo is not for this species', v_line_no using errcode = '22023';
      end if;
      v_name := v_combo.name;
      v_minutes := coalesce(nullif(v_combo.duration_minutes, 0), c_default_minutes);
      v_price := v_combo.price;
    elsif v_kind = 'service' then
      select * into v_service from public.pet_services where id = v_item_id and is_active;
      if not found then
        raise exception 'line %: service is not available', v_line_no using errcode = 'P0002';
      end if;
      if exists (select 1 from public.service_species where service_id = v_service.id)
         and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
        raise exception 'line %: the service is not for this species', v_line_no using errcode = '22023';
      end if;
      v_name := v_service.name;
      v_minutes := coalesce(nullif(v_service.duration_minutes, 0), c_default_minutes);
      if v_service.type = 'by_weight' then
        -- Estimated from the weight typed, else the pet's latest weight; the real price is set at check-in.
        v_weight := coalesce(
          v_weight,
          (select weight_kg from public.pet_weight_logs where pet_id = v_pet order by measured_at desc limit 1)
        );
        if v_weight is not null then
          v_price := public.get_service_price(v_species, v_service.id, v_weight, v_branch);
        end if;
      else
        v_price := v_service.general_price;
      end if;
    else
      raise exception 'line %: unknown ticket type', v_line_no using errcode = '22023';
    end if;

    v_end := v_start + make_interval(mins => v_minutes);

    -- Time rules: quarter hours, not in the past, inside opening hours on one day.
    v_local := v_start at time zone c_tz;
    if extract(second from v_local) <> 0 or extract(minute from v_local)::int % 15 <> 0 then
      raise exception 'line %: start on a quarter hour', v_line_no using errcode = 'P0001', hint = 'bad_time';
    end if;
    if v_start < now() - c_late_grace then
      raise exception 'line %: the time is in the past', v_line_no using errcode = 'P0001', hint = 'in_past';
    end if;
    select * into v_hours from public.spa_hours(v_branch, v_local::date);
    if v_hours.is_closed then
      raise exception 'line %: the branch is closed that day', v_line_no using errcode = 'P0001', hint = 'closed';
    end if;
    if v_local::time < v_hours.open_time
       or (v_end at time zone c_tz)::date <> v_local::date
       or (v_end at time zone c_tz)::time > v_hours.close_time then
      raise exception 'line %: outside opening hours', v_line_no using errcode = 'P0001', hint = 'outside_hours';
    end if;

    if v_staff is not null and not exists (
      select 1 from public.staff_branches
      where user_id = v_staff and branch_id = v_branch and does_services
    ) then
      raise exception 'line %: that staff member does not do services at this branch', v_line_no using errcode = '22023';
    end if;
    if v_resource is not null and not exists (
      select 1 from public.spa_resources where id = v_resource and branch_id = v_branch and is_active
    ) then
      raise exception 'line %: that spa table is not available', v_line_no using errcode = '22023';
    end if;

    begin
      insert into public.appointment_items (
        appointment_id, branch_id, line_no, pet_id, item_type, service_id, combo_id, name,
        duration_minutes, staff_id, resource_id, start_at, end_at, est_price, weight_kg
      )
      values (
        v_id, v_branch, v_line_no, v_pet, v_kind,
        case when v_kind = 'service' then v_item_id end,
        case when v_kind = 'combo' then v_item_id end,
        v_name, v_minutes, v_staff, v_resource, v_start, v_end, v_price, v_weight
      );
    exception when exclusion_violation then
      get stacked diagnostics v_constraint = constraint_name;
      raise exception 'line %: already booked at that time', v_line_no
        using errcode = 'P0001',
              hint = case when v_constraint like '%staff%' then 'slot_staff' else 'slot_resource' end,
              detail = v_name;
    end;
  end loop;

  select min(start_at), max(end_at) into v_min_start, v_max_end
  from public.appointment_items where appointment_id = v_id;
  update public.appointments set
    start_at = v_min_start,
    end_at = v_max_end,
    source = v_source,
    note = nullif(btrim(p ->> 'note'), '')
  where id = v_id;

  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

revoke execute on function public.save_appointment(jsonb, uuid) from public, anon;
grant execute on function public.save_appointment(jsonb, uuid) to authenticated;

-- ------------------------------------------------------------------- cancel
-- Only while no ticket has started. Frees the staff and table slots.
create or replace function public.cancel_appointment(p_id uuid, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt public.appointments;
begin
  select * into v_appt from public.appointments where id = p_id for update;
  if not found then
    raise exception 'appointment % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_schedule('DELETE', v_appt.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_appt.status not in ('booked', 'checked_in') then
    raise exception 'this appointment can no longer be cancelled' using errcode = 'P0001', hint = 'not_editable';
  end if;

  update public.appointment_items set status = 'cancelled' where appointment_id = p_id;
  update public.appointments set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = nullif(btrim(p_reason), '')
  where id = p_id;
end;
$$;

revoke execute on function public.cancel_appointment(uuid, text) from public, anon;
grant execute on function public.cancel_appointment(uuid, text) to authenticated;

-- ---------------------------------------------------------------------- list
-- Appointments of a branch between two dates (business time, inclusive), newest first.
-- p_search matches the code, customer name or phone, or a pet name. Returns { rows, total }.
create or replace function public.list_appointments(
  p_branch uuid,
  p_from date default null,
  p_to date default null,
  p_status text default null,
  p_search text default null,
  p_page int default 1,
  p_page_size int default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_digits text := regexp_replace(coalesce(p_search, ''), '\D', '', 'g');
  v_from   timestamptz := case when p_from is null then null else (p_from::timestamp at time zone c_tz) end;
  v_to     timestamptz := case when p_to is null then null else ((p_to + 1)::timestamp at time zone c_tz) end;
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select a.*
    from public.appointments a
    where a.branch_id = p_branch
      and (v_from is null or a.start_at >= v_from)
      and (v_to is null or a.start_at < v_to)
      and (nullif(p_status, '') is null or a.status = p_status)
      and (
        v_term = ''
        or lower(a.code) like v_like
        or lower(public.immutable_unaccent(a.customer_name)) like v_like
        or (length(v_digits) >= 3 and regexp_replace(a.customer_phone, '\D', '', 'g') like v_digits || '%')
        or exists (
          select 1 from public.appointment_items i
          join public.pets pt on pt.id = i.pet_id
          where i.appointment_id = a.id and lower(public.immutable_unaccent(pt.name)) like v_like
        )
      )
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'code', a.code,
        'status', a.status,
        'start_at', a.start_at,
        'end_at', a.end_at,
        'customer_id', a.customer_id,
        'customer_name', a.customer_name,
        'customer_phone', a.customer_phone,
        'note', a.note,
        'checked_in_at', a.checked_in_at,
        'items', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', i.id,
            'name', i.name,
            'item_type', i.item_type,
            'service_id', i.service_id,
            'combo_id', i.combo_id,
            'status', i.status,
            'pet_id', i.pet_id,
            'pet_name', pt.name,
            'staff_id', i.staff_id,
            'staff_name', case when i.staff_id is null then null else public.staff_display_name(i.staff_id) end,
            'resource_id', i.resource_id,
            'resource_name', rs.name,
            'start_at', i.start_at,
            'end_at', i.end_at,
            'est_price', i.est_price,
            'weight_kg', i.weight_kg,
            'unit_price', i.unit_price
          ) order by i.line_no), '[]'::jsonb)
          from public.appointment_items i
          left join public.pets pt on pt.id = i.pet_id
          left join public.spa_resources rs on rs.id = i.resource_id
          where i.appointment_id = a.id
        )
      ) order by a.start_at desc, a.code desc)
      from (select * from f order by start_at desc, code desc limit v_size offset v_offset) a
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$$;

revoke execute on function public.list_appointments(uuid, date, date, text, text, int, int) from public, anon;
grant execute on function public.list_appointments(uuid, date, date, text, text, int, int) to authenticated;

-- ------------------------------------------------------------------ day board
-- Everything the day view needs in one call: the day's opening hours, the staff and tables that
-- can be booked, and the tickets that are not cancelled.
create or replace function public.spa_day_board(p_branch uuid, p_date date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_hours record;
  v_from timestamptz := (p_date::timestamp at time zone c_tz);
  v_to   timestamptz := ((p_date + 1)::timestamp at time zone c_tz);
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_hours from public.spa_hours(p_branch, p_date);

  return jsonb_build_object(
    'date', p_date,
    'is_closed', v_hours.is_closed,
    'open_time', to_char(v_hours.open_time, 'HH24:MI'),
    'close_time', to_char(v_hours.close_time, 'HH24:MI'),
    'staff', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', sb.user_id, 'name', public.staff_display_name(sb.user_id)
      ) order by public.staff_display_name(sb.user_id)), '[]'::jsonb)
      from public.staff_branches sb
      where sb.branch_id = p_branch and sb.does_services
    ),
    'resources', (
      select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name) order by r.sort_order, r.name), '[]'::jsonb)
      from public.spa_resources r
      where r.branch_id = p_branch and r.is_active
    ),
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', i.id,
        'appointment_id', a.id,
        'code', a.code,
        'appointment_status', a.status,
        'status', i.status,
        'name', i.name,
        'start_at', i.start_at,
        'end_at', i.end_at,
        'staff_id', i.staff_id,
        'resource_id', i.resource_id,
        'pet_name', pt.name,
        'customer_name', a.customer_name
      ) order by i.start_at, i.line_no), '[]'::jsonb)
      from public.appointment_items i
      join public.appointments a on a.id = i.appointment_id
      left join public.pets pt on pt.id = i.pet_id
      where i.branch_id = p_branch
        and i.status <> 'cancelled'
        and i.start_at >= v_from and i.start_at < v_to
    )
  );
end;
$$;

revoke execute on function public.spa_day_board(uuid, date) from public, anon;
grant execute on function public.spa_day_board(uuid, date) to authenticated;

notify pgrst, 'reload schema';
