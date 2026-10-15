-- Pet hotel (boarding), step 3 (2/2): check-in, extend, check-out
-- (docs/khach-san-thu-cung.md, sections 3, 5 and 9). Runs after 20261020030000_boarding_care.sql.
-- Safe to run more than once.
--
-- Before: a stay can be booked but the pets never "arrive": no weight, no fixed price, no bill.
-- After: check-in records the weight and the hand-over of each pet and fixes its nightly price;
-- extend moves the departure of a stay that is in; check-out counts the nights by the calendar
-- (Vietnam time), adds the late fee, writes the amounts to boarding_charges, frees the nights that
-- were not used and sets the kennels to "cleaning".
--
-- Refusals carry a `hint`: not_found, not_editable, need_weight (detail: pet), kennel_not_ready
-- (detail: kennel code; cleaning or maintenance), kennel_taken (detail: kennel code), pet_busy
-- (detail: pet), bad_dates, too_long.

-- ------------------------------------------------------------ check-in
-- p_pets: [{ stay_pet_id, weight_kg, vaccine_checked?, vaccine_note?, belongings?, feeding?, medication? }],
-- one entry for every pet of the stay. A pet that arrives before its booked day moves its nights to
-- today when the kennel is free, else the call is refused with kennel_taken. The nightly price is
-- fixed here and does not follow later price changes. Returns { id, code }.
create or replace function public.check_in_boarding(p_id uuid, p_pets jsonb, p_emergency_phone text default null) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_stay       public.boarding_stays;
  v_sp         public.boarding_stay_pets;
  v_item       jsonb;
  v_weight     numeric;
  v_kennel     public.kennels;
  v_today      date := public.business_date();
  v_out_date   date;
  v_range      daterange;
  v_charged    numeric;
  v_price      numeric;
  v_constraint text;
