-- Pet hotel (boarding), step 2 (3/3): list, detail and the day board of stays
-- (docs/khach-san-thu-cung.md, section 6). Runs after 20261020020100_boarding_booking.sql.
-- Safe to run more than once.

-- JSON of one stay for the list and the detail (internal). `pets` carries the rows of
-- boarding_stay_pets; the detail adds more in later steps.
create or replace function public.boarding_stay_json(p_stay public.boarding_stays) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
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
    'emergency_phone', p_stay.emergency_phone,
    'note', p_stay.note,
    'cancel_reason', p_stay.cancel_reason,
    'est_total', coalesce((
      select sum(coalesce(sp.night_price, sp.est_night_price) * sp.charged_nights)
      from public.boarding_stay_pets sp where sp.stay_id = p_stay.id and sp.status = 'active'
    ), 0),
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

revoke execute on function public.boarding_stay_json(public.boarding_stays) from public, anon, authenticated;

-- ---------------------------------------------------------------------- list
-- One page: { total, rows: [stay] } newest arrival first. p_from / p_to keep the stays that touch
-- that range of days (arrival and departure as planned, or as happened). Search matches the code,
-- customer name (accents ignored), phone, pet name or kennel code.
create or replace function public.list_boarding_stays(
  p_branch    uuid,
  p_from      date default null,
  p_to        date default null,
  p_status    text default null,
  p_search    text default null,
  p_page      int default 1,
  p_page_size int default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_digits text := regexp_replace(coalesce(p_search, ''), '\D', '', 'g');
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select s.*
    from public.boarding_stays s
    where s.branch_id = p_branch
      and (nullif(p_status, '') is null or s.status = p_status)
      and (p_from is null or public.boarding_local_date(coalesce(s.checked_out_at, s.planned_out_at)) >= p_from)
      and (p_to is null or public.boarding_local_date(coalesce(s.checked_in_at, s.planned_in_at)) <= p_to)
      and (
        v_term = ''
        or lower(s.code) like v_like
        or lower(public.immutable_unaccent(s.customer_name)) like v_like
        or (length(v_digits) >= 3 and regexp_replace(s.customer_phone, '\D', '', 'g') like v_digits || '%')
        or exists (
          select 1
          from public.boarding_stay_pets sp
          join public.kennels k on k.id = sp.kennel_id
          where sp.stay_id = s.id
            and (lower(public.immutable_unaccent(sp.pet_name)) like v_like or lower(k.code) like v_like)
        )
      )
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(public.boarding_stay_json(s) order by s.planned_in_at desc, s.id)
      from (select * from f order by planned_in_at desc, id limit v_size offset v_offset) s
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;

revoke execute on function public.list_boarding_stays(uuid, date, date, text, text, int, int) from public, anon;
grant execute on function public.list_boarding_stays(uuid, date, date, text, text, int, int) to authenticated;

-- One stay with its pets, or null when the caller cannot see it.
create or replace function public.get_boarding_stay(p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_stay public.boarding_stays;
begin
  select * into v_stay from public.boarding_stays where id = p_id;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('VIEW', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return public.boarding_stay_json(v_stay);
end;
$$;

revoke execute on function public.get_boarding_stay(uuid) from public, anon;
grant execute on function public.get_boarding_stay(uuid) to authenticated;

-- ------------------------------------------------------------------- board
-- The day board: every active kennel with what is in it on p_date (default today), grouped by the
-- screen. state, by priority: maintenance, overdue (a pet is past its planned departure),
-- departing (leaves today), occupied, cleaning, arriving (a booked pet arrives today), free.
-- { date, counts: { arriving, departing, occupied, overdue, free },
--   kennels: [{ id, code, name, kennel_type_id, kennel_type_name, status, state, conflict,
--               pets: [pet], arriving: [pet] }] }
-- pet: { stay_id, stay_code, stay_status, stay_pet_id, pet_id, pet_name, customer_name,
--        planned_in_at, planned_out_at, has_notes, overdue }
create or replace function public.boarding_board(p_branch uuid, p_date date default null) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
    where sp.branch_id = p_branch and sp.status = 'active'
      and s.status in ('booked', 'checked_in')
  ), per_kennel as (
    select k.id, k.code, k.name, k.kennel_type_id, t.name as type_name, k.status, k.sort_order, t.sort_order as type_sort,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name,
             'customer_name', p.customer_name, 'planned_in_at', p.planned_in_at,
             'planned_out_at', p.planned_out_at, 'has_notes', p.has_notes, 'overdue', p.overdue
           ) order by p.pet_name) filter (where p.in_kennel), '[]'::jsonb) as in_pets,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name,
             'customer_name', p.customer_name, 'planned_in_at', p.planned_in_at,
             'planned_out_at', p.planned_out_at, 'has_notes', p.has_notes, 'overdue', false
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
           'kennel_type_id', st.kennel_type_id, 'kennel_type_name', st.type_name,
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
        'free', count(*) filter (where k ->> 'state' = 'free')
      )
      from jsonb_array_elements(coalesce(v_kennels, '[]'::jsonb)) as t(k)
    )
  );
end;
$$;

revoke execute on function public.boarding_board(uuid, date) from public, anon;
grant execute on function public.boarding_board(uuid, date) to authenticated;

notify pgrst, 'reload schema';
