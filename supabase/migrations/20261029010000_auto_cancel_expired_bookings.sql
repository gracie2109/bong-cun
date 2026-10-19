-- Bookings nobody showed up for are cancelled by the system, with a reason the pages can name.
--
--  A booked spa visit or hotel stay whose time is over (visit end / planned check-out, plus one
--  hour so a late check-in at the counter is never raced) was left 'booked' until staff marked it.
--  auto_cancel_expired_bookings() now sets those to 'cancelled' with the fixed reason from
--  expired_booking_reason(), cancels their items / pets (the same writes as cancel_appointment and
--  cancel_boarding_stay), and runs every 15 minutes. my_appointments and my_boarding_stay_json
--  return 'expired' for them so the customer pages show "Hủy vì quá thời gian". Checked-in or
--  started work is never touched. Safe to run more than once.

create or replace function public.expired_booking_reason()
returns text
language sql
immutable
set search_path = ''
as $$ select 'Tự hủy: quá thời gian hẹn'::text $$;

revoke execute on function public.expired_booking_reason() from public, anon, authenticated;

create or replace function public.auto_cancel_expired_bookings(p_grace_minutes integer default 60)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cutoff  timestamptz;
  v_appts   integer;
  v_stays   integer;
begin
  if p_grace_minutes is null or p_grace_minutes < 0 then
    raise exception 'p_grace_minutes must not be negative' using errcode = '22023', hint = 'bad_grace';
  end if;
  v_cutoff := now() - make_interval(mins => p_grace_minutes);

  with expired as (
    update public.appointments
    set status = 'cancelled', cancelled_at = now(), cancel_reason = public.expired_booking_reason()
    where status = 'booked' and end_at < v_cutoff
    returning id
  ), items as (
    update public.appointment_items set status = 'cancelled'
    where appointment_id in (select id from expired)
    returning 1
  )
  select count(*) into v_appts from expired;

  with expired as (
    update public.boarding_stays
    set status = 'cancelled', cancelled_at = now(), cancel_reason = public.expired_booking_reason()
    where status = 'booked' and kind = 'boarding' and planned_out_at < v_cutoff
    returning id
  ), pets as (
    update public.boarding_stay_pets set status = 'cancelled'
    where stay_id in (select id from expired)
    returning 1
  )
  select count(*) into v_stays from expired;

  return jsonb_build_object('appointments', v_appts, 'stays', v_stays);
end;
$$;

revoke all on function public.auto_cancel_expired_bookings(integer) from public, anon, authenticated;
grant execute on function public.auto_cancel_expired_bookings(integer) to service_role;

create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('auto-cancel-expired-bookings')
  where exists (select 1 from cron.job where jobname = 'auto-cancel-expired-bookings');
  perform cron.schedule(
    'auto-cancel-expired-bookings',
    '*/15 * * * *',
    'select public.auto_cancel_expired_bookings(60)'
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
    'expired', p_stay.status = 'cancelled' and p_stay.cancel_reason = public.expired_booking_reason(),
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
