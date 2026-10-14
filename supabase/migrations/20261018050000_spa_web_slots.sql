-- Customer UI, step 7 (1/3): rules, quotes and free time slots for booking spa visits on the web
-- (docs/giao-dien-khach-hang.md, 3.5).
--
--  spa_web_rules()                    the named limits of online booking (one place to change them).
--  spa_ticket_quote(branch, pet, ..)  name, minutes and estimated price of one service/combo for one
--                                     pet, the way save_appointment works it out. Internal.
--  spa_block_is_free(branch, start, minutes)
--                                     true when every quarter hour of the block has a free table. Internal.
--  spa_web_slots(branch, date, minutes)
--                                     start times (15 minutes apart) of a block of `minutes`, each flagged
--                                     free or not. Public: it never says who booked.
--  spa_web_quote(branch, items)       the signed-in customer's quote for the chosen pets and services.
--
-- Capacity of a time = the number of active spa tables of the branch (at least 1); tickets that are not
-- cancelled and overlap that time count against it. The customer picks no staff and no table.
-- Safe to run more than once.

create or replace function public.spa_web_rules() returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'min_lead_minutes', 120,
    'max_days', 30,
    'max_open', 3,
    'cancel_before_minutes', 120,
    'step_minutes', 15,
    'max_block_minutes', 600
  );
$$;

revoke execute on function public.spa_web_rules() from public;
grant execute on function public.spa_web_rules() to anon, authenticated;

