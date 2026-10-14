-- Customer UI, step 5 (1/2): "my pets" for the signed-in web account (docs/giao-dien-khach-hang.md, 3.4).
--
--  my_pets()                 the pets I currently own (pet_owners.to_date is null), staff-made ones included.
--  save_my_pet(p, p_id)      add a pet (I become its primary owner) or edit one I am primary owner of;
--                            a changed weight is logged in pet_weight_logs.
--  hide_my_pet(p_id)         close my ownership link; the pet and its history stay. Refused while an
--                            appointment that is not finished yet includes the pet.
--
-- Everything goes through my_customer_id(); customers, pets and pet_owners stay staff-only under RLS.
-- microchip and status are never touched here (staff only). Safe to run more than once.

create or replace function public.my_pets() returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_cust uuid := public.my_customer_id();
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(
             jsonb_build_object(
               'id', p.id,
               'name', p.name,
               'species_id', p.species_id,
               'species_name', s.name,
               'breed', p.breed,
               'sex', p.sex,
               'neutered', p.neutered,
               'birth_date', p.birth_date,
               'allergies', p.allergies,
               'behavior_notes', p.behavior_notes,
               'weight_kg', (
                 select l.weight_kg from public.pet_weight_logs l
                 where l.pet_id = p.id order by l.measured_at desc limit 1
               ),
               'role', po.role,
               'can_edit', po.role = 'primary',
               'has_open_appointment', exists (
                 select 1
                 from public.appointment_items ai
                 join public.appointments a on a.id = ai.appointment_id
                 where ai.pet_id = p.id and a.status in ('booked', 'checked_in', 'in_progress')
               )
             )
             order by lower(p.name), p.created_at
           )
    from public.pet_owners po
    join public.pets p on p.id = po.pet_id
    join public.species s on s.id = p.species_id
    where po.customer_id = v_cust and po.to_date is null and p.status = 'active'
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.my_pets() from public, anon;
grant execute on function public.my_pets() to authenticated;

