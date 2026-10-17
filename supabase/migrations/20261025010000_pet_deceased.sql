-- Before: "mark deceased" was a plain update of pets.status from the pet menu: no date, no
-- confirmation, and the pet's spa bookings, hotel bookings and booked visits stayed on the calendar.
-- After: mark_pet_deceased records the date and a note, a trigger on pets cancels what is still
-- booked for the pet (whatever path sets the status, including signing a visit with the outcome
-- "deceased"), refuses while the pet is in a kennel (hint pet_in_kennel), and restore_pet undoes a
-- mistake. pet_deceased_preview lists what will be cancelled and what staff must handle by hand.

alter table public.pets add column if not exists deceased_note text;

-- ----------------------------------------------------------------- what the status change touches
-- Not for clients: the preview and the cleanup read the same sets of rows.
create or replace function public.pet_deceased_impact(p_pet uuid) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    -- Spa bookings with a waiting line of this pet. "whole" means no other pet keeps the booking alive.
    'appointments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'code', a.code, 'start_at', a.start_at, 'branch_id', a.branch_id, 'branch_name', b.name,
        'whole', not exists (
          select 1 from public.appointment_items o
          where o.appointment_id = a.id and o.status <> 'cancelled' and o.pet_id is distinct from p_pet
        )
      ) order by a.start_at)
      from public.appointments a
      join public.branches b on b.id = a.branch_id
      where a.status = 'booked'
        and exists (select 1 from public.appointment_items i where i.appointment_id = a.id and i.pet_id = p_pet and i.status = 'waiting')
    ), '[]'::jsonb),
    -- Hotel bookings of this pet that have not started.
    'stays', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', s.id, 'code', s.code, 'start_at', s.planned_in_at, 'branch_id', s.branch_id, 'branch_name', b.name,
        'whole', not exists (
          select 1 from public.boarding_stay_pets o where o.stay_id = s.id and o.status = 'active' and o.pet_id <> p_pet
        )
      ) order by s.planned_in_at)
      from public.boarding_stays s
      join public.branches b on b.id = s.branch_id
      where s.status = 'booked'
        and exists (select 1 from public.boarding_stay_pets sp where sp.stay_id = s.id and sp.pet_id = p_pet and sp.status = 'active')
    ), '[]'::jsonb),
    -- Visits booked ahead (a re-check, for instance).
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id, 'code', v.code, 'start_at', v.scheduled_at, 'branch_id', v.branch_id, 'branch_name', b.name
      ) order by v.scheduled_at)
      from public.medical_visits v
      join public.branches b on b.id = v.branch_id
      where v.pet_id = p_pet and v.status = 'scheduled'
    ), '[]'::jsonb),
    -- The pet is in a kennel now: check it out or discharge it first, so the nights are charged right.
    'blocking', coalesce((
      select jsonb_agg(jsonb_build_object(
        'type', s.kind, 'id', s.id, 'code', s.code, 'visit_id', s.visit_id, 'branch_id', s.branch_id
      ) order by s.checked_in_at)
      from public.boarding_stays s
      where s.status = 'checked_in'
        and exists (select 1 from public.boarding_stay_pets sp where sp.stay_id = s.id and sp.pet_id = p_pet and sp.status = 'active')
    ), '[]'::jsonb),
    -- Work in progress that stays as it is: staff finish it by hand.
    'open', coalesce((
      select jsonb_agg(x.item order by x.at) from (
        select a.start_at as at, jsonb_build_object('type', 'appointment', 'id', a.id, 'code', a.code, 'status', a.status, 'branch_id', a.branch_id) as item
        from public.appointments a
        where a.status in ('checked_in', 'in_progress')
          and exists (select 1 from public.appointment_items i where i.appointment_id = a.id and i.pet_id = p_pet and i.status <> 'cancelled')
        union all
        select v.created_at, jsonb_build_object('type', 'visit', 'id', v.id, 'code', v.code, 'status', v.status, 'branch_id', v.branch_id)
        from public.medical_visits v
        where v.pet_id = p_pet and v.status in ('waiting', 'in_progress')
      ) x
    ), '[]'::jsonb)
  );
$$;
revoke all on function public.pet_deceased_impact(uuid) from public, anon, authenticated;

