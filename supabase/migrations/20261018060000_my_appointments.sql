-- Customer UI, step 8: "my appointments" for the signed-in web account (docs/giao-dien-khach-hang.md, 3.6).
--
--  my_appointments(p_scope, p_page, p_page_size)  'upcoming' (booked, checked in, in progress; soonest
--                                                 first) or 'past' (done, paid, cancelled, no show;
--                                                 newest first). Returns { total, rows }. A row never
--                                                 names the staff, only the state of the visit.
--  cancel_my_appointment(p_id, p_reason)          cancels my own appointment while it is still 'booked' and
--                                                 more than spa_web_rules().cancel_before_minutes ahead.
--
-- Errors (hint): no_customer, invalid_scope, not_found, not_cancellable, too_late. Safe to run more than once.

create or replace function public.my_appointments(
  p_scope text default 'upcoming',
  p_page int default 1,
  p_page_size int default 10
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.my_appointments(text, int, int) from public, anon;
grant execute on function public.my_appointments(text, int, int) to authenticated;

create or replace function public.cancel_my_appointment(p_id uuid, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cust  uuid := public.my_customer_id();
  v_appt  public.appointments;
  v_cancel interval := make_interval(mins => (public.spa_web_rules() ->> 'cancel_before_minutes')::int);
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  select * into v_appt from public.appointments where id = p_id and customer_id = v_cust for update;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_appt.status <> 'booked' then
    raise exception 'this appointment can no longer be cancelled' using errcode = 'P0001', hint = 'not_cancellable';
  end if;
  if v_appt.start_at - now() <= v_cancel then
    raise exception 'too close to the appointment time' using errcode = 'P0001', hint = 'too_late';
  end if;

  update public.appointment_items set status = 'cancelled' where appointment_id = p_id;
  update public.appointments set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = coalesce(left(nullif(btrim(p_reason), ''), 200), 'cancelled by customer')
  where id = p_id;
end;
$$;

revoke execute on function public.cancel_my_appointment(uuid, text) from public, anon;
grant execute on function public.cancel_my_appointment(uuid, text) to authenticated;

notify pgrst, 'reload schema';
