-- Pet hotel (boarding), step 2 (2/3): book, edit, cancel and quote stays
-- (docs/khach-san-thu-cung.md, sections 5, 6 and 9). Runs after 20261020020000_boarding_stays.sql.
-- Safe to run more than once.
--
-- Refusals carry a `hint` the screen turns into text: no_kennel (detail: kennel type), kennel_taken,
-- pet_busy (detail: pet), species_not_allowed (detail: pet), too_many_pets, bad_dates, too_long,
-- too_early, in_past, not_editable, not_due, no_customer, no_pet (detail: pet), no_price,
-- need_pet, bad_share.

-- ------------------------------------------------------------------- helpers
-- Rules of a branch with the defaults filled in (internal).
create or replace function public.boarding_rules(p_branch uuid)
returns table (check_in_from time, check_out_by time, late_half_until time, max_nights int, day_stay_nights numeric)
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(s.check_in_from, time '08:00'),
         coalesce(s.check_out_by, time '12:00'),
         coalesce(s.late_half_until, time '18:00'),
         coalesce(s.max_nights, 30),
         coalesce(s.day_stay_nights, 1)
  from (select 1) as one
  left join public.boarding_settings s on s.branch_id = p_branch;
$$;

revoke execute on function public.boarding_rules(uuid) from public, anon, authenticated;

-- The Vietnam calendar date of an instant (internal).
create or replace function public.boarding_local_date(p_at timestamptz) returns date
language sql
immutable
set search_path = ''
as $$ select (p_at at time zone 'Asia/Ho_Chi_Minh')::date; $$;

revoke execute on function public.boarding_local_date(timestamptz) from public, anon, authenticated;

-- The first free kennel of a type for a range of nights, in display order (internal).
-- Maintenance and switched-off kennels are skipped; a kennel being cleaned can still be booked ahead.
create or replace function public.boarding_pick_kennel(
  p_branch uuid,
  p_type uuid,
  p_nights daterange,
  p_exclude uuid[] default '{}'
) returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select k.id
  from public.kennels k
  where k.branch_id = p_branch
    and k.kennel_type_id = p_type
    and k.is_active
    and k.status <> 'maintenance'
    and k.id <> all (p_exclude)
    and not exists (
      select 1 from public.boarding_stay_pets sp
      where sp.kennel_id = k.id and sp.status = 'active' and sp.nights && p_nights
    )
  order by k.sort_order, lower(k.code), k.id
  limit 1;
$$;

revoke execute on function public.boarding_pick_kennel(uuid, uuid, daterange, uuid[]) from public, anon, authenticated;

-- ---------------------------------------------------------- book / edit core
-- Creates (p_id null) or replaces a booked stay with its pets in one transaction (internal).
-- p: {
--   branch_id, customer_id, planned_in_at, planned_out_at, source?: 'counter' | 'phone',
--   emergency_phone?, note?,
--   pets: [{ pet_id, kennel_type_id, kennel_id?, share_with?, feeding?, medication?, belongings? }]
-- }
-- kennel_id picks a kennel; without it the first free kennel of the type is taken. share_with is
-- the 1-based line of an earlier pet whose kennel this pet shares. Names and prices come from
-- the database. With p_dry the work is rolled back and the quote is returned.
create or replace function public.boarding_apply_stay(p jsonb, p_id uuid, p_dry boolean) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid        uuid := (select auth.uid());
  v_branch     uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer   uuid := nullif(p ->> 'customer_id', '')::uuid;
  v_in         timestamptz := nullif(p ->> 'planned_in_at', '')::timestamptz;
  v_out        timestamptz := nullif(p ->> 'planned_out_at', '')::timestamptz;
  v_source     text := coalesce(nullif(p ->> 'source', ''), 'counter');
  v_stay       public.boarding_stays;
  v_rules      record;
  v_in_date    date;
  v_out_date   date;
  v_range      daterange;
  v_charged    numeric;
  v_id         uuid;
  v_code       text;
  v_cust_name  text;
  v_cust_phone text;
  v_item       jsonb;
  v_line       int := 0;
  v_pet        uuid;
  v_pet_name   text;
  v_species    uuid;
  v_type       public.kennel_types;
  v_kennel     uuid;
  v_wanted     uuid;
  v_auto       boolean;
  v_excluded   uuid[];
  v_tries      int;
  v_share      int;
  v_extra      boolean;
  v_price      numeric;
  v_sharing    int;
  v_constraint text;
  v_kennels    uuid[] := '{}';
  v_result     jsonb;
