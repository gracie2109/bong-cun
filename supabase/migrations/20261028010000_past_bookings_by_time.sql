-- Past bookings no longer show as upcoming on the customer's account pages.
--
--  my_appointments put every 'booked' visit under "Sắp tới", so a visit whose time had passed
--  (the shop never marked it no-show) stayed there with "Đã đặt". my_boarding_stays did the same
--  for booked stays past their planned check-out. Upcoming/past is now decided from the time, in
--  the database clock: a booked visit moves to "Đã qua" once its end time passes, a booked stay
--  once its planned check-out passes. Both JSONs gain 'overdue' so the page can say "quá giờ hẹn"
--  instead of "Đã đặt". The stored status is not touched: staff still mark no-show themselves.
--  Each function is its current definition with only these changes. Safe to run more than once.

create or replace function "public"."my_boarding_stay_in_scope"("p_stay" "public"."boarding_stays", "p_scope" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select case p_scope
    when 'upcoming' then p_stay.status = 'booked' and p_stay.planned_out_at > now()
    when 'current' then p_stay.status = 'checked_in'
    when 'past' then p_stay.status in ('checked_out', 'paid', 'cancelled', 'no_show')
      or (p_stay.status = 'booked' and p_stay.planned_out_at <= now())
    else false
  end;
$$;

revoke execute on function "public"."my_boarding_stay_in_scope"("public"."boarding_stays", "text") from public, anon, authenticated;

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
      and (a.status in ('checked_in', 'in_progress') or (a.status = 'booked' and a.end_at > now())) = v_upcoming
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
          'overdue', a.status = 'booked' and a.end_at <= now(),
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
    'overdue', p_stay.status = 'booked' and p_stay.planned_out_at <= now(),
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

create or replace function "public"."my_boarding_stays"("p_scope" "text" DEFAULT 'upcoming'::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 10) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cust   uuid := public.my_customer_id();
  v_size   int := least(greatest(coalesce(p_page_size, 10), 1), 50);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_states text[];
  v_total  bigint;
  v_rows   jsonb;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  v_states := case p_scope
    when 'upcoming' then array['booked']
    when 'current' then array['checked_in']
    when 'past' then array['checked_out', 'paid', 'cancelled', 'no_show']
  end;
  if v_states is null then
    raise exception 'unknown scope' using errcode = '22023', hint = 'invalid_scope';
  end if;
  if v_cust is null then
    return jsonb_build_object('total', 0, 'rows', '[]'::jsonb);
  end if;

  select count(*) into v_total
  from public.boarding_stays s where s.customer_id = v_cust and public.my_boarding_stay_in_scope(s, p_scope);

  select coalesce(jsonb_agg(public.my_boarding_stay_json(s) order by
           case when p_scope = 'past' then null else s.planned_in_at end asc,
           s.planned_in_at desc), '[]'::jsonb)
  into v_rows
  from (
    select * from public.boarding_stays s
    where s.customer_id = v_cust and public.my_boarding_stay_in_scope(s, p_scope)
    order by case when p_scope = 'past' then null else s.planned_in_at end asc, s.planned_in_at desc
    limit v_size offset v_offset
  ) s;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;
