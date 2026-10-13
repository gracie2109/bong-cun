-- Spa appointments, step 1 (4/4): the appointment list and the day board. Runs after 20261013030200_spa_booking.sql.

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
