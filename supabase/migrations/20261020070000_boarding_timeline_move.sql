-- Pet hotel, step 7 (Should): kennel calendar and moving a pet to another kennel (docs/khach-san-thu-cung.md).
--
--  boarding_timeline(p_branch, p_from, p_days)  the booked nights of every kennel over p_days days (1 to 31, default 14)
--                                                from p_from (default today). Segments are the nights of active pets of
--                                                booked, checked-in, checked-out and paid stays that touch the window.
--  move_boarding_pet(p_stay_pet, p_kennel)      puts a pet of a booked or checked-in stay in another kennel of the SAME type.
--
-- A stay-pet row has one kennel for all its nights, so a move changes the kennel of the whole row: the new kennel
-- has to be free on every night of the stay (kennel_taken otherwise). The price stays (same type); a pet that was
-- the second in a shared kennel and moves alone pays the full price from then on.
-- Errors (hint): not_found, not_editable, wrong_type, same_kennel, kennel_not_ready, kennel_taken, kennel_full.
-- Safe to run more than once.

-- { from, days, kennels: [{ id, code, name, kennel_type_id, kennel_type_name, status,
--     segments: [{ stay_id, stay_code, stay_status, stay_pet_id, pet_name, customer_name, from, to }] }] }
create or replace function public.boarding_timeline(p_branch uuid, p_from date default null, p_days int default 14) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_from date := coalesce(p_from, public.business_date());
  v_days int := least(greatest(coalesce(p_days, 14), 1), 31);
  v_win  daterange;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  v_win := daterange(v_from, v_from + v_days, '[)');

  return jsonb_build_object(
    'from', v_from,
    'days', v_days,
    'kennels', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', k.id, 'code', k.code, 'name', k.name,
        'kennel_type_id', k.kennel_type_id, 'kennel_type_name', t.name, 'status', k.status,
        'segments', coalesce((
          select jsonb_agg(jsonb_build_object(
            'stay_id', s.id, 'stay_code', s.code, 'stay_status', s.status, 'stay_pet_id', sp.id,
            'pet_name', sp.pet_name, 'customer_name', s.customer_name,
            'from', lower(sp.nights), 'to', upper(sp.nights)
          ) order by lower(sp.nights), sp.line_no)
          from public.boarding_stay_pets sp
          join public.boarding_stays s on s.id = sp.stay_id
          where sp.kennel_id = k.id and sp.status = 'active'
            and s.status in ('booked', 'checked_in', 'checked_out', 'paid')
            and sp.nights && v_win
        ), '[]'::jsonb)
      ) order by t.sort_order, lower(t.name), k.sort_order, lower(k.code), k.id)
      from public.kennels k
      join public.kennel_types t on t.id = k.kennel_type_id
      where k.branch_id = p_branch and k.is_active
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.boarding_timeline(uuid, date, int) from public, anon;
grant execute on function public.boarding_timeline(uuid, date, int) to authenticated;

create or replace function public.move_boarding_pet(p_stay_pet uuid, p_kennel uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sp     public.boarding_stay_pets;
  v_stay   public.boarding_stays;
  v_kennel public.kennels;
  v_old    uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = p_stay_pet for update;
  if not found then
    raise exception 'stay pet % not found', p_stay_pet using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_stay from public.boarding_stays where id = v_sp.stay_id for update;
  if not public.can_boarding('UPDATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_sp.status <> 'active' or v_stay.status not in ('booked', 'checked_in') then
    raise exception 'this pet cannot change kennel' using errcode = 'P0001', hint = 'not_editable';
  end if;

  select * into v_kennel from public.kennels where id = p_kennel and branch_id = v_stay.branch_id and is_active;
  if not found then
    raise exception 'kennel not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_kennel.id = v_sp.kennel_id then
    raise exception 'the pet is already in this kennel' using errcode = '22023', hint = 'same_kennel';
  end if;
  if v_kennel.kennel_type_id <> v_sp.kennel_type_id then
    raise exception 'pick a kennel of the same type' using errcode = '22023', hint = 'wrong_type';
  end if;
  if v_kennel.status = 'maintenance' or (v_stay.status = 'checked_in' and v_kennel.status <> 'ready') then
    raise exception 'the kennel is not ready' using errcode = 'P0001', hint = 'kennel_not_ready';
  end if;

  -- Sharing is decided when the stay is booked (it sets the price), so a move never joins a pet of the same stay.
  if exists (
    select 1 from public.boarding_stay_pets o
    where o.stay_id = v_sp.stay_id and o.kennel_id = p_kennel and o.status = 'active' and o.id <> v_sp.id
  ) then
    raise exception 'the kennel is full' using errcode = 'P0001', hint = 'kennel_full';
  end if;

  v_old := v_sp.kennel_id;
  begin
    update public.boarding_stay_pets set kennel_id = p_kennel where id = v_sp.id;
  exception when exclusion_violation then
    raise exception 'the kennel is taken on some night of this stay' using errcode = 'P0001', hint = 'kennel_taken';
  end;

  -- A second pet that now has a kennel to itself pays the full price from here on.
  if v_sp.is_extra_pet then
    update public.boarding_stay_pets
    set is_extra_pet = false,
        est_night_price = public.kennel_night_price(v_sp.kennel_type_id, v_stay.branch_id),
        night_price = case when v_sp.night_price is not null then public.kennel_night_price(v_sp.kennel_type_id, v_stay.branch_id) end
    where id = v_sp.id;
  end if;

  -- The kennel the pet left needs cleaning when the pet was physically in it.
  if v_stay.status = 'checked_in' and not exists (
    select 1 from public.boarding_stay_pets o
    join public.boarding_stays os on os.id = o.stay_id
    where o.kennel_id = v_old and o.status = 'active' and os.status = 'checked_in'
  ) then
    update public.kennels set status = 'cleaning' where id = v_old and status = 'ready';
  end if;
end;
$$;

revoke execute on function public.move_boarding_pet(uuid, uuid) from public, anon;
grant execute on function public.move_boarding_pet(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
