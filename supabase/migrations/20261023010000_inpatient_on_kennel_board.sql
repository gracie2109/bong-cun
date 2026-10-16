-- Before: the kennel board showed a pet in a medical or isolation kennel like any hotel guest, and the
-- hotel check-out, extend and extras worked on an inpatient stay (skipping discharge_inpatient).
-- After: the board, timeline and stay lists say which stays are inpatient (kind, visit_id, visit_code)
-- and which kennels are medical or isolation (purpose); check-out, extend and extras refuse an
-- inpatient stay with hint inpatient_stay (discharge_inpatient is the only way out).


CREATE OR REPLACE FUNCTION "public"."boarding_board"("p_branch" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_date  date := coalesce(p_date, public.business_date());
  v_today date := public.business_date();
  v_kennels jsonb;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with pets as (
    -- Every active pet that is in a kennel on v_date or arrives on it.
    select sp.kennel_id,
           s.id as stay_id, s.code as stay_code, s.status as stay_status, sp.id as stay_pet_id,
           s.kind as stay_kind, s.visit_id, mv.code as visit_code,
           sp.pet_id, sp.pet_name, s.customer_name, s.planned_in_at, s.planned_out_at,
           -- In the kennel on v_date: checked in, started, and either still within its nights or (today and
           -- earlier) not yet collected. A later date does not count a pet that is planned to have left.
           (s.status = 'checked_in' and lower(sp.nights) <= v_date
            and (v_date < upper(sp.nights) or v_date <= v_today)) as in_kennel,
           (s.status = 'booked' and lower(sp.nights) = v_date) as arrives,
           (s.status = 'checked_in'
            and ((v_date = v_today and s.planned_out_at < now())
                 or (v_date < v_today and public.boarding_local_date(s.planned_out_at) < v_date))) as overdue,
           (s.status = 'checked_in' and public.boarding_local_date(s.planned_out_at) = v_date) as leaves,
           exists (
             select 1 from public.pets pt
             where pt.id = sp.pet_id
               and (nullif(btrim(pt.behavior_notes), '') is not null or nullif(btrim(pt.allergies), '') is not null)
           ) as has_notes
    from public.boarding_stay_pets sp
    join public.boarding_stays s on s.id = sp.stay_id
    left join public.medical_visits mv on mv.id = s.visit_id
    where sp.branch_id = p_branch and sp.status = 'active'
      and s.status in ('booked', 'checked_in')
  ), per_kennel as (
    select k.id, k.code, k.name, k.kennel_type_id, t.name as type_name, t.purpose, k.status, k.sort_order, t.sort_order as type_sort,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name,
             'customer_name', p.customer_name, 'planned_in_at', p.planned_in_at,
             'planned_out_at', p.planned_out_at, 'has_notes', p.has_notes, 'overdue', p.overdue,
             'kind', p.stay_kind, 'visit_id', p.visit_id, 'visit_code', p.visit_code
           ) order by p.pet_name) filter (where p.in_kennel), '[]'::jsonb) as in_pets,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name,
             'customer_name', p.customer_name, 'planned_in_at', p.planned_in_at,
             'planned_out_at', p.planned_out_at, 'has_notes', p.has_notes, 'overdue', false,
             'kind', p.stay_kind, 'visit_id', p.visit_id, 'visit_code', p.visit_code
           ) order by p.pet_name) filter (where p.arrives), '[]'::jsonb) as arriving_pets,
           coalesce(bool_or(p.in_kennel and p.overdue), false) as has_overdue,
           coalesce(bool_or(p.in_kennel and p.leaves and not p.overdue), false) as has_leaving,
           coalesce(bool_or(p.in_kennel), false) as has_pet,
           coalesce(bool_or(p.arrives), false) as has_arrival
    from public.kennels k
    join public.kennel_types t on t.id = k.kennel_type_id
    left join pets p on p.kennel_id = k.id
    where k.branch_id = p_branch and k.is_active
    group by k.id, t.id
  ), states as (
    select pk.*,
           case
             when pk.status = 'maintenance' then 'maintenance'
             when pk.has_overdue then 'overdue'
             when pk.has_leaving then 'departing'
             when pk.has_pet then 'occupied'
             when pk.status = 'cleaning' then 'cleaning'
             when pk.has_arrival then 'arriving'
             else 'free'
           end as state
    from per_kennel pk
  )
  select jsonb_agg(jsonb_build_object(
           'id', st.id, 'code', st.code, 'name', st.name,
           'kennel_type_id', st.kennel_type_id, 'kennel_type_name', st.type_name, 'purpose', st.purpose,
           'status', st.status, 'state', st.state,
           'conflict', (st.has_overdue and st.has_arrival),
           'pets', st.in_pets, 'arriving', st.arriving_pets
         ) order by st.type_sort, lower(st.type_name), st.sort_order, lower(st.code), st.id)
  into v_kennels
  from states st;

  return jsonb_build_object(
    'date', v_date,
    'kennels', coalesce(v_kennels, '[]'::jsonb),
    'counts', (
      select jsonb_build_object(
        'arriving', count(*) filter (where k ->> 'state' = 'arriving' or jsonb_array_length(k -> 'arriving') > 0),
        'departing', count(*) filter (where k ->> 'state' = 'departing'),
        'occupied', count(*) filter (where k ->> 'state' in ('occupied', 'departing', 'overdue')),
        'overdue', count(*) filter (where k ->> 'state' = 'overdue'),
        'free', count(*) filter (where k ->> 'state' = 'free'),
        'inpatient', count(*) filter (where exists (
          select 1 from jsonb_array_elements(k -> 'pets') as p(pet) where p.pet ->> 'kind' = 'inpatient'))
      )
      from jsonb_array_elements(coalesce(v_kennels, '[]'::jsonb)) as t(k)
    )
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."boarding_timeline"("p_branch" "uuid", "p_from" "date" DEFAULT NULL::"date", "p_days" integer DEFAULT 14) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_from date := coalesce(p_from, public.business_date());
  v_days int := least(greatest(coalesce(p_days, 14), 1), 31);
  v_win  daterange;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  v_win := daterange(v_from, v_from + v_days, '[)');

  return jsonb_build_object(
    'from', v_from,
    'days', v_days,
    'kennels', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', k.id, 'code', k.code, 'name', k.name,
        'kennel_type_id', k.kennel_type_id, 'kennel_type_name', t.name, 'status', k.status,
        'segments', coalesce((
          select jsonb_agg(jsonb_build_object(
            'stay_id', s.id, 'stay_code', s.code, 'stay_status', s.status, 'stay_pet_id', sp.id,
            'pet_name', sp.pet_name, 'customer_name', s.customer_name,
            'kind', s.kind, 'visit_code', mv.code,
            'from', lower(sp.nights), 'to', upper(sp.nights)
          ) order by lower(sp.nights), sp.line_no)
          from public.boarding_stay_pets sp
          join public.boarding_stays s on s.id = sp.stay_id
          left join public.medical_visits mv on mv.id = s.visit_id
          where sp.kennel_id = k.id and sp.status = 'active'
            and s.status in ('booked', 'checked_in', 'checked_out', 'paid')
            and sp.nights && v_win
        ), '[]'::jsonb)
      ) order by t.sort_order, lower(t.name), k.sort_order, lower(k.code), k.id)
      from public.kennels k
      join public.kennel_types t on t.id = k.kennel_type_id
      where k.branch_id = p_branch and k.is_active
    ), '[]'::jsonb)
  );