begin
  select * into v_stay from public.boarding_stays where id = p_id for update;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('CREATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.status <> 'booked' then
    raise exception 'only a booked stay can be checked in' using errcode = 'P0001', hint = 'not_editable';
  end if;
  v_out_date := public.boarding_local_date(v_stay.planned_out_at);
  if v_today > v_out_date then
    raise exception 'the planned departure has passed' using errcode = 'P0001', hint = 'bad_dates';
  end if;

  for v_sp in
    select * from public.boarding_stay_pets where stay_id = p_id and status = 'active' order by line_no
  loop
    select e into v_item
    from jsonb_array_elements(coalesce(p_pets, '[]'::jsonb)) e
    where e ->> 'stay_pet_id' = v_sp.id::text
    limit 1;
    v_weight := nullif(v_item ->> 'weight_kg', '')::numeric;
    if v_weight is null or v_weight <= 0 or v_weight >= 10000 then
      raise exception 'weigh %', v_sp.pet_name using errcode = '22023', hint = 'need_weight', detail = v_sp.pet_name;
    end if;

    select * into v_kennel from public.kennels where id = v_sp.kennel_id for share;
    if v_kennel.status <> 'ready' then
      raise exception 'kennel % is not ready', v_kennel.code using errcode = 'P0001', hint = 'kennel_not_ready', detail = v_kennel.code;
    end if;

    v_range := v_sp.nights;
    v_charged := v_sp.charged_nights;
    if v_today < lower(v_sp.nights) then
      v_range := daterange(v_today, v_out_date);
      v_charged := v_out_date - v_today;
    end if;
    v_price := case when v_sp.is_extra_pet
                    then public.kennel_extra_pet_price(v_sp.kennel_type_id, v_stay.branch_id)
                    else public.kennel_night_price(v_sp.kennel_type_id, v_stay.branch_id) end;

    begin
      update public.boarding_stay_pets set
        nights = v_range,
        charged_nights = v_charged,
        night_price = coalesce(v_price, v_sp.est_night_price),
        weight_kg = v_weight,
        vaccine_checked = coalesce((v_item ->> 'vaccine_checked')::boolean, false),
        vaccine_note = nullif(btrim(v_item ->> 'vaccine_note'), ''),
        belongings = case when v_item ? 'belongings' then nullif(btrim(v_item ->> 'belongings'), '') else v_sp.belongings end,
        feeding = case when v_item ? 'feeding' then nullif(btrim(v_item ->> 'feeding'), '') else v_sp.feeding end,
        medication = case when v_item ? 'medication' then nullif(btrim(v_item ->> 'medication'), '') else v_sp.medication end
      where id = v_sp.id;
    exception when exclusion_violation then
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint like '%pet_no_overlap' then
        raise exception 'the pet has another stay on these nights' using errcode = 'P0001', hint = 'pet_busy', detail = v_sp.pet_name;
      end if;
      raise exception 'kennel % is taken on these nights', v_kennel.code using errcode = 'P0001', hint = 'kennel_taken', detail = v_kennel.code;
    end;

    insert into public.pet_weight_logs (pet_id, weight_kg, note)
    values (v_sp.pet_id, v_weight, 'Lưu trú ' || v_stay.code);
  end loop;

  update public.boarding_stays set
    status = 'checked_in',
    checked_in_at = now(),
    planned_in_at = least(planned_in_at, now()),
    emergency_phone = coalesce(nullif(btrim(p_emergency_phone), ''), emergency_phone)
  where id = p_id;

  return jsonb_build_object('id', p_id, 'code', v_stay.code);
end;
$$;

revoke execute on function public.check_in_boarding(uuid, jsonb, text) from public, anon;
grant execute on function public.check_in_boarding(uuid, jsonb, text) to authenticated;

-- ------------------------------------------------------------------- extend
-- Moves the planned departure of a stay that is in, longer or shorter. Every pet keeps its kennel;
-- when a later booking already holds one of the added nights the call is refused (kennel_taken).
create or replace function public.extend_boarding_stay(p_id uuid, p_planned_out_at timestamptz) returns void
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.extend_boarding_stay(uuid, timestamptz) from public, anon;
grant execute on function public.extend_boarding_stay(uuid, timestamptz) to authenticated;

-- ----------------------------------------------------------------- check-out
-- What leaving at p_at costs for the night and late-fee lines, and how each pet's nights end
-- (internal). Nights are counted by calendar date: the date of leaving minus the first night, or
-- day_stay_nights when the pet leaves on the day it came. Leaving after check_out_by adds half a
-- night, after late_half_until a whole night (overnight stays only). The occupied nights are only
-- ever cut short, never lengthened, so a pet picked up late does not collide with a later booking.
-- { items: [{ stay_pet_id, pet_name, kind, name, qty, unit_price, amount }],
--   pets: [{ stay_pet_id, charged_nights, nights_to }] }
create or replace function public.boarding_checkout_calc(p_stay public.boarding_stays, p_at timestamptz) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_rules   record;
  v_sp      record;
  v_end     date := public.boarding_local_date(p_at);
  v_time    time := (p_at at time zone c_tz)::time;
  v_start   date;
  v_charged numeric;
  v_upper   date;
  v_late    numeric;
  v_price   numeric;
  v_items   jsonb := '[]'::jsonb;
  v_pets    jsonb := '[]'::jsonb;
begin
  select * into v_rules from public.boarding_rules(p_stay.branch_id);
  for v_sp in
    select sp.*, t.name as type_name, k.code as kennel_code
    from public.boarding_stay_pets sp
    join public.kennel_types t on t.id = sp.kennel_type_id
    join public.kennels k on k.id = sp.kennel_id
    where sp.stay_id = p_stay.id and sp.status = 'active'
    order by sp.line_no
  loop
    v_start := lower(v_sp.nights);
    v_price := coalesce(v_sp.night_price, v_sp.est_night_price);
    v_late := 0;
    if v_end <= v_start then
      v_charged := v_rules.day_stay_nights;
      v_upper := v_start + 1;
    else
      v_charged := v_end - v_start;
      v_upper := least(upper(v_sp.nights), v_end);
      if v_time > v_rules.late_half_until then
        v_late := 1;
      elsif v_time > v_rules.check_out_by then
        v_late := 0.5;
      end if;
    end if;

    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'stay_pet_id', v_sp.id, 'pet_name', v_sp.pet_name, 'kind', 'night',
      'name', 'Lưu trú ' || v_sp.type_name || ' (' || v_sp.kennel_code || ')',
      'qty', v_charged, 'unit_price', v_price, 'amount', round(v_charged * v_price, 2)));
    if v_late > 0 then
      v_items := v_items || jsonb_build_array(jsonb_build_object(
        'stay_pet_id', v_sp.id, 'pet_name', v_sp.pet_name, 'kind', 'late',
        'name', 'Phụ thu trả muộn', 'qty', v_late, 'unit_price', v_price, 'amount', round(v_late * v_price, 2)));
    end if;
    v_pets := v_pets || jsonb_build_array(jsonb_build_object(
      'stay_pet_id', v_sp.id, 'charged_nights', v_charged, 'nights_to', v_upper));
  end loop;
  return jsonb_build_object('items', v_items, 'pets', v_pets);
