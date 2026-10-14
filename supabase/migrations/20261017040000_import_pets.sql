-- Data import/export, step 4: import_pets (docs/nhap-xuat-du-lieu.md, 6.2). Safe to run more than once.
--
--  p_rows: [{ row, owner_phone, owner_name, owner_email, owner_note, pet_name, species, breed,
--  sex ('male'|'female'|'unknown'|null), neutered (bool|null), birth_date ('yyyy-mm-dd'|null),
--  microchip, allergies, behavior_notes }], at most 500, one element per file line.
--
--  The customer is found by the digits of owner_phone (created when new, which needs owner_name).
--  A row without pet_name only creates / updates the customer. A pet is found by microchip, else by
--  (primary owner, name); it is created when missing. An empty cell never clears a value, a
--  microchip never moves a pet to another customer, and species are never created here (a species
--  carries weight brackets and prices). Rows are saved one by one so later rows see earlier ones.
--  With p_dry_run (default) everything is checked and rolled back; a real run writes only when every
--  row is fine. Needs the "pets: IMPORT" method. Never deletes.

create or replace function public.import_pets(p_rows jsonb, p_dry_run boolean default true)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if not (coalesce((select public.is_admin()), false) or coalesce((select public.has_permission('pets', 'IMPORT')), false)) then
    raise exception 'not allowed to import pets' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'rows must be a list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 500 then
    raise exception 'at most 500 rows per call' using errcode = '22023', hint = 'too_many_rows';
  end if;

  if p_dry_run then
    begin
      v_result := public.import_pets_run(p_rows);
      raise exception 'dry run' using errcode = 'P0099';
    exception when sqlstate 'P0099' then
      return v_result;
    end;
  end if;

  v_result := public.import_pets_run(p_rows);
  if not (v_result ->> 'ok')::boolean then
    raise exception 'the file has errors' using errcode = '22023', hint = 'import_invalid';
  end if;
  return v_result;
end;
$$;

-- The work for one row; returns { action, customer: 'created'|'updated'|null } or raises.
create or replace function public.import_pets_row(p_row jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_phone    text := btrim(coalesce(p_row ->> 'owner_phone', ''));
  v_digits   text := regexp_replace(coalesce(p_row ->> 'owner_phone', ''), '\D', '', 'g');
  v_name     text := nullif(btrim(coalesce(p_row ->> 'owner_name', '')), '');
  v_email    text := nullif(btrim(coalesce(p_row ->> 'owner_email', '')), '');
  v_note     text := nullif(btrim(coalesce(p_row ->> 'owner_note', '')), '');
  v_pet_name text := nullif(btrim(coalesce(p_row ->> 'pet_name', '')), '');
  v_species  text := nullif(btrim(coalesce(p_row ->> 'species', '')), '');
  v_breed    text := nullif(btrim(coalesce(p_row ->> 'breed', '')), '');
  v_sex      text := nullif(btrim(coalesce(p_row ->> 'sex', '')), '');
  v_chip     text := nullif(btrim(coalesce(p_row ->> 'microchip', '')), '');
  v_allergy  text := nullif(btrim(coalesce(p_row ->> 'allergies', '')), '');
  v_behavior text := nullif(btrim(coalesce(p_row ->> 'behavior_notes', '')), '');
  v_neutered boolean := case when p_row ->> 'neutered' is null then null else (p_row ->> 'neutered')::boolean end;
  v_birth    date := nullif(btrim(coalesce(p_row ->> 'birth_date', '')), '')::date;
  v_customer uuid;
  v_cust_act text;
  v_species_id uuid;
  v_pet      uuid;
  v_pet_owner uuid;
  v_action   text;
begin
  if length(v_digits) not between 8 and 15 then
    raise exception 'Số điện thoại chủ cần 8 đến 15 chữ số' using errcode = '22023';
  end if;
  if v_sex is not null and v_sex not in ('male', 'female', 'unknown') then
    raise exception 'Giới tính chỉ nhận Đực, Cái hoặc Không rõ' using errcode = '22023';
  end if;
  if v_birth is not null and v_birth > current_date then
    raise exception 'Ngày sinh không được ở tương lai' using errcode = '22023';
  end if;

  -- customer
  select id into v_customer from public.customers where phone_digits = v_digits;
  if v_customer is null then
    if v_name is null then
      raise exception 'Khách mới cần có tên chủ' using errcode = '22023';
    end if;
    insert into public.customers (full_name, phone, email, note)
    values (v_name, v_phone, v_email, v_note)
    returning id into v_customer;
    v_cust_act := 'created';
  else
    update public.customers
    set full_name = coalesce(v_name, full_name),
        email     = coalesce(v_email, email),
        note      = coalesce(v_note, note)
    where id = v_customer;
    v_cust_act := 'updated';
  end if;

  if v_pet_name is null then
    return jsonb_build_object('action', case when v_cust_act = 'created' then 'create' else 'update' end, 'customer', v_cust_act);
  end if;

  -- species (never created from a file)
  if v_species is not null then
    select id into v_species_id from public.species
    where lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_species));
    if v_species_id is null then
      raise exception 'Loài chưa có: %', v_species using errcode = '22023';
    end if;
  end if;

  -- pet: by microchip, else by (primary owner, name)
  if v_chip is not null then
    select id into v_pet from public.pets where microchip = v_chip;
    if v_pet is not null then
      select po.customer_id into v_pet_owner from public.pet_owners po
      where po.pet_id = v_pet and po.role = 'primary' and po.to_date is null;
      if v_pet_owner is distinct from v_customer then
        raise exception 'Microchip đã thuộc thú cưng của khách khác' using errcode = '22023';
      end if;
    end if;
  end if;
  if v_pet is null then
    select p.id into v_pet
    from public.pets p
    join public.pet_owners po on po.pet_id = p.id and po.role = 'primary' and po.to_date is null
    where po.customer_id = v_customer
      and lower(btrim(p.name)) = lower(v_pet_name)
      and (v_chip is null or p.microchip is null)
    order by p.created_at
    limit 1;
  end if;

  if v_pet is null then
    if v_species_id is null then
      raise exception 'Thú cưng mới cần có loài' using errcode = '22023';
    end if;
    insert into public.pets (species_id, name, breed, sex, neutered, birth_date, microchip, allergies, behavior_notes)
    values (v_species_id, v_pet_name, v_breed, coalesce(v_sex, 'unknown'), coalesce(v_neutered, false), v_birth, v_chip, v_allergy, v_behavior)
    returning id into v_pet;
    insert into public.pet_owners (pet_id, customer_id, role) values (v_pet, v_customer, 'primary');
    v_action := 'create';
  else
    update public.pets
    set species_id      = coalesce(v_species_id, species_id),
        breed           = coalesce(v_breed, breed),
        sex             = coalesce(v_sex, sex),
        neutered        = coalesce(v_neutered, neutered),
        birth_date      = coalesce(v_birth, birth_date),
        microchip       = coalesce(v_chip, microchip),
        allergies       = coalesce(v_allergy, allergies),
        behavior_notes  = coalesce(v_behavior, behavior_notes)
    where id = v_pet;
    v_action := 'update';
  end if;
  return jsonb_build_object('action', v_action, 'customer', v_cust_act);
