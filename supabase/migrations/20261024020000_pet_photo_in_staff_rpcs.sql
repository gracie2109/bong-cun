-- Pet photo in the staff screens' data (docs/anh-thu-cung.md, step 4).
--
--  Adds a pet_photo_url key next to pet_name in the JSON that boarding, inpatient, spa, medical and
--  POS screens read, so each can show the pet's picture. Every function below is the current
--  definition with only that key added. list_boarding_stays and list_medical_visits are unchanged:
--  they build their rows with boarding_stay_json and medical_visit_json.
--  Safe to run more than once.

create or replace function "public"."boarding_stay_json"("p_stay" "public"."boarding_stays") RETURNS "jsonb"
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
        'pet_photo_url', (select pt.photo_url from public.pets pt where pt.id = sp.pet_id),
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

create or replace function "public"."boarding_board"("p_branch" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
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
           ) as has_notes,
           (select pt.photo_url from public.pets pt where pt.id = sp.pet_id) as pet_photo_url
    from public.boarding_stay_pets sp
    join public.boarding_stays s on s.id = sp.stay_id
    left join public.medical_visits mv on mv.id = s.visit_id
    where sp.branch_id = p_branch and sp.status = 'active'
      and s.status in ('booked', 'checked_in')
  ), per_kennel as (
    select k.id, k.code, k.name, k.kennel_type_id, t.name as type_name, t.purpose, k.status, k.sort_order, t.sort_order as type_sort,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name, 'pet_photo_url', p.pet_photo_url,
             'customer_name', p.customer_name, 'planned_in_at', p.planned_in_at,
             'planned_out_at', p.planned_out_at, 'has_notes', p.has_notes, 'overdue', p.overdue,
             'kind', p.stay_kind, 'visit_id', p.visit_id, 'visit_code', p.visit_code
           ) order by p.pet_name) filter (where p.in_kennel), '[]'::jsonb) as in_pets,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name, 'pet_photo_url', p.pet_photo_url,
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

create or replace function "public"."inpatient_ward"("p_branch" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_date date := coalesce(p_date, public.business_date());
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_build_object('date', v_date, 'rows', coalesce((
    select jsonb_agg(jsonb_build_object(
      'stay_id', s.id,
      'stay_code', s.code,
      'stay_pet_id', sp.id,
      'visit_id', v.id,
      'visit_code', v.code,
      'pet_id', sp.pet_id,
      'pet_name', sp.pet_name,
      'pet_photo_url', pt.photo_url,
      'customer_name', s.customer_name,
      'customer_phone', s.customer_phone,
      'kennel_code', k.code,
      'purpose', t.purpose,
      'since', s.checked_in_at,
      'planned_out_at', s.planned_out_at,
      'overdue', s.planned_out_at < now(),
      'allergies', nullif(btrim(pt.allergies), ''),
      'orders', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', o.id, 'kind', o.kind, 'name', o.name, 'dose', o.dose, 'qty_per_dose', o.qty_per_dose,
          'times', o.times, 'start_on', o.start_on, 'end_on', o.end_on, 'note', o.note,
          'stopped', o.stopped_at is not null
        ) order by o.created_at)
        from public.inpatient_orders o where o.stay_pet_id = sp.id and o.stopped_at is null
      ), '[]'::jsonb),
      'doses', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', d.id, 'order_id', d.order_id, 'due_at', d.due_at, 'given_at', d.given_at,
          'given_by_name', d.given_by_name, 'skipped_reason', d.skipped_reason
        ) order by d.due_at)
        from public.inpatient_doses d
        join public.inpatient_orders o on o.id = d.order_id
        where o.stay_pet_id = sp.id and public.medical_local_date(d.due_at) = v_date
      ), '[]'::jsonb),
      'last_vitals', (
        select jsonb_build_object('content', l.content, 'logged_at', l.logged_at)
        from public.boarding_care_logs l
        where l.stay_pet_id = sp.id and l.kind = 'vitals'
        order by l.logged_at desc limit 1
      )
    ) order by k.code)
    from public.boarding_stays s
    join public.boarding_stay_pets sp on sp.stay_id = s.id and sp.status = 'active'
    join public.kennels k on k.id = sp.kennel_id
    join public.kennel_types t on t.id = k.kennel_type_id
    join public.medical_visits v on v.id = s.visit_id
    join public.pets pt on pt.id = sp.pet_id
    where s.branch_id = p_branch and s.kind = 'inpatient' and s.status = 'checked_in'
  ), '[]'::jsonb));
end;
$$;