-- p: { name, species_id, breed?, sex?, neutered?, birth_date?, allergies?, behavior_notes?, weight_kg? }
-- Returns the pet id. Errors (hint): no_customer, invalid_name, invalid_species, invalid_sex,
-- invalid_birth_date, invalid_weight, too_many_pets, not_found, not_primary.
create or replace function public.save_my_pet(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_max_pets constant int := 20;
  v_uid    uuid := auth.uid();
  v_cust   uuid := public.my_customer_id();
  v_name   text := btrim(coalesce(p ->> 'name', ''));
  v_sex    text := coalesce(nullif(btrim(coalesce(p ->> 'sex', '')), ''), 'unknown');
  v_birth  date;
  v_weight numeric;
  v_species uuid;
  v_pet    uuid := p_id;
  v_last   numeric;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  if length(v_name) = 0 or length(v_name) > 80 then
    raise exception 'name is required' using errcode = '22023', hint = 'invalid_name';
  end if;
  if v_sex not in ('male', 'female', 'unknown') then
    raise exception 'invalid sex' using errcode = '22023', hint = 'invalid_sex';
  end if;
  begin
    v_species := nullif(btrim(coalesce(p ->> 'species_id', '')), '')::uuid;
  exception when others then
    v_species := null;
  end;
  if v_species is null or not exists (select 1 from public.species where id = v_species and is_active) then
    raise exception 'pick a species' using errcode = '22023', hint = 'invalid_species';
  end if;
  begin
    v_birth := nullif(btrim(coalesce(p ->> 'birth_date', '')), '')::date;
  exception when others then
    raise exception 'birth date is not a date' using errcode = '22023', hint = 'invalid_birth_date';
  end;
  if v_birth is not null and (v_birth > current_date or v_birth < date '1990-01-01') then
    raise exception 'birth date is out of range' using errcode = '22023', hint = 'invalid_birth_date';
  end if;
  begin
    v_weight := nullif(btrim(coalesce(p ->> 'weight_kg', '')), '')::numeric;
  exception when others then
    raise exception 'weight is not a number' using errcode = '22023', hint = 'invalid_weight';
  end;
  if v_weight is not null and (v_weight <= 0 or v_weight >= 1000) then
    raise exception 'weight is out of range' using errcode = '22023', hint = 'invalid_weight';
  end if;

  if v_pet is null then
    if (select count(*) from public.pet_owners po join public.pets x on x.id = po.pet_id
        where po.customer_id = v_cust and po.to_date is null and x.status = 'active') >= c_max_pets then
      raise exception 'too many pets' using errcode = '22023', hint = 'too_many_pets';
    end if;
    insert into public.pets (species_id, name, breed, sex, neutered, birth_date, allergies, behavior_notes)
    values (
      v_species, v_name,
      nullif(btrim(coalesce(p ->> 'breed', '')), ''),
      v_sex,
      coalesce((p ->> 'neutered')::boolean, false),
      v_birth,
      nullif(btrim(coalesce(p ->> 'allergies', '')), ''),
      nullif(btrim(coalesce(p ->> 'behavior_notes', '')), '')
    )
    returning id into v_pet;
    insert into public.pet_owners (pet_id, customer_id, role) values (v_pet, v_cust, 'primary');
  else
    if not exists (
      select 1 from public.pet_owners po join public.pets x on x.id = po.pet_id
      where po.pet_id = v_pet and po.customer_id = v_cust and po.to_date is null and x.status = 'active'
    ) then
      raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
    end if;
    if not exists (
      select 1 from public.pet_owners po
      where po.pet_id = v_pet and po.customer_id = v_cust and po.to_date is null and po.role = 'primary'
    ) then
      raise exception 'only the primary owner can edit' using errcode = '42501', hint = 'not_primary';
    end if;
    update public.pets
       set species_id = v_species,
           name = v_name,
           breed = nullif(btrim(coalesce(p ->> 'breed', '')), ''),
           sex = v_sex,
           neutered = coalesce((p ->> 'neutered')::boolean, false),
           birth_date = v_birth,
           allergies = nullif(btrim(coalesce(p ->> 'allergies', '')), ''),
           behavior_notes = nullif(btrim(coalesce(p ->> 'behavior_notes', '')), ''),
           updated_at = now()
     where id = v_pet;
  end if;

  if v_weight is not null then
    select l.weight_kg into v_last
    from public.pet_weight_logs l where l.pet_id = v_pet order by l.measured_at desc limit 1;
    if v_last is distinct from v_weight then
      insert into public.pet_weight_logs (pet_id, weight_kg, note) values (v_pet, v_weight, 'web');
    end if;
  end if;
  return v_pet;
end;
$$;

revoke execute on function public.save_my_pet(jsonb, uuid) from public, anon;
grant execute on function public.save_my_pet(jsonb, uuid) to authenticated;

-- Errors (hint): no_customer, not_found, has_open_appointment.
create or replace function public.hide_my_pet(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := auth.uid();
  v_cust uuid := public.my_customer_id();
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  if not exists (
    select 1 from public.pet_owners po
    where po.pet_id = p_id and po.customer_id = v_cust and po.to_date is null
  ) then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if exists (
    select 1
    from public.appointment_items ai
    join public.appointments a on a.id = ai.appointment_id
    where ai.pet_id = p_id and a.status in ('booked', 'checked_in', 'in_progress')
  ) then
    raise exception 'the pet has an appointment that is not finished' using errcode = '22023', hint = 'has_open_appointment';
  end if;
  update public.pet_owners
     set to_date = current_date
   where pet_id = p_id and customer_id = v_cust and to_date is null;
end;
$$;

revoke execute on function public.hide_my_pet(uuid) from public, anon;
grant execute on function public.hide_my_pet(uuid) to authenticated;

notify pgrst, 'reload schema';