begin
  -- Who may do this, and which stay.
  if p_id is not null then
    select * into v_stay from public.boarding_stays where id = p_id for update;
    if not found then
      raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
    end if;
    v_branch := v_stay.branch_id;
    v_customer := v_stay.customer_id;
    if not public.can_boarding('UPDATE', v_branch) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_stay.status <> 'booked' then
      raise exception 'only a booked stay can be edited' using errcode = 'P0001', hint = 'not_editable';
    end if;
  elsif v_uid is null or v_branch is null or not public.can_boarding('CREATE', v_branch) then
    raise exception 'not allowed to book at this branch' using errcode = '42501';
  end if;
  if v_source not in ('counter', 'phone') then
    v_source := 'counter';
  end if;

  -- Dates and the rules of the branch.
  select * into v_rules from public.boarding_rules(v_branch);
  if v_in is null or v_out is null or v_out <= v_in then
    raise exception 'pick the arrival and departure' using errcode = '22023', hint = 'bad_dates';
  end if;
  v_in_date := public.boarding_local_date(v_in);
  v_out_date := public.boarding_local_date(v_out);
  if v_out_date < v_in_date then
    raise exception 'departure is before arrival' using errcode = '22023', hint = 'bad_dates';
  end if;
  if v_in_date < public.business_date() then
    raise exception 'the arrival is in the past' using errcode = 'P0001', hint = 'in_past';
  end if;
  if (v_in at time zone c_tz)::time < v_rules.check_in_from then
    raise exception 'pets are accepted from %', v_rules.check_in_from using errcode = 'P0001', hint = 'too_early';
  end if;
  if v_out_date - v_in_date > v_rules.max_nights then
    raise exception 'a stay is at most % nights', v_rules.max_nights using errcode = 'P0001', hint = 'too_long';
  end if;
  -- A same-day stay still holds the kennel for that one night.
  v_range := daterange(v_in_date, greatest(v_out_date, v_in_date + 1), '[)');
  v_charged := case when v_out_date = v_in_date then v_rules.day_stay_nights else (v_out_date - v_in_date) end;

  select full_name, phone into v_cust_name, v_cust_phone
  from public.customers where id = v_customer and is_active;
  if v_cust_name is null then
    raise exception 'pick a customer' using errcode = 'P0002', hint = 'no_customer';
  end if;
  if jsonb_array_length(coalesce(p -> 'pets', '[]'::jsonb)) = 0 then
    raise exception 'pick at least one pet' using errcode = '22023', hint = 'need_pet';
  end if;

  -- The stay row (kept on edit, so its code does not change).
  if p_id is null then
    v_code := public.next_doc_code(v_branch, 'LT');
    insert into public.boarding_stays (
      code, branch_id, customer_id, customer_name, customer_phone,
      planned_in_at, planned_out_at, source, emergency_phone, note, created_by
    ) values (
      v_code, v_branch, v_customer, v_cust_name, v_cust_phone, v_in, v_out, v_source,
      nullif(btrim(p ->> 'emergency_phone'), ''), nullif(btrim(p ->> 'note'), ''), v_uid
    ) returning id into v_id;
  else
    v_id := p_id;
    v_code := v_stay.code;
    -- Free the old kennels first so the new rows do not clash with themselves.
    delete from public.boarding_stay_pets where stay_id = v_id;
    update public.boarding_stays set
      planned_in_at = v_in,
      planned_out_at = v_out,
      source = v_source,
      emergency_phone = nullif(btrim(p ->> 'emergency_phone'), ''),
      note = nullif(btrim(p ->> 'note'), '')
    where id = v_id;
  end if;

  -- One row per pet.
  for v_item in select * from jsonb_array_elements(p -> 'pets') loop
    v_line := v_line + 1;
    v_pet := nullif(v_item ->> 'pet_id', '')::uuid;
    v_wanted := nullif(v_item ->> 'kennel_id', '')::uuid;
    v_share := nullif(v_item ->> 'share_with', '')::int;
    v_extra := false;

    select pt.name, pt.species_id into v_pet_name, v_species
    from public.pets pt
    join public.pet_owners o on o.pet_id = pt.id and o.customer_id = v_customer and o.to_date is null
    where pt.id = v_pet and pt.status = 'active';
    if v_pet_name is null then
      raise exception 'line %: the pet does not belong to this customer', v_line
        using errcode = '22023', hint = 'no_pet', detail = coalesce(v_pet::text, '');
    end if;

    select * into v_type from public.kennel_types
    where id = nullif(v_item ->> 'kennel_type_id', '')::uuid and is_active and purpose = 'boarding';
    if not found then
      raise exception 'line %: pick a kennel type', v_line using errcode = '22023', hint = 'bad_input';
    end if;
    if cardinality(v_type.species_ids) > 0 and v_species <> all (v_type.species_ids) then
      raise exception 'line %: % does not take this species', v_line, v_type.name
        using errcode = 'P0001', hint = 'species_not_allowed', detail = v_pet_name;
    end if;
    v_price := public.kennel_night_price(v_type.id, v_branch);
    if v_price is null then
      raise exception 'line %: % has no price', v_line, v_type.name
        using errcode = 'P0001', hint = 'no_price', detail = v_type.name;
    end if;

    v_kennel := null;
    v_auto := false;
    if v_share is not null then
      -- Shares the kennel of an earlier line: same type, same owner, capacity of the type.
      if v_share < 1 or v_share >= v_line or v_kennels[v_share] is null
         or not exists (
           select 1 from public.boarding_stay_pets
           where stay_id = v_id and line_no = v_share and kennel_type_id = v_type.id
         ) then
        raise exception 'line %: cannot share that kennel', v_line using errcode = '22023', hint = 'bad_share';
      end if;
      select count(*) + 1 into v_sharing from public.boarding_stay_pets
      where stay_id = v_id and kennel_id = v_kennels[v_share];
      if v_sharing > v_type.max_pets then
        raise exception 'line %: at most % pets in one % kennel', v_line, v_type.max_pets, v_type.name
          using errcode = 'P0001', hint = 'too_many_pets', detail = v_type.name;
      end if;
      v_kennel := v_kennels[v_share];
      v_extra := true;
      v_price := public.kennel_extra_pet_price(v_type.id, v_branch);
    elsif v_wanted is not null then
      if not exists (
        select 1 from public.kennels
        where id = v_wanted and branch_id = v_branch and kennel_type_id = v_type.id
          and is_active and status <> 'maintenance'
      ) then
        raise exception 'line %: that kennel cannot be used', v_line using errcode = 'P0001', hint = 'kennel_taken';
      end if;
      v_kennel := v_wanted;
    else
      v_auto := true;
    end if;

    v_excluded := '{}';
    v_tries := 0;
    loop
      if v_kennel is null then
        v_kennel := public.boarding_pick_kennel(v_branch, v_type.id, v_range, v_excluded);
        if v_kennel is null then
          raise exception 'line %: no free % kennel for those nights', v_line, v_type.name
            using errcode = 'P0001', hint = 'no_kennel', detail = v_type.name;
        end if;
      end if;
      begin
        insert into public.boarding_stay_pets (
          stay_id, branch_id, line_no, pet_id, pet_name, kennel_type_id, kennel_id, nights, charged_nights,
          is_extra_pet, est_night_price, feeding, medication, belongings
        ) values (
          v_id, v_branch, v_line, v_pet, v_pet_name, v_type.id, v_kennel, v_range, v_charged,
          v_extra, v_price,
          nullif(btrim(v_item ->> 'feeding'), ''),
          nullif(btrim(v_item ->> 'medication'), ''),
          nullif(btrim(v_item ->> 'belongings'), '')
        );
        exit;
      exception when exclusion_violation then
        get stacked diagnostics v_constraint = constraint_name;
        if v_constraint like '%pet_no_overlap' then
          raise exception 'line %: % is already in another stay on those nights', v_line, v_pet_name
            using errcode = 'P0001', hint = 'pet_busy', detail = v_pet_name;
        end if;
        -- Another booking took the kennel a moment ago: look for another one of the same type, once.
        if v_auto and v_tries < 1 then
          v_excluded := v_excluded || v_kennel;
          v_kennel := null;
          v_tries := v_tries + 1;
        elsif v_auto then
          raise exception 'line %: no free % kennel for those nights', v_line, v_type.name
            using errcode = 'P0001', hint = 'no_kennel', detail = v_type.name;
        else
          raise exception 'line %: the kennel is taken on those nights', v_line
            using errcode = 'P0001', hint = 'kennel_taken';
        end if;
      end;
    end loop;
    v_kennels[v_line] := v_kennel;
  end loop;

  -- What the stay looks like now (also the answer of a quote).
  select jsonb_build_object(
    'id', v_id,
    'code', v_code,
    'nights', v_charged,
    'total', coalesce(sum(sp.est_night_price * sp.charged_nights), 0),
    'items', coalesce(jsonb_agg(jsonb_build_object(
      'line_no', sp.line_no,
      'pet_id', sp.pet_id,
      'pet_name', sp.pet_name,
      'kennel_type_id', sp.kennel_type_id,
      'kennel_type_name', t.name,
      'kennel_id', sp.kennel_id,
      'kennel_code', k.code,
      'is_extra_pet', sp.is_extra_pet,
      'night_price', sp.est_night_price,
      'amount', sp.est_night_price * sp.charged_nights,
      'warnings', (
        select coalesce(jsonb_agg(w), '[]'::jsonb) from (
          select 'overweight' as w
          where t.max_weight_kg is not null and coalesce((
            select l.weight_kg from public.pet_weight_logs l where l.pet_id = sp.pet_id
            order by l.measured_at desc limit 1
          ), 0) > t.max_weight_kg
          union all
          select 'behavior' where exists (
            select 1 from public.pets pt
            where pt.id = sp.pet_id
              and (nullif(btrim(pt.behavior_notes), '') is not null or nullif(btrim(pt.allergies), '') is not null)
          )
        ) as ws
      )
    ) order by sp.line_no), '[]'::jsonb)
  ) into v_result
  from public.boarding_stay_pets sp
  join public.kennel_types t on t.id = sp.kennel_type_id
  join public.kennels k on k.id = sp.kennel_id
  where sp.stay_id = v_id;

  if p_dry then
    -- Roll everything back (the caller catches this) and hand the quote over in the message.
    raise exception '%', v_result::text using errcode = 'BQ001';
  end if;
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