create or replace function public.pet_deceased_preview(p_pet uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (coalesce((select public.is_admin()), false) or coalesce((select public.has_permission('pets', 'VIEW')), false)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not exists (select 1 from public.pets where id = p_pet) then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  return public.pet_deceased_impact(p_pet);
end;
$$;
revoke all on function public.pet_deceased_preview(uuid) from public, anon;
grant execute on function public.pet_deceased_preview(uuid) to authenticated;

-- ----------------------------------------------------------------- the cleanup
-- Cancels what is still booked for the pet. Called by the trigger below, never by a client.
create or replace function public.pet_deceased_cleanup(p_pet uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_reason constant text := 'Thú đã mất';
begin
  -- Spa: the pet's waiting lines go; a booking left with no line is cancelled.
  update public.appointment_items i set status = 'cancelled'
  from public.appointments a
  where i.appointment_id = a.id and a.status = 'booked' and i.pet_id = p_pet and i.status = 'waiting';
  update public.appointments a set status = 'cancelled', cancelled_at = now(), cancel_reason = c_reason
  where a.status = 'booked'
    and exists (select 1 from public.appointment_items i where i.appointment_id = a.id and i.pet_id = p_pet)
    and not exists (select 1 from public.appointment_items i where i.appointment_id = a.id and i.status <> 'cancelled');

  -- Hotel: the pet leaves its booked stays; a stay left with no pet is cancelled.
  update public.boarding_stay_pets sp set status = 'cancelled'
  from public.boarding_stays s
  where sp.stay_id = s.id and s.status = 'booked' and sp.pet_id = p_pet and sp.status = 'active';
  update public.boarding_stays s set status = 'cancelled', cancelled_at = now(), cancel_reason = c_reason
  where s.status = 'booked'
    and exists (select 1 from public.boarding_stay_pets sp where sp.stay_id = s.id and sp.pet_id = p_pet)
    and not exists (select 1 from public.boarding_stay_pets sp where sp.stay_id = s.id and sp.status = 'active');

  -- Visits booked ahead.
  update public.medical_visits v set status = 'cancelled', cancelled_at = now(), cancel_reason = c_reason
  where v.pet_id = p_pet and v.status = 'scheduled';
end;
$$;
revoke all on function public.pet_deceased_cleanup(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------- the trigger
create or replace function public.pets_deceased_before() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'deceased' and old.status is distinct from 'deceased' then
    if exists (
      select 1 from public.boarding_stay_pets sp
      join public.boarding_stays s on s.id = sp.stay_id
      where sp.pet_id = new.id and sp.status = 'active' and s.status = 'checked_in'
    ) then
      raise exception 'the pet is still in a kennel' using errcode = 'P0001', hint = 'pet_in_kennel';
    end if;
    new.deceased_on := coalesce(new.deceased_on, public.business_date());
    if new.deceased_on > public.business_date() or (new.birth_date is not null and new.deceased_on < new.birth_date) then
      raise exception 'bad date of death' using errcode = '22023', hint = 'bad_input';
    end if;
  elsif old.status = 'deceased' and new.status is distinct from 'deceased' then
    new.deceased_on := null;
    new.deceased_note := null;
  end if;
  return new;
end;
$$;

create or replace function public.pets_deceased_after() returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.pet_deceased_cleanup(new.id);
  return new;
end;
$$;

drop trigger if exists pets_deceased_before on public.pets;
create trigger pets_deceased_before before update of status on public.pets
  for each row execute function public.pets_deceased_before();
drop trigger if exists pets_deceased_after on public.pets;
create trigger pets_deceased_after after update of status on public.pets
  for each row when (new.status = 'deceased' and old.status is distinct from 'deceased')
  execute function public.pets_deceased_after();

-- ----------------------------------------------------------------- the RPCs
-- p: deceased_on (default today), note. Returns what was cancelled.
create or replace function public.mark_pet_deceased(p_pet uuid, p jsonb default '{}'::jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pet    public.pets;
  v_impact jsonb;
begin
  if not (coalesce((select public.is_admin()), false) or coalesce((select public.has_permission('pets', 'UPDATE')), false)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_pet from public.pets where id = p_pet for update;
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_pet.status = 'deceased' then
    raise exception 'the pet is already marked deceased' using errcode = 'P0001', hint = 'already_done';
  end if;
  v_impact := public.pet_deceased_impact(p_pet);
  if jsonb_array_length(v_impact -> 'blocking') > 0 then
    raise exception 'the pet is still in a kennel' using errcode = 'P0001', hint = 'pet_in_kennel';
  end if;

  update public.pets set
    status = 'deceased',
    deceased_on = coalesce(nullif(p ->> 'deceased_on', '')::date, public.business_date()),
    deceased_note = nullif(btrim(p ->> 'note'), '')
  where id = p_pet;

  return jsonb_build_object('cancelled', jsonb_build_object(
    'appointments', jsonb_array_length(v_impact -> 'appointments'),
    'stays', jsonb_array_length(v_impact -> 'stays'),
    'visits', jsonb_array_length(v_impact -> 'visits')
  ));
end;
$$;
revoke all on function public.mark_pet_deceased(uuid, jsonb) from public, anon;
grant execute on function public.mark_pet_deceased(uuid, jsonb) to authenticated;

-- A mistake: the pet is active again. Cancelled bookings stay cancelled.
create or replace function public.restore_pet(p_pet uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if not (coalesce((select public.is_admin()), false) or coalesce((select public.has_permission('pets', 'UPDATE')), false)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select status into v_status from public.pets where id = p_pet for update;
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_status = 'active' then
    raise exception 'the pet is active' using errcode = 'P0001', hint = 'already_done';
  end if;
  update public.pets set status = 'active' where id = p_pet;
end;
$$;
revoke all on function public.restore_pet(uuid) from public, anon;
grant execute on function public.restore_pet(uuid) to authenticated;
