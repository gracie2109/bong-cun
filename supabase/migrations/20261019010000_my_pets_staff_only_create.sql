-- Only staff add pets (grace, 2026-10-15). Customers keep seeing, editing and hiding the pets they own.
--
--  save_my_pet(p, p_id)   now edit-only: a call without p_id raises hint 'added_by_shop' instead of
--                         creating a pet. Staff keep adding pets in admin (register_pet).
--
-- Same signature as 20261018030000_my_pets.sql, so the client types do not change. Safe to run more than once.

-- p: { name, species_id, breed?, sex?, neutered?, birth_date?, allergies?, behavior_notes?, weight_kg? }
-- Edits a pet I am primary owner of; returns the pet id. Errors (hint): no_customer, added_by_shop
-- (no p_id: only staff add pets), invalid_name, invalid_species, invalid_sex, invalid_birth_date,
-- invalid_weight, not_found, not_primary.
create or replace function public.save_my_pet(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
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
  if v_pet is null then
    raise exception 'pets are registered by the shop' using errcode = '42501', hint = 'added_by_shop';
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

notify pgrst, 'reload schema';