end;
$$;


CREATE OR REPLACE FUNCTION "public"."boarding_stay_json"("p_stay" "public"."boarding_stays") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', p_stay.id,
    'code', p_stay.code,
    'branch_id', p_stay.branch_id,
    'status', p_stay.status,
    'customer_id', p_stay.customer_id,
    'customer_name', p_stay.customer_name,
    'customer_phone', p_stay.customer_phone,
    'planned_in_at', p_stay.planned_in_at,
    'planned_out_at', p_stay.planned_out_at,
    'checked_in_at', p_stay.checked_in_at,
    'checked_out_at', p_stay.checked_out_at,
    'source', p_stay.source,
    'kind', p_stay.kind,
    'visit_id', p_stay.visit_id,
    'visit_code', (select mv.code from public.medical_visits mv where mv.id = p_stay.visit_id),
    'emergency_phone', p_stay.emergency_phone,
    'note', p_stay.note,
    'cancel_reason', p_stay.cancel_reason,
    'est_total',
      case
        when p_stay.status in ('checked_out', 'paid') then
          coalesce((select sum(c.amount) from public.boarding_charges c where c.stay_id = p_stay.id), 0)
        else
          coalesce((
            select sum(coalesce(sp.night_price, sp.est_night_price) * sp.charged_nights)
            from public.boarding_stay_pets sp where sp.stay_id = p_stay.id and sp.status = 'active'
          ), 0)
          + coalesce((select sum(c.amount) from public.boarding_charges c where c.stay_id = p_stay.id), 0)
      end,
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', sp.id,
        'line_no', sp.line_no,
        'pet_id', sp.pet_id,
        'pet_name', sp.pet_name,
        'status', sp.status,
        'kennel_type_id', sp.kennel_type_id,
        'kennel_type_name', t.name,
        'kennel_id', sp.kennel_id,
        'kennel_code', k.code,
        'nights_from', lower(sp.nights),
        'nights_to', upper(sp.nights),
        'charged_nights', sp.charged_nights,
        'is_extra_pet', sp.is_extra_pet,
        'est_night_price', sp.est_night_price,
        'night_price', sp.night_price,
        'weight_kg', sp.weight_kg,
        'vaccine_checked', sp.vaccine_checked,
        'vaccine_note', sp.vaccine_note,
        'belongings', sp.belongings,
        'belongings_returned', sp.belongings_returned,
        'feeding', sp.feeding,
        'medication', sp.medication,
        'has_notes', exists (
          select 1 from public.pets pt
          where pt.id = sp.pet_id
            and (nullif(btrim(pt.behavior_notes), '') is not null or nullif(btrim(pt.allergies), '') is not null)
        )
      ) order by sp.line_no)
      from public.boarding_stay_pets sp
      join public.kennel_types t on t.id = sp.kennel_type_id
      join public.kennels k on k.id = sp.kennel_id
      where sp.stay_id = p_stay.id
    ), '[]'::jsonb)
  );