-- p_type 'service' | 'combo'. Returns { name, minutes, price, weight_kg }; price is null when a
-- by-weight service has no weight yet to price. Errors (hint): unavailable, wrong_species, no_pet.
create or replace function public.spa_ticket_quote(p_branch uuid, p_pet uuid, p_type text, p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_default_minutes constant int := 30;
  v_species uuid;
  v_service public.pet_services;
  v_combo   public.pet_service_combos;
  v_weight  numeric;
  v_price   numeric;
begin
  select species_id into v_species from public.pets where id = p_pet and status = 'active';
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'no_pet';
  end if;

  if p_type = 'combo' then
    select * into v_combo from public.pet_service_combos
    where id = p_id and status = 1 and is_active and coalesce(mark_as_id, '4') <> '3';
    if not found then
      raise exception 'combo is not available' using errcode = 'P0002', hint = 'unavailable';
    end if;
    if exists (select 1 from public.combo_species where combo_id = v_combo.id)
       and not exists (select 1 from public.combo_species where combo_id = v_combo.id and species_id = v_species) then
      raise exception 'the combo is not for this species' using errcode = '22023', hint = 'wrong_species';
    end if;
    return jsonb_build_object(
      'name', v_combo.name,
      'minutes', coalesce(nullif(v_combo.duration_minutes, 0), c_default_minutes),
      'price', v_combo.price,
      'weight_kg', null
    );
  elsif p_type = 'service' then
    select * into v_service from public.pet_services where id = p_id and is_active;
    if not found then
      raise exception 'service is not available' using errcode = 'P0002', hint = 'unavailable';
    end if;
    if exists (select 1 from public.service_species where service_id = v_service.id)
       and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
      raise exception 'the service is not for this species' using errcode = '22023', hint = 'wrong_species';
    end if;
    if v_service.type = 'by_weight' then
      select weight_kg into v_weight from public.pet_weight_logs where pet_id = p_pet order by measured_at desc limit 1;
      v_price := case when v_weight is null then null
                      else public.get_service_price(v_species, v_service.id, v_weight, p_branch) end;
    else
      v_price := v_service.general_price;
    end if;
    return jsonb_build_object(
      'name', v_service.name,
      'minutes', coalesce(nullif(v_service.duration_minutes, 0), c_default_minutes),
      'price', v_price,
      'weight_kg', v_weight
    );
  end if;
  raise exception 'unknown ticket type' using errcode = '22023', hint = 'unavailable';
end;
$$;

revoke execute on function public.spa_ticket_quote(uuid, uuid, text, uuid) from public, anon, authenticated;

-- True when, for every quarter hour in [p_start, p_start + p_minutes), fewer tickets than tables overlap it.
create or replace function public.spa_block_is_free(p_branch uuid, p_start timestamptz, p_minutes int) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with cap as (
    select greatest(1, count(*))::int as n
    from public.spa_resources where branch_id = p_branch and is_active
  )
  select not exists (
    select 1
    from generate_series(0, p_minutes - 1, 15) as g(off), cap
    where (
      select count(*)
      from public.appointment_items i
      where i.branch_id = p_branch
        and i.status <> 'cancelled'
        and i.start_at < p_start + make_interval(mins => g.off + 15)
        and i.end_at > p_start + make_interval(mins => g.off)
    ) >= cap.n
  );
$$;

revoke execute on function public.spa_block_is_free(uuid, timestamptz, int) from public, anon, authenticated;

-- Start times for a block of p_minutes on p_date (business time): inside the opening hours, at least
-- min_lead from now, no more than max_days ahead. Returns [{ start_at, free }].
create or replace function public.spa_web_slots(p_branch uuid, p_date date, p_minutes int) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_rules   jsonb := public.spa_web_rules();
  v_minutes int := p_minutes;
  v_hours   record;
  v_today   date := (now() at time zone c_tz)::date;
  v_open    timestamp;
  v_close   timestamp;
  v_earliest timestamptz := now() + make_interval(mins => (v_rules ->> 'min_lead_minutes')::int);
begin
  if p_branch is null or p_date is null or v_minutes is null
     or not exists (select 1 from public.branches where id = p_branch and is_active) then
    return '[]'::jsonb;
  end if;
  v_minutes := ceil(v_minutes / 15.0)::int * 15;
  if v_minutes < 15 or v_minutes > (v_rules ->> 'max_block_minutes')::int then
    return '[]'::jsonb;
  end if;
  if p_date < v_today or p_date > v_today + (v_rules ->> 'max_days')::int then
    return '[]'::jsonb;
  end if;
  select * into v_hours from public.spa_hours(p_branch, p_date);
  if v_hours.is_closed then
    return '[]'::jsonb;
  end if;

  -- Opening time rounded up to a quarter hour.
  v_open := p_date + (ceil(extract(epoch from v_hours.open_time) / 900.0) * 900 * interval '1 second');
  v_close := p_date + v_hours.close_time;

  return coalesce((
    select jsonb_agg(
             jsonb_build_object(
               'start_at', s.start_at,
               'free', s.start_at >= v_earliest and public.spa_block_is_free(p_branch, s.start_at, v_minutes)
             )
             order by s.start_at)
    from (
      select (g.t at time zone c_tz) as start_at
      from generate_series(v_open, v_close - make_interval(mins => v_minutes), interval '15 minutes') as g(t)
    ) s
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.spa_web_slots(uuid, date, int) from public;
grant execute on function public.spa_web_slots(uuid, date, int) to anon, authenticated;

-- p_items: [{ pet_id, type, id }]. Returns { items: [{ pet_id, type, id, name, minutes, price }],
-- total_minutes, total_price, has_unpriced }. Only the caller's own pets are quoted.
-- Errors (hint): no_customer, no_pet, unavailable, wrong_species, empty.
create or replace function public.spa_web_quote(p_branch uuid, p_items jsonb) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_max_items constant int := 10;
  v_cust   uuid := public.my_customer_id();
  v_item   jsonb;
  v_quote  jsonb;
  v_rows   jsonb := '[]'::jsonb;
  v_minutes int := 0;
  v_total  numeric := 0;
  v_unpriced boolean := false;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) = 0
     or jsonb_array_length(p_items) > c_max_items then
    raise exception 'pick at least one service' using errcode = '22023', hint = 'empty';
  end if;
  for v_item in select * from jsonb_array_elements(p_items) loop
    if not exists (
      select 1 from public.pet_owners
      where pet_id = nullif(v_item ->> 'pet_id', '')::uuid and customer_id = v_cust and to_date is null
    ) then
      raise exception 'pet not found' using errcode = 'P0002', hint = 'no_pet';
    end if;
    v_quote := public.spa_ticket_quote(
      p_branch, (v_item ->> 'pet_id')::uuid, v_item ->> 'type', nullif(v_item ->> 'id', '')::uuid
    );
    v_minutes := v_minutes + (v_quote ->> 'minutes')::int;
    if v_quote ->> 'price' is null then
      v_unpriced := true;
    else
      v_total := v_total + (v_quote ->> 'price')::numeric;
    end if;
    v_rows := v_rows || jsonb_build_array(
      jsonb_build_object(
        'pet_id', v_item ->> 'pet_id', 'type', v_item ->> 'type', 'id', v_item ->> 'id',
        'name', v_quote ->> 'name', 'minutes', (v_quote ->> 'minutes')::int, 'price', v_quote -> 'price'
      )
    );
  end loop;
  return jsonb_build_object('items', v_rows, 'total_minutes', v_minutes, 'total_price', v_total, 'has_unpriced', v_unpriced);
end;
$$;

revoke execute on function public.spa_web_quote(uuid, jsonb) from public, anon;
grant execute on function public.spa_web_quote(uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';