revoke execute on function public.boarding_apply_stay(jsonb, uuid, boolean) from public, anon, authenticated;

-- Creates (p_id null) or replaces a booked stay. Returns { id, code }.
create or replace function public.save_boarding_stay(p jsonb, p_id uuid default null) returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select public.boarding_apply_stay(p, p_id, false);
$$;

revoke execute on function public.save_boarding_stay(jsonb, uuid) from public, anon;
grant execute on function public.save_boarding_stay(jsonb, uuid) to authenticated;

-- What a booking would cost and which kennels it would get, nothing saved. Same checks and the
-- same kennel choice as save_boarding_stay. p_stay: the stay being edited, so its own kennels
-- count as free. Returns { nights, total, items: [{ pet_name, kennel_type_name, kennel_code,
-- night_price, amount, is_extra_pet, warnings }] }.
create or replace function public.boarding_quote(p_branch uuid, p jsonb, p_stay uuid default null) returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  if not (public.can_boarding('CREATE', p_branch) or public.can_boarding('UPDATE', p_branch)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  begin
    perform public.boarding_apply_stay(
      jsonb_set(coalesce(p, '{}'::jsonb), '{branch_id}', to_jsonb(p_branch::text)), p_stay, true
    );
  exception when sqlstate 'BQ001' then
    return sqlerrm::jsonb;
  end;
  return null;
end;
$$;

revoke execute on function public.boarding_quote(uuid, jsonb, uuid) from public, anon;
grant execute on function public.boarding_quote(uuid, jsonb, uuid) to authenticated;

-- ------------------------------------------------------------- availability
-- Kennels free for every night of [p_from, p_to), per kennel type:
-- [{ kennel_type_id, name, total, free, night_price }]. Types without kennels at the branch are left out.
create or replace function public.boarding_availability(p_branch uuid, p_from date, p_to date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_range daterange;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'bad dates' using errcode = '22023', hint = 'bad_dates';
  end if;
  v_range := daterange(p_from, greatest(p_to, p_from + 1), '[)');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'kennel_type_id', t.id,
      'name', t.name,
      'total', x.total,
      'free', x.free,
      'night_price', public.kennel_night_price(t.id, p_branch)
    ) order by t.sort_order, lower(t.name), t.id)
    from public.kennel_types t
    cross join lateral (
      select count(*) as total,
             count(*) filter (where not exists (
               select 1 from public.boarding_stay_pets sp
               where sp.kennel_id = k.id and sp.status = 'active' and sp.nights && v_range
             )) as free
      from public.kennels k
      where k.branch_id = p_branch and k.kennel_type_id = t.id and k.is_active and k.status <> 'maintenance'
    ) x
    where t.is_active and t.purpose = 'boarding' and x.total > 0
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.boarding_availability(uuid, date, date) from public, anon;
grant execute on function public.boarding_availability(uuid, date, date) to authenticated;

