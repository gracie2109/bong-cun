-- Spa appointments, step 2: check-in with the real weight (locks the price), ticket progress
-- (waiting -> in progress -> done) and no-show. Run after 20261013030000_spa_appointments.sql.
-- Re-runnable.

-- ------------------------------------------------------------------- status
-- The appointment's status follows its tickets once the pet has arrived: any ticket in progress
-- makes it in_progress, every live ticket done makes it done, otherwise it is checked_in.
create or replace function public.refresh_appointment_status(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_live int;
  v_done int;
  v_busy int;
begin
  select count(*) filter (where status <> 'cancelled'),
         count(*) filter (where status = 'done'),
         count(*) filter (where status = 'in_progress')
  into v_live, v_done, v_busy
  from public.appointment_items where appointment_id = p_id;

  update public.appointments set status = case
    when v_busy > 0 then 'in_progress'
    when v_live > 0 and v_done = v_live then 'done'
    else 'checked_in'
  end
  where id = p_id and status in ('checked_in', 'in_progress', 'done');
end;
$$;

revoke execute on function public.refresh_appointment_status(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------- check-in
-- p_weights: [{ "pet_id": uuid, "weight_kg": number }]. Every by-weight ticket needs its pet's
-- weight; the weight is also saved to the pet's weight log. The price on each ticket is fixed here:
-- later catalog changes do not move it.
create or replace function public.check_in_appointment(p_id uuid, p_weights jsonb default '[]'::jsonb) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt    public.appointments;
  v_item    public.appointment_items;
  v_service public.pet_services;
  v_combo   public.pet_service_combos;
  v_species uuid;
  v_weight  numeric;
  v_price   numeric;
  v_given   jsonb;
  v_logged  uuid[] := '{}';
begin
  select * into v_appt from public.appointments where id = p_id for update;
  if not found then
    raise exception 'appointment % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_schedule('CREATE', v_appt.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_appt.status <> 'booked' then
    raise exception 'only a booked appointment can be checked in' using errcode = 'P0001', hint = 'not_editable';
  end if;

  for v_item in
    select * from public.appointment_items
    where appointment_id = p_id and status <> 'cancelled'
    order by line_no
  loop
    if v_item.pet_id is null then
      raise exception 'pick the pet before check-in' using errcode = '22023', hint = 'no_pet';
    end if;
    select species_id into v_species from public.pets where id = v_item.pet_id;

    select e into v_given
    from jsonb_array_elements(coalesce(p_weights, '[]'::jsonb)) e
    where e ->> 'pet_id' = v_item.pet_id::text
    limit 1;
    v_weight := nullif(v_given ->> 'weight_kg', '')::numeric;
    if v_weight is not null and v_weight <= 0 then
      raise exception 'weight must be positive' using errcode = '22023', hint = 'need_weight', detail = v_item.name;
    end if;

    if v_weight is not null and not (v_item.pet_id = any (v_logged)) then
      insert into public.pet_weight_logs (pet_id, weight_kg) values (v_item.pet_id, v_weight);
      v_logged := v_logged || v_item.pet_id;
    end if;

    if v_item.item_type = 'combo' then
      select * into v_combo from public.pet_service_combos where id = v_item.combo_id;
      v_price := v_combo.price;
    else
      select * into v_service from public.pet_services where id = v_item.service_id;
      if v_service.type = 'by_weight' then
        if v_weight is null then
          raise exception 'weight needed for %', v_item.name using errcode = '22023', hint = 'need_weight', detail = v_item.name;
        end if;
        v_price := public.get_service_price(v_species, v_item.service_id, v_weight, v_appt.branch_id);
        if v_price is null then
          raise exception 'no price for %', v_item.name using errcode = 'P0001', hint = 'no_price', detail = v_item.name;
        end if;
      else
        v_price := v_service.general_price;
      end if;
    end if;

    update public.appointment_items
    set weight_kg = coalesce(v_weight, weight_kg), unit_price = v_price
    where id = v_item.id;
  end loop;

  update public.appointments set status = 'checked_in', checked_in_at = now() where id = p_id;
end;
$$;

revoke execute on function public.check_in_appointment(uuid, jsonb) from public, anon;
grant execute on function public.check_in_appointment(uuid, jsonb) to authenticated;

-- ------------------------------------------------------------ ticket status
-- waiting -> in_progress -> done, and one step back for a mistaken tap.
create or replace function public.set_appointment_item_status(p_item uuid, p_status text) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item public.appointment_items;
  v_appt public.appointments;
begin
  select * into v_item from public.appointment_items where id = p_item for update;
  if not found then
    raise exception 'ticket % not found', p_item using errcode = 'P0002';
  end if;
  select * into v_appt from public.appointments where id = v_item.appointment_id for update;
  if not public.can_schedule('UPDATE', v_appt.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_appt.status not in ('checked_in', 'in_progress', 'done')
     or not ((v_item.status, p_status) in (
       ('waiting', 'in_progress'), ('in_progress', 'done'), ('in_progress', 'waiting'), ('done', 'in_progress')
     )) then
    raise exception 'this ticket cannot change to %', p_status using errcode = 'P0001', hint = 'bad_status';
  end if;

  update public.appointment_items set status = p_status where id = p_item;
  perform public.refresh_appointment_status(v_appt.id);
end;
$$;

revoke execute on function public.set_appointment_item_status(uuid, text) from public, anon;
grant execute on function public.set_appointment_item_status(uuid, text) to authenticated;

-- ------------------------------------------------------------------ no-show
-- Only for a booked appointment whose time has passed; frees the staff and table slots.
create or replace function public.mark_no_show(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_appt public.appointments;
begin
  select * into v_appt from public.appointments where id = p_id for update;
  if not found then
    raise exception 'appointment % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_schedule('UPDATE', v_appt.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_appt.status <> 'booked' then
    raise exception 'only a booked appointment can be a no-show' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_appt.start_at > now() then
    raise exception 'the appointment time has not come yet' using errcode = 'P0001', hint = 'not_due';
  end if;

  update public.appointment_items set status = 'cancelled' where appointment_id = p_id;
  update public.appointments set status = 'no_show' where id = p_id;
end;
$$;

revoke execute on function public.mark_no_show(uuid) from public, anon;
grant execute on function public.mark_no_show(uuid) to authenticated;

-- -------------------------------------------------------------- one appointment
create or replace function public.get_appointment(p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_appt   public.appointments;
  v_result jsonb;
begin
  select * into v_appt from public.appointments where id = p_id;
  if not found then
    return null;
  end if;
  -- list_appointments checks the permission and builds the same shape as the list.
  v_result := public.list_appointments(v_appt.branch_id, null, null, null, v_appt.code, 1, 100);
  return (select r from jsonb_array_elements(v_result -> 'rows') r where r ->> 'id' = p_id::text limit 1);
end;
$$;

revoke execute on function public.get_appointment(uuid) from public, anon;
grant execute on function public.get_appointment(uuid) to authenticated;

notify pgrst, 'reload schema';
