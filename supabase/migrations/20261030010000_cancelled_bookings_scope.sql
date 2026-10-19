-- A separate "Đã hủy" tab on the customer's Lịch hẹn and Lưu trú pages.
--
--  Cancelled visits and stays (by the customer, the shop, or the system for being overdue) were
--  listed under "Đã qua" with the finished ones. my_appointments and my_boarding_stays now take
--  scope 'cancelled' for them, and 'past' keeps only the finished, no-show and overdue-booked ones.
--  Each function is its current definition with only the scope changes. Safe to run more than once.

create or replace function "public"."my_boarding_stay_in_scope"("p_stay" "public"."boarding_stays", "p_scope" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select case p_scope
    when 'upcoming' then p_stay.status = 'booked' and p_stay.planned_out_at > now()
    when 'current' then p_stay.status = 'checked_in'
    when 'cancelled' then p_stay.status = 'cancelled'
    when 'past' then p_stay.status in ('checked_out', 'paid', 'no_show')
      or (p_stay.status = 'booked' and p_stay.planned_out_at <= now())
    else false
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
  if p_scope not in ('upcoming', 'past', 'cancelled') then
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
      and case p_scope
            when 'upcoming' then a.status in ('checked_in', 'in_progress') or (a.status = 'booked' and a.end_at > now())
            when 'cancelled' then a.status = 'cancelled'
            else a.status in ('done', 'paid', 'no_show') or (a.status = 'booked' and a.end_at <= now())
          end
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
          'expired', a.status = 'cancelled' and a.cancel_reason = public.expired_booking_reason(),
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
    when 'past' then array['checked_out', 'paid', 'no_show']
    when 'cancelled' then array['cancelled']
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
           case when p_scope in ('past', 'cancelled') then null else s.planned_in_at end asc,
           s.planned_in_at desc), '[]'::jsonb)
  into v_rows
  from (
    select * from public.boarding_stays s
    where s.customer_id = v_cust and public.my_boarding_stay_in_scope(s, p_scope)
    order by case when p_scope in ('past', 'cancelled') then null else s.planned_in_at end asc, s.planned_in_at desc
    limit v_size offset v_offset
  ) s;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;
