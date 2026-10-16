-- Before: a deceased pet could still be booked for spa (the staff screen hid it, the RPCs did not check), and
-- the customer site hid it completely.
-- After: save_appointment and book_my_appointment refuse a pet that is not active (hint pet_deceased for a
-- deceased pet, no_pet otherwise). my_pets also returns deceased pets, flagged with status and deceased_on,
-- with no next vaccine and no open booking; my_pet_health opens for a deceased pet and hides the next dose.

CREATE OR REPLACE FUNCTION "public"."save_appointment"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    if exists (select 1 from public.pets where id = v_pet and status <> 'active') then
      raise exception 'line %: the pet is not active', v_line_no using errcode = '22023',
        hint = case when (select status from public.pets where id = v_pet) = 'deceased' then 'pet_deceased' else 'no_pet' end;
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

CREATE OR REPLACE FUNCTION "public"."book_my_appointment"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid      uuid := auth.uid();
  v_cust     uuid := public.my_customer_id();
  v_rules    jsonb := public.spa_web_rules();
  v_branch   uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_start    timestamptz;
  v_local    timestamp;
  v_hours    record;
  v_items    jsonb := coalesce(p -> 'items', '[]'::jsonb);
  v_item     jsonb;
  v_quote    jsonb;
  v_quotes   jsonb[] := '{}';
  v_minutes  int := 0;
  v_cursor   timestamptz;
  v_end      timestamptz;
  v_line     int := 0;
  v_name     text;
  v_phone    text;
  v_id       uuid;
  v_code     text;
  v_pet      uuid;
  v_kind     text;
  v_obj      uuid;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 or jsonb_array_length(v_items) > 10 then
    raise exception 'pick at least one service' using errcode = '22023', hint = 'empty';
  end if;
  if v_branch is null or not exists (select 1 from public.branches where id = v_branch and is_active) then
    raise exception 'branch not found' using errcode = 'P0002', hint = 'bad_time';
  end if;
  begin
    v_start := (p ->> 'start_at')::timestamptz;
  exception when others then
    v_start := null;
  end;
  v_local := v_start at time zone c_tz;
  if v_start is null or extract(second from v_local) <> 0 or extract(minute from v_local)::int % 15 <> 0 then
    raise exception 'start on a quarter hour' using errcode = 'P0001', hint = 'bad_time';
  end if;
  if v_start < now() + make_interval(mins => (v_rules ->> 'min_lead_minutes')::int) then
    raise exception 'too soon' using errcode = 'P0001', hint = 'too_soon';
  end if;
  if v_local::date > (now() at time zone c_tz)::date + (v_rules ->> 'max_days')::int then
    raise exception 'too far ahead' using errcode = 'P0001', hint = 'too_far';
  end if;

  -- One customer, one lock per branch and day: the slot count below stays true until we commit.
  perform pg_advisory_xact_lock(hashtextextended(v_branch::text || ':' || v_local::date::text, 0));

  if (
    select count(*) from public.appointments a
    where a.customer_id = v_cust and a.source = 'web' and a.status = 'booked' and a.start_at > now()
  ) >= (v_rules ->> 'max_open')::int then
    raise exception 'too many upcoming web bookings' using errcode = 'P0001', hint = 'too_many';
  end if;

  -- Quote every ticket first (also checks the pets are mine and the offer fits the species).
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_pet := nullif(v_item ->> 'pet_id', '')::uuid;
    if not exists (
      select 1 from public.pet_owners where pet_id = v_pet and customer_id = v_cust and to_date is null
    ) then
      raise exception 'pet not found' using errcode = 'P0002', hint = 'no_pet';
    end if;
    if exists (select 1 from public.pets where id = v_pet and status <> 'active') then
      raise exception 'the pet is not active' using errcode = 'P0001',
        hint = case when (select status from public.pets where id = v_pet) = 'deceased' then 'pet_deceased' else 'no_pet' end;
    end if;
    v_quote := public.spa_ticket_quote(v_branch, v_pet, v_item ->> 'type', nullif(v_item ->> 'id', '')::uuid);
    v_quotes := v_quotes || v_quote;
    v_minutes := v_minutes + (v_quote ->> 'minutes')::int;
  end loop;
  v_minutes := ceil(v_minutes / 15.0)::int * 15;
  if v_minutes > (v_rules ->> 'max_block_minutes')::int then
    raise exception 'too long for one booking' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  select * into v_hours from public.spa_hours(v_branch, v_local::date);
  if v_hours.is_closed then
    raise exception 'the branch is closed that day' using errcode = 'P0001', hint = 'closed';
  end if;
  v_end := v_start + make_interval(mins => v_minutes);
  if v_local::time < v_hours.open_time
     or (v_end at time zone c_tz)::date <> v_local::date
     or (v_end at time zone c_tz)::time > v_hours.close_time then
    raise exception 'outside opening hours' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  if not public.spa_block_is_free(v_branch, v_start, v_minutes) then
    raise exception 'that time is full' using errcode = 'P0001', hint = 'slot_full';
  end if;

  -- A pet cannot be in two places at once.
  for v_item in select * from jsonb_array_elements(v_items) loop
    if exists (
      select 1 from public.appointment_items i
      where i.pet_id = (v_item ->> 'pet_id')::uuid and i.status <> 'cancelled'
        and i.start_at < v_end and i.end_at > v_start
    ) then
      raise exception 'the pet already has a visit at that time' using errcode = 'P0001', hint = 'pet_busy';
    end if;
  end loop;

  select full_name, phone into v_name, v_phone from public.customers where id = v_cust;
  insert into public.appointments (
    code, branch_id, customer_id, customer_name, customer_phone, start_at, end_at, source, note, created_by
  )
  values (
    public.next_doc_code(v_branch, 'LH'), v_branch, v_cust, v_name, v_phone,
    v_start, v_end, 'web', left(nullif(btrim(p ->> 'note'), ''), 500), v_uid
  )
  returning id, code into v_id, v_code;

  v_cursor := v_start;
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_line := v_line + 1;
    v_quote := v_quotes[v_line];
    v_kind := v_item ->> 'type';
    v_obj := nullif(v_item ->> 'id', '')::uuid;
    insert into public.appointment_items (
      appointment_id, branch_id, line_no, pet_id, item_type, service_id, combo_id, name,
      duration_minutes, start_at, end_at, est_price, weight_kg
    )
    values (
      v_id, v_branch, v_line, (v_item ->> 'pet_id')::uuid, v_kind,
      case when v_kind = 'service' then v_obj end,
      case when v_kind = 'combo' then v_obj end,
      v_quote ->> 'name', (v_quote ->> 'minutes')::int,
      v_cursor, v_cursor + make_interval(mins => (v_quote ->> 'minutes')::int),
      (v_quote ->> 'price')::numeric, (v_quote ->> 'weight_kg')::numeric
    );
    v_cursor := v_cursor + make_interval(mins => (v_quote ->> 'minutes')::int);
  end loop;

  update public.appointments set end_at = v_cursor where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."my_pets"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid  uuid := auth.uid();
  v_cust uuid := public.my_customer_id();
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(
             jsonb_build_object(
               'id', p.id,
               'name', p.name,
               'species_id', p.species_id,
               'species_name', s.name,
               'breed', p.breed,
               'photo_url', p.photo_url,
               'sex', p.sex,
               'neutered', p.neutered,
               'birth_date', p.birth_date,
               'status', p.status,
               'deceased_on', p.deceased_on,
               'allergies', p.allergies,
               'behavior_notes', p.behavior_notes,
               'weight_kg', (
                 select l.weight_kg from public.pet_weight_logs l
                 where l.pet_id = p.id order by l.measured_at desc limit 1
               ),
               'role', po.role,
               'can_edit', po.role = 'primary',
               'has_open_appointment', p.status = 'active' and exists (
                 select 1
                 from public.appointment_items ai
                 join public.appointments a on a.id = ai.appointment_id
                 where ai.pet_id = p.id and a.status in ('booked', 'checked_in', 'in_progress')
               ),
               'next_vaccine', (
                 select jsonb_build_object('name', t.name, 'due_on', l.next_due_on)
                 from public.vaccine_types t
                 join lateral (
                   select v.next_due_on from public.vaccinations v
                   where v.pet_id = p.id and v.vaccine_type_id = t.id and v.voided_at is null
                   order by v.given_on desc, v.created_at desc limit 1
                 ) l on true
                 where l.next_due_on is not null and p.status = 'active'
                 order by l.next_due_on, t.name
                 limit 1
               )
             )
             order by (p.status = 'active') desc, lower(p.name), p.created_at
           )
    from public.pet_owners po
    join public.pets p on p.id = po.pet_id
    join public.species s on s.id = p.species_id
    where po.customer_id = v_cust and po.to_date is null and p.status in ('active', 'deceased')
  ), '[]'::jsonb);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."my_pet_health"("p_pet" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid   uuid := (select auth.uid());
  v_cust  uuid := public.my_customer_id();
  v_today date := public.business_date();
  v_pet   public.pets;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  select p.* into v_pet
  from public.pets p
  join public.pet_owners po on po.pet_id = p.id
  where p.id = p_pet and po.customer_id = v_cust and po.to_date is null and p.status in ('active', 'deceased');
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  return jsonb_build_object(
    'pet_id', v_pet.id,
    'pet_name', v_pet.name,
    'status', v_pet.status,
    'deceased_on', v_pet.deceased_on,
    'pet_photo_url', v_pet.photo_url,
    'phone', (
      select b.phone from public.branches b where b.is_active and b.phone is not null
      order by b.created_at limit 1
    ),
    'vaccines', coalesce((
      select jsonb_agg(entry order by (entry ->> 'last_given_on') desc, entry ->> 'name')
      from (
        select jsonb_build_object(
          'vaccine_type_id', t.id,
          'name', t.name,
          'kind', t.kind,
          'last_given_on', last.given_on,
          'next_due_on', case when v_pet.status = 'active' then last.next_due_on end,
          'state', case
            when last.next_due_on is null or v_pet.status <> 'active' then 'ok'
            when last.next_due_on < v_today then 'overdue'
            when last.next_due_on <= v_today + 14 then 'due_soon'
            else 'ok' end,
          'doses', (
            select jsonb_agg(jsonb_build_object(
              'dose_no', d.dose_no, 'given_on', d.given_on,
              'is_external', d.is_external, 'external_place', d.external_place
            ) order by d.given_on desc, d.created_at desc)
            from public.vaccinations d
            where d.pet_id = v_pet.id and d.vaccine_type_id = t.id and d.voided_at is null
          )
        ) as entry
        from public.vaccine_types t
        join lateral (
          select v.given_on, v.next_due_on from public.vaccinations v
          where v.pet_id = v_pet.id and v.vaccine_type_id = t.id and v.voided_at is null
          order by v.given_on desc, v.created_at desc limit 1
        ) last on true
      ) e
    ), '[]'::jsonb),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', mv.id,
        'date', public.medical_local_date(mv.signed_at),
        'reason', mv.reason,
        'diagnoses', coalesce((
          select jsonb_agg(d.name order by d.sort_order, d.created_at)
          from public.medical_diagnoses d where d.visit_id = mv.id
        ), '[]'::jsonb),
        'owner_instructions', mv.owner_instructions,
        'recheck_on', mv.recheck_on,
        'branch_name', (select b.name from public.branches b where b.id = mv.branch_id),
        'take_home', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', i.name, 'dose', i.dose, 'frequency', i.frequency, 'days', i.days,
            'route', i.route, 'instructions', i.instructions
          ) order by i.created_at, i.id)
          from public.medical_visit_items i
          where i.visit_id = mv.id and i.take_home and i.kind in ('product', 'external')
        ), '[]'::jsonb)
      ) order by mv.signed_at desc)
      from public.medical_visits mv
      where mv.pet_id = v_pet.id and mv.signed_at is not null and mv.status in ('done', 'paid')
    ), '[]'::jsonb)
  );
end;
$$;