end;
$$;

-- Runs every row in its own sub-transaction so a bad row leaves no trace, and collects the answer.
create or replace function public.import_pets_run(p_rows jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item     record;
  v_one      jsonb;
  v_out      jsonb := '[]'::jsonb;
  v_ok       boolean := true;
  v_created  int := 0;
  v_updated  int := 0;
  v_c_cust   int := 0;
  v_u_cust   int := 0;
  v_msg      text;
  v_state    text;
  v_note     text;
begin
  for v_item in select r, ord from jsonb_array_elements(p_rows) with ordinality as t(r, ord) order by ord loop
    begin
      v_one := public.import_pets_row(v_item.r);
      if v_one ->> 'action' = 'create' then v_created := v_created + 1; else v_updated := v_updated + 1; end if;
      if v_one ->> 'customer' = 'created' then v_c_cust := v_c_cust + 1;
      elsif v_one ->> 'customer' = 'updated' then v_u_cust := v_u_cust + 1; end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('row', v_item.r ->> 'row', 'action', v_one ->> 'action', 'errors', '[]'::jsonb));
    exception when others then
      get stacked diagnostics v_msg = message_text;
      v_state := sqlstate;
      if v_state = '42501' then raise; end if;
      v_note := case v_state
        when '23505' then 'Microchip hoặc số điện thoại đã được dùng ở dòng khác'
        when '22007' then 'Ngày sinh không đọc được'
        when '22008' then 'Ngày sinh không đọc được'
        when '22P02' then 'Có ô không đúng định dạng'
        else v_msg
      end;
      v_ok := false;
      v_out := v_out || jsonb_build_array(jsonb_build_object('row', v_item.r ->> 'row', 'action', 'skip', 'errors', jsonb_build_array(v_note)));
    end;
  end loop;

  return jsonb_build_object(
    'ok', v_ok,
    'created', v_created,
    'updated', v_updated,
    'rows', v_out,
    'extra', jsonb_build_object('created_customers', v_c_cust, 'updated_customers', v_u_cust)
  );
end;
$$;

revoke execute on function public.import_pets_row(jsonb) from public, anon, authenticated;
revoke execute on function public.import_pets_run(jsonb) from public, anon, authenticated;
revoke execute on function public.import_pets(jsonb, boolean) from public, anon;
grant execute on function public.import_pets(jsonb, boolean) to authenticated;

notify pgrst, 'reload schema';