end;
$$;

revoke execute on function public.boarding_checkout_calc(public.boarding_stays, timestamptz) from public, anon, authenticated;

-- The bill if the pets left at p_at, nothing is saved: the night and late lines plus the extras
-- already added, and the belongings to hand back.
-- { at, items: [line], total, belongings: [{ stay_pet_id, pet_name, belongings, returned }] }
create or replace function public.boarding_checkout_preview(p_id uuid, p_at timestamptz default now()) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_stay  public.boarding_stays;
  v_calc  jsonb;
  v_items jsonb;
begin
  select * into v_stay from public.boarding_stays where id = p_id;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('VIEW', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.status <> 'checked_in' then
    raise exception 'only a stay that is in can be checked out' using errcode = 'P0001', hint = 'not_editable';
  end if;
  v_calc := public.boarding_checkout_calc(v_stay, coalesce(p_at, now()));
  v_items := (v_calc -> 'items') || coalesce((
    select jsonb_agg(jsonb_build_object(
      'stay_pet_id', c.stay_pet_id, 'pet_name', sp.pet_name, 'kind', c.kind, 'name', c.name,
      'qty', c.qty, 'unit_price', c.unit_price, 'amount', c.amount) order by c.created_at, c.id)
    from public.boarding_charges c
    left join public.boarding_stay_pets sp on sp.id = c.stay_pet_id
    where c.stay_id = p_id
  ), '[]'::jsonb);
  return jsonb_build_object(
    'at', coalesce(p_at, now()),
    'items', v_items,
    'total', coalesce((select sum((i ->> 'amount')::numeric) from jsonb_array_elements(v_items) i), 0),
    'belongings', coalesce((
      select jsonb_agg(jsonb_build_object(
        'stay_pet_id', sp.id, 'pet_name', sp.pet_name, 'belongings', sp.belongings,
        'returned', sp.belongings_returned) order by sp.line_no)
      from public.boarding_stay_pets sp
      where sp.stay_id = p_id and sp.status = 'active' and nullif(btrim(sp.belongings), '') is not null
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.boarding_checkout_preview(uuid, timestamptz) from public, anon;
grant execute on function public.boarding_checkout_preview(uuid, timestamptz) to authenticated;

-- Checks the pets out now: writes the night and late lines, cuts the occupied nights to the day of
-- leaving, marks the belongings handed back (p_returned: stay_pet ids) and sets every kennel that
-- was ready to "cleaning". Returns { id, code, total } with everything owed for the stay.
create or replace function public.check_out_boarding(p_id uuid, p_returned uuid[] default '{}') returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.check_out_boarding(uuid, uuid[]) from public, anon;
grant execute on function public.check_out_boarding(uuid, uuid[]) to authenticated;

notify pgrst, 'reload schema';
