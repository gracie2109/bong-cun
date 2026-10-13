-- Spa appointments, step 1 (3/4): book / edit and cancel an appointment. Runs after 20261013030100_spa_settings.sql.

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