$$;


CREATE OR REPLACE FUNCTION "public"."check_out_boarding"("p_id" "uuid", "p_returned" "uuid"[] DEFAULT '{}'::"uuid"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_stay public.boarding_stays;
  v_calc jsonb;
  v_item jsonb;
  v_total numeric;
begin
  select * into v_stay from public.boarding_stays where id = p_id for update;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.kind = 'inpatient' then
    raise exception 'an inpatient stay is managed on the inpatient screen' using errcode = 'P0001', hint = 'inpatient_stay';
  end if;
  if v_stay.status <> 'checked_in' then
    raise exception 'only a stay that is in can be checked out' using errcode = 'P0001', hint = 'not_editable';
  end if;

  v_calc := public.boarding_checkout_calc(v_stay, now());
  for v_item in select * from jsonb_array_elements(v_calc -> 'items') loop
    insert into public.boarding_charges (
      stay_id, stay_pet_id, branch_id, kind, name, qty, unit_price, amount, created_by
    )
    values (
      p_id, (v_item ->> 'stay_pet_id')::uuid, v_stay.branch_id, v_item ->> 'kind', v_item ->> 'name',
      (v_item ->> 'qty')::numeric, (v_item ->> 'unit_price')::numeric, (v_item ->> 'amount')::numeric,
      (select auth.uid())
    );
  end loop;

  for v_item in select * from jsonb_array_elements(v_calc -> 'pets') loop
    update public.boarding_stay_pets set
      nights = daterange(lower(nights), (v_item ->> 'nights_to')::date),
      charged_nights = (v_item ->> 'charged_nights')::numeric,
      belongings_returned = belongings_returned or id = any (coalesce(p_returned, '{}'))
    where id = (v_item ->> 'stay_pet_id')::uuid;
  end loop;

  update public.kennels set status = 'cleaning'
  where status = 'ready'
    and id in (select kennel_id from public.boarding_stay_pets where stay_id = p_id and status = 'active');

  update public.boarding_stays set status = 'checked_out', checked_out_at = now() where id = p_id;

  select coalesce(sum(amount), 0) into v_total from public.boarding_charges where stay_id = p_id;
  return jsonb_build_object('id', p_id, 'code', v_stay.code, 'total', v_total);
end;
$$;


CREATE OR REPLACE FUNCTION "public"."extend_boarding_stay"("p_id" "uuid", "p_planned_out_at" timestamp with time zone) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_stay       public.boarding_stays;
  v_sp         public.boarding_stay_pets;
  v_rules      record;
  v_out_date   date;
  v_from       date;
  v_range      daterange;
  v_charged    numeric;
  v_constraint text;
  v_code       text;
begin
  select * into v_stay from public.boarding_stays where id = p_id for update;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.kind = 'inpatient' then
    raise exception 'an inpatient stay is managed on the inpatient screen' using errcode = 'P0001', hint = 'inpatient_stay';
  end if;
  if v_stay.status <> 'checked_in' then
    raise exception 'only a stay that is in can be extended' using errcode = 'P0001', hint = 'not_editable';
  end if;
  v_out_date := public.boarding_local_date(p_planned_out_at);
  if p_planned_out_at is null or p_planned_out_at <= v_stay.checked_in_at or v_out_date < public.business_date() then
    raise exception 'bad departure' using errcode = '22023', hint = 'bad_dates';
  end if;
  select * into v_rules from public.boarding_rules(v_stay.branch_id);

  for v_sp in
    select * from public.boarding_stay_pets where stay_id = p_id and status = 'active' order by line_no
  loop
    v_from := lower(v_sp.nights);
    if v_out_date - v_from > v_rules.max_nights then
      raise exception 'too long' using errcode = '22023', hint = 'too_long';
    end if;
    if v_out_date > v_from then
      v_range := daterange(v_from, v_out_date);
      v_charged := v_out_date - v_from;
    else
      v_range := daterange(v_from, v_from + 1);
      v_charged := v_rules.day_stay_nights;
    end if;
    begin
      update public.boarding_stay_pets set nights = v_range, charged_nights = v_charged where id = v_sp.id;
    exception when exclusion_violation then
      get stacked diagnostics v_constraint = constraint_name;
      select code into v_code from public.kennels where id = v_sp.kennel_id;
      if v_constraint like '%pet_no_overlap' then
        raise exception 'the pet has another stay on these nights' using errcode = 'P0001', hint = 'pet_busy', detail = v_sp.pet_name;
      end if;
      raise exception 'kennel % is taken on these nights', v_code using errcode = 'P0001', hint = 'kennel_taken', detail = v_code;
    end;
  end loop;

  update public.boarding_stays set planned_out_at = p_planned_out_at where id = p_id;
end;
$$;


CREATE OR REPLACE FUNCTION "public"."add_boarding_extra"("p_stay_pet" "uuid", "p_service" "uuid", "p_qty" numeric DEFAULT 1) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_sp      public.boarding_stay_pets;
  v_status  text;
  v_service public.pet_services;
  v_species uuid;
  v_price   numeric;
  v_qty     numeric := coalesce(p_qty, 1);
  v_id      uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = p_stay_pet;
  if not found then
    raise exception 'pet of stay % not found', p_stay_pet using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('CREATE', v_sp.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select status into v_status from public.boarding_stays where id = v_sp.stay_id;
  if exists (select 1 from public.boarding_stays where id = v_sp.stay_id and kind = 'inpatient') then
    raise exception 'an inpatient stay is managed on the inpatient screen' using errcode = 'P0001', hint = 'inpatient_stay';
  end if;
  if v_status <> 'checked_in' or v_sp.status <> 'active' then
    raise exception 'the pet is not in the hotel' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_qty <= 0 or v_qty > 999 then
    raise exception 'bad quantity' using errcode = '22023', hint = 'bad_input';
  end if;

  select * into v_service from public.pet_services where id = p_service and is_active;
  if not found then
    raise exception 'service is not available' using errcode = 'P0002', hint = 'no_service';
  end if;
  select species_id into v_species from public.pets where id = v_sp.pet_id;
  if exists (select 1 from public.service_species where service_id = v_service.id)
     and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
    raise exception 'the service is not for this species' using errcode = '22023', hint = 'species_not_allowed', detail = v_sp.pet_name;
  end if;
  v_price := public.get_service_price(v_species, v_service.id, coalesce(v_sp.weight_kg, 0), v_sp.branch_id);
  if v_price is null then
    raise exception 'no price for this service' using errcode = 'P0001', hint = 'no_price', detail = v_service.name;
  end if;

  insert into public.boarding_charges (
    stay_id, stay_pet_id, branch_id, kind, service_id, name, qty, unit_price, amount, created_by
  )
  values (
    v_sp.stay_id, p_stay_pet, v_sp.branch_id, 'extra', v_service.id, v_service.name,
    v_qty, v_price, round(v_price * v_qty, 2), (select auth.uid())
  )
  returning id into v_id;
  return v_id;
end;
$$;