create or replace function "public"."spa_day_board"("p_branch" "uuid", "p_date" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
        'source', a.source,
        'appointment_status', a.status,
        'status', i.status,
        'name', i.name,
        'start_at', i.start_at,
        'end_at', i.end_at,
        'staff_id', i.staff_id,
        'resource_id', i.resource_id,
        'pet_name', pt.name,
        'pet_photo_url', pt.photo_url,
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

create or replace function "public"."list_appointments"("p_branch" "uuid", "p_from" "date" DEFAULT NULL::"date", "p_to" "date" DEFAULT NULL::"date", "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
        'source', a.source,
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
            'pet_photo_url', pt.photo_url,
            'staff_id', i.staff_id,
            'staff_name', case when i.staff_id is null then null else public.staff_display_name(i.staff_id) end,
            'resource_id', i.resource_id,
            'resource_name', rs.name,
            'start_at', i.start_at,
            'end_at', i.end_at,
            'est_price', i.est_price,
            'weight_kg', i.weight_kg,
            'unit_price', i.unit_price,
            'billed', i.invoice_line_id is not null
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

create or replace function "public"."medical_visit_json"("v" "public"."medical_visits") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', v.id,
    'code', v.code,
    'branch_id', v.branch_id,
    'status', v.status,
    'priority', v.priority,
    'queue_date', v.queue_date,
    'queue_no', v.queue_no,
    'scheduled_at', v.scheduled_at,
    'checked_in_at', v.checked_in_at,
    'started_at', v.started_at,
    'signed_at', v.signed_at,
    'created_at', v.created_at,
    'pet_id', v.pet_id,
    'pet_name', v.pet_name,
    'pet_photo_url', (select p.photo_url from public.pets p where p.id = v.pet_id),
    'species_name', (select s.name from public.pets p join public.species s on s.id = p.species_id where p.id = v.pet_id),
    'customer_id', v.customer_id,
    'customer_name', v.customer_name,
    'customer_phone', v.customer_phone,
    'reason', v.reason,
    'vet_id', v.vet_id,
    'vet_name', v.vet_name,
    'weight_kg', v.weight_kg,
    'outcome', v.outcome,
    'recheck_on', v.recheck_on,
    'follow_up_of', v.follow_up_of,
    'diagnoses_text', (
      select string_agg(d.name, ', ' order by d.sort_order) from public.medical_diagnoses d where d.visit_id = v.id
    ),
    -- What the visit will cost: the service and product lines (external medicine is free).
    'est_total', coalesce((
      select sum(i.amount) from public.medical_visit_items i where i.visit_id = v.id and i.kind in ('service', 'product')
    ), 0)
  );
$$;

create or replace function "public"."billable_appointment_items"("p_branch" "uuid", "p_customer" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', i.id,
      'code', a.code,
      'name', i.name,
      'item_type', i.item_type,
      'pet_id', i.pet_id,
      'pet_name', pt.name,
      'pet_photo_url', pt.photo_url,
      'unit_price', i.unit_price
    ) order by a.start_at, i.line_no)
    from public.appointment_items i
    join public.appointments a on a.id = i.appointment_id
    left join public.pets pt on pt.id = i.pet_id
    where a.branch_id = p_branch
      and a.customer_id = p_customer
      and i.status = 'done'
      and i.invoice_line_id is null
      and i.unit_price is not null
  ), '[]'::jsonb);
end;
$$;

create or replace function "public"."billable_boarding_charges"("p_branch" "uuid", "p_customer" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'stay_id', s.id,
      'code', s.code,
      'total', c.total,
      'charges', c.charges
    ) order by s.checked_out_at, s.code)
    from public.boarding_stays s
    cross join lateral (
      select sum(bc.amount) as total,
             jsonb_agg(jsonb_build_object(
               'id', bc.id,
               'kind', bc.kind,
               'name', bc.name,
               'qty', bc.qty,
               'unit_price', bc.unit_price,
               'amount', bc.amount,
               'pet_name', (
                 select p.name
                 from public.boarding_stay_pets sp
                 join public.pets p on p.id = sp.pet_id
                 where sp.id = bc.stay_pet_id
               ),
               'pet_photo_url', (
                 select p.photo_url
                 from public.boarding_stay_pets sp
                 join public.pets p on p.id = sp.pet_id
                 where sp.id = bc.stay_pet_id
               )
             ) order by bc.created_at, bc.id) as charges
      from public.boarding_charges bc
      where bc.stay_id = s.id and bc.invoice_line_id is null
    ) c
    where s.branch_id = p_branch
      and s.customer_id = p_customer
      and s.status = 'checked_out'
      and c.charges is not null
  ), '[]'::jsonb);
end;
$$;

create or replace function "public"."billable_medical_items"("p_branch" "uuid", "p_customer" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'visit_id', v.id,
      'code', v.code,
      'pet_name', v.pet_name,
      'pet_photo_url', (select p.photo_url from public.pets p where p.id = v.pet_id),
      'total', c.total,
      'items', c.items
    ) order by v.signed_at, v.code)
    from public.medical_visits v
    cross join lateral (
      select sum(i.amount) as total,
             jsonb_agg(jsonb_build_object(
               'id', i.id,
               'kind', i.kind,
               'name', i.name,
               'qty', i.qty,
               'unit_name', i.unit_name,
               'unit_price', i.unit_price,
               'amount', i.amount
             ) order by i.created_at, i.id) as items
      from public.medical_visit_items i
      where i.visit_id = v.id and i.kind in ('service', 'product') and i.invoice_line_id is null
    ) c
    where v.branch_id = p_branch
      and v.customer_id = p_customer
      and v.status = 'done'
      and v.signed_at is not null
      and c.items is not null
  ), '[]'::jsonb);
end;
$$;

notify pgrst, 'reload schema';
