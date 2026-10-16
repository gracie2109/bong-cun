-- Pet photo in the customer pages' data (docs/anh-thu-cung.md, step 5).
--
--  Adds the pet's photo URL to the JSON a signed-in customer reads: my_pets (photo_url),
--  my_pet_health, my_appointments and my_boarding_stay_json (pet_photo_url). Each function is the
--  current definition with one key added. Customers still only read: nothing here writes.
--  Safe to run more than once.

create or replace function "public"."my_pets"() RETURNS "jsonb"
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
               'allergies', p.allergies,
               'behavior_notes', p.behavior_notes,
               'weight_kg', (
                 select l.weight_kg from public.pet_weight_logs l
                 where l.pet_id = p.id order by l.measured_at desc limit 1
               ),
               'role', po.role,
               'can_edit', po.role = 'primary',
               'has_open_appointment', exists (
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
                 where l.next_due_on is not null
                 order by l.next_due_on, t.name
                 limit 1
               )
             )
             order by lower(p.name), p.created_at
           )
    from public.pet_owners po
    join public.pets p on p.id = po.pet_id
    join public.species s on s.id = p.species_id
    where po.customer_id = v_cust and po.to_date is null and p.status = 'active'
  ), '[]'::jsonb);
end;
$$;

create or replace function "public"."my_pet_health"("p_pet" "uuid") RETURNS "jsonb"
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
  where p.id = p_pet and po.customer_id = v_cust and po.to_date is null and p.status = 'active';
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  return jsonb_build_object(
    'pet_id', v_pet.id,
    'pet_name', v_pet.name,
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
          'next_due_on', last.next_due_on,
          'state', case
            when last.next_due_on is null then 'ok'
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

create or replace function "public"."my_appointments"("p_scope" "text" DEFAULT 'upcoming'::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 10) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cust   uuid := public.my_customer_id();
  v_size   int := least(greatest(coalesce(p_page_size, 10), 1), 50);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_cancel interval := make_interval(mins => (public.spa_web_rules() ->> 'cancel_before_minutes')::int);
  v_upcoming boolean;
  v_total  bigint;
  v_rows   jsonb;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if p_scope not in ('upcoming', 'past') then
    raise exception 'unknown scope' using errcode = '22023', hint = 'invalid_scope';
  end if;
  v_upcoming := p_scope = 'upcoming';
  if v_cust is null then
    return jsonb_build_object('total', 0, 'rows', '[]'::jsonb);
  end if;

  with f as (
    select a.*
    from public.appointments a
    where a.customer_id = v_cust
      and (a.status in ('booked', 'checked_in', 'in_progress')) = v_upcoming
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'code', a.code,
          'status', a.status,
          'start_at', a.start_at,
          'end_at', a.end_at,
          'note', a.note,
          'branch_name', b.name,
          'branch_phone', b.phone,
          'can_cancel', a.status = 'booked' and a.start_at - now() > v_cancel,
          'est_total', (
            select coalesce(sum(i.est_price), 0)
            from public.appointment_items i where i.appointment_id = a.id and i.status <> 'cancelled'
          ),
          'has_unpriced', exists (
            select 1 from public.appointment_items i
            where i.appointment_id = a.id and i.status <> 'cancelled' and i.est_price is null
          ),
          'items', (
            select coalesce(jsonb_agg(
              jsonb_build_object(
                'name', i.name,
                'pet_name', pt.name,
                'pet_photo_url', pt.photo_url,
                'start_at', i.start_at,
                'status', i.status,
                'est_price', i.est_price
              ) order by i.line_no), '[]'::jsonb)
            from public.appointment_items i
            left join public.pets pt on pt.id = i.pet_id
            where i.appointment_id = a.id
          )
        )
        order by case when v_upcoming then a.start_at end asc, case when not v_upcoming then a.start_at end desc
      )
      from (
        select * from f
        order by case when v_upcoming then start_at end asc, case when not v_upcoming then start_at end desc
        limit v_size offset v_offset
      ) a
      join public.branches b on b.id = a.branch_id
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

create or replace function "public"."my_boarding_stay_json"("p_stay" "public"."boarding_stays") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', p_stay.id,
    'code', p_stay.code,
    'status', p_stay.status,
    'planned_in_at', p_stay.planned_in_at,
    'planned_out_at', p_stay.planned_out_at,
    'checked_in_at', p_stay.checked_in_at,
    'checked_out_at', p_stay.checked_out_at,
    'branch_name', b.name,
    'branch_phone', b.phone,
    'est_total', (public.boarding_stay_json(p_stay) ->> 'est_total')::numeric,
    'is_final', p_stay.status in ('checked_out', 'paid'),
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'pet_name', sp.pet_name,
        'pet_photo_url', (select pt.photo_url from public.pets pt where pt.id = sp.pet_id),
        'status', sp.status,
        'kennel_type_name', t.name,
        'nights_from', lower(sp.nights),
        'nights_to', upper(sp.nights),
        'charged_nights', sp.charged_nights,
        'feeding', sp.feeding,
        'medication', sp.medication
      ) order by sp.line_no)
      from public.boarding_stay_pets sp
      join public.kennel_types t on t.id = sp.kennel_type_id
      where sp.stay_id = p_stay.id
    ), '[]'::jsonb)
  )
  from public.branches b
  where b.id = p_stay.branch_id;
$$;

notify pgrst, 'reload schema';