-- ------------------------------------------------------------ cancel / no show
-- Only a booked stay; frees the kennels.
create or replace function public.cancel_boarding_stay(p_id uuid, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stay public.boarding_stays;
begin
  select * into v_stay from public.boarding_stays where id = p_id for update;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('DELETE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.status <> 'booked' then
    raise exception 'only a booked stay can be cancelled' using errcode = 'P0001', hint = 'not_editable';
  end if;
  update public.boarding_stay_pets set status = 'cancelled' where stay_id = p_id;
  update public.boarding_stays set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = nullif(btrim(p_reason), '')
  where id = p_id;
end;
$$;

revoke execute on function public.cancel_boarding_stay(uuid, text) from public, anon;
grant execute on function public.cancel_boarding_stay(uuid, text) to authenticated;

-- The customer did not come: only a booked stay whose arrival day has passed. Frees the kennels.
create or replace function public.mark_boarding_no_show(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_stay public.boarding_stays;
begin
  select * into v_stay from public.boarding_stays where id = p_id for update;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.status <> 'booked' then
    raise exception 'only a booked stay can be marked as no-show' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if public.boarding_local_date(v_stay.planned_in_at) >= public.business_date() then
    raise exception 'the arrival day has not passed' using errcode = 'P0001', hint = 'not_due';
  end if;
  update public.boarding_stay_pets set status = 'cancelled' where stay_id = p_id;
  update public.boarding_stays set status = 'no_show' where id = p_id;
end;
$$;

revoke execute on function public.mark_boarding_no_show(uuid) from public, anon;
grant execute on function public.mark_boarding_no_show(uuid) to authenticated;

notify pgrst, 'reload schema';
