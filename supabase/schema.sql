


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."add_boarding_extra"("p_stay_pet" "uuid", "p_service" "uuid", "p_qty" numeric DEFAULT 1) RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_sp      public.boarding_stay_pets;
  v_status  text;
  v_service public.pet_services;
  v_species uuid;
  v_price   numeric;
  v_qty     numeric := coalesce(p_qty, 1);
  v_id      uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = p_stay_pet;
  if not found then
    raise exception 'pet of stay % not found', p_stay_pet using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('CREATE', v_sp.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select status into v_status from public.boarding_stays where id = v_sp.stay_id;
  if exists (select 1 from public.boarding_stays where id = v_sp.stay_id and kind = 'inpatient') then
    raise exception 'an inpatient stay is managed on the inpatient screen' using errcode = 'P0001', hint = 'inpatient_stay';
  end if;
  if v_status <> 'checked_in' or v_sp.status <> 'active' then
    raise exception 'the pet is not in the hotel' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_qty <= 0 or v_qty > 999 then
    raise exception 'bad quantity' using errcode = '22023', hint = 'bad_input';
  end if;

  select * into v_service from public.pet_services where id = p_service and is_active;
  if not found then
    raise exception 'service is not available' using errcode = 'P0002', hint = 'no_service';
  end if;
  select species_id into v_species from public.pets where id = v_sp.pet_id;
  if exists (select 1 from public.service_species where service_id = v_service.id)
     and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
    raise exception 'the service is not for this species' using errcode = '22023', hint = 'species_not_allowed', detail = v_sp.pet_name;
  end if;
  v_price := public.get_service_price(v_species, v_service.id, coalesce(v_sp.weight_kg, 0), v_sp.branch_id);
  if v_price is null then
    raise exception 'no price for this service' using errcode = 'P0001', hint = 'no_price', detail = v_service.name;
  end if;

  insert into public.boarding_charges (
    stay_id, stay_pet_id, branch_id, kind, service_id, name, qty, unit_price, amount, created_by
  )
  values (
    v_sp.stay_id, p_stay_pet, v_sp.branch_id, 'extra', v_service.id, v_service.name,
    v_qty, v_price, round(v_price * v_qty, 2), (select auth.uid())
  )
  returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_boarding_extra"("p_stay_pet" "uuid", "p_service" "uuid", "p_qty" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_care_log"("p_stay_pet" "uuid", "p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_sp      public.boarding_stay_pets;
  v_status  text;
  v_kind    text := p ->> 'kind';
  v_eaten   text := nullif(p ->> 'meal_eaten', '');
  v_content text := nullif(btrim(p ->> 'content'), '');
  v_id      uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = p_stay_pet;
  if not found then
    raise exception 'pet of stay % not found', p_stay_pet using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('CREATE', v_sp.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select status into v_status from public.boarding_stays where id = v_sp.stay_id;
  if v_status <> 'checked_in' or v_sp.status <> 'active' then
    raise exception 'the pet is not in the hotel' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_kind is null or v_kind not in ('meal', 'walk', 'potty', 'medication', 'note')
     or (v_kind = 'meal' and (v_eaten is null or v_eaten not in ('all', 'some', 'none')))
     or (v_kind <> 'meal' and v_content is null) then
    raise exception 'bad care log' using errcode = '22023', hint = 'bad_input';
  end if;

  insert into public.boarding_care_logs (
    stay_pet_id, stay_id, branch_id, kind, meal_eaten, content, visible_to_customer, created_by
  )
  values (
    p_stay_pet, v_sp.stay_id, v_sp.branch_id, v_kind,
    case when v_kind = 'meal' then v_eaten end,
    v_content,
    coalesce((p ->> 'visible_to_customer')::boolean, true),
    (select auth.uid())
  )
  returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_care_log"("p_stay_pet" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_external_vaccination"("p_pet" "uuid", "p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid   uuid := (select auth.uid());
  v_type  public.vaccine_types;
  v_given date := nullif(p ->> 'given_on', '')::date;
  v_dose  int;
  v_due   date;
  v_id    uuid;
begin
  if not public.can_medical('CREATE') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if not exists (select 1 from public.pets where id = p_pet) then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_type from public.vaccine_types where id = nullif(p ->> 'vaccine_type_id', '')::uuid and is_active;
  if not found then
    raise exception 'vaccine type is not available' using errcode = 'P0002', hint = 'no_vaccine';
  end if;
  if v_given is null then
    raise exception 'the day of the shot is needed' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_given > public.business_date() then
    raise exception 'the shot cannot be in the future' using errcode = '22023', hint = 'future_date';
  end if;
  v_dose := coalesce(nullif(p ->> 'dose_no', '')::int, public.medical_next_dose_no(p_pet, v_type.id));
  if v_dose <= 0 then
    raise exception 'bad dose number' using errcode = '22023', hint = 'bad_input';
  end if;
  v_due := case when p ? 'next_due_on' then nullif(p ->> 'next_due_on', '')::date
                else public.medical_next_due(v_type.id, v_dose, v_given) end;

  insert into public.vaccinations (
    pet_id, vaccine_type_id, dose_no, given_on, lot_no, expiry_date, is_external, external_place,
    vet_name, next_due_on, created_by
  ) values (
    p_pet, v_type.id, v_dose, v_given, nullif(btrim(p ->> 'lot_no'), ''), nullif(p ->> 'expiry_date', '')::date,
    true, nullif(btrim(p ->> 'external_place'), ''), nullif(btrim(p ->> 'vet_name'), ''), v_due, v_uid
  ) returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_external_vaccination"("p_pet" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_inpatient_log"("p_stay_pet" "uuid", "p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_sp      public.boarding_stay_pets;
  v_stay    public.boarding_stays;
  v_kind    text := p ->> 'kind';
  v_content text := nullif(btrim(p ->> 'content'), '');
  v_id      uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = p_stay_pet;
  if not found then
    raise exception 'pet of stay not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_stay from public.boarding_stays where id = v_sp.stay_id;
  if not public.can_medical('UPDATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.kind <> 'inpatient' or v_stay.status <> 'checked_in' then
    raise exception 'the pet is not an in-patient' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_kind not in ('vitals', 'treatment', 'note') or v_content is null then
    raise exception 'bad log' using errcode = '22023', hint = 'bad_input';
  end if;
  insert into public.boarding_care_logs (stay_pet_id, stay_id, branch_id, kind, content, visible_to_customer, created_by)
  values (p_stay_pet, v_sp.stay_id, v_sp.branch_id, v_kind, v_content, false, (select auth.uid()))
  returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_inpatient_log"("p_stay_pet" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_medical_addendum"("p_id" "uuid", "p_content" "text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid     uuid := (select auth.uid());
  v_visit   public.medical_visits;
  v_content text := nullif(btrim(p_content), '');
  v_id      uuid;
begin
  select * into v_visit from public.medical_visits where id = p_id;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.signed_at is null then
    raise exception 'only a signed visit takes an addendum' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_content is null then
    raise exception 'the addendum is empty' using errcode = '22023', hint = 'bad_input';
  end if;
  insert into public.medical_addenda (visit_id, content, created_by, created_by_name)
  values (p_id, v_content, v_uid, public.staff_display_name(v_uid))
  returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_medical_addendum"("p_id" "uuid", "p_content" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_medical_attachment"("p_visit" "uuid", "p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid   uuid := (select auth.uid());
  v_visit public.medical_visits;
  v_path  text := btrim(coalesce(p ->> 'file_path', ''));
  v_id    uuid;
begin
  select * into v_visit from public.medical_visits where id = p_visit;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status in ('cancelled', 'no_show', 'scheduled') then
    raise exception 'the visit cannot take files' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_path not like v_visit.pet_id::text || '/' || v_visit.id::text || '/%' then
    raise exception 'bad file path' using errcode = '22023', hint = 'bad_input';
  end if;

  insert into public.medical_attachments (
    visit_id, pet_id, kind, title, file_path, mime_type, size_bytes, created_by, created_by_name
  ) values (
    v_visit.id, v_visit.pet_id, coalesce(nullif(p ->> 'kind', ''), 'other'),
    btrim(coalesce(p ->> 'title', '')), v_path, coalesce(p ->> 'mime_type', ''),
    coalesce(nullif(p ->> 'size_bytes', '')::bigint, 0), v_uid, public.staff_display_name(v_uid)
  )
  returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."add_medical_attachment"("p_visit" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_medical_item"("p_visit" "uuid", "p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid      uuid := (select auth.uid());
  v_visit    public.medical_visits;
  v_kind     text := p ->> 'kind';
  v_qty      numeric := coalesce(nullif(p ->> 'qty', '')::numeric, 1);
  v_service  public.pet_services;
  v_product  public.products;
  v_unit     public.product_units;
  v_species  uuid;
  v_name     text;
  v_price    numeric := 0;
  v_factor   numeric := 1;
  v_unit_name text;
  v_days     int := nullif(p ->> 'days', '')::int;
  v_id       uuid;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into v_visit from public.medical_visits where id = p_visit for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status not in ('in_progress', 'done', 'paid') then
    raise exception 'the visit is not open' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_kind is null or v_kind not in ('service', 'product', 'external') or v_qty <= 0 or v_qty > 999
     or (v_days is not null and v_days <= 0) then
    raise exception 'bad line' using errcode = '22023', hint = 'bad_input';
  end if;

  select species_id into v_species from public.pets where id = v_visit.pet_id;

  if v_kind = 'service' then
    select * into v_service from public.pet_services
    where id = nullif(p ->> 'service_id', '')::uuid and is_active and category = 'medical';
    if not found then
      raise exception 'service is not available' using errcode = 'P0002', hint = 'no_service';
    end if;
    if exists (select 1 from public.service_species where service_id = v_service.id)
       and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
      raise exception 'the service is not for this species' using errcode = '22023', hint = 'species_not_allowed', detail = v_visit.pet_name;
    end if;
    if v_service.type <> 'all' and v_visit.weight_kg is null then
      raise exception 'the weight is needed for this service' using errcode = 'P0001', hint = 'no_weight', detail = v_service.name;
    end if;
    v_price := public.get_service_price(v_species, v_service.id, coalesce(v_visit.weight_kg, 0), v_visit.branch_id);
    if v_price is null then
      raise exception 'no price for this service' using errcode = 'P0001', hint = 'no_price', detail = v_service.name;
    end if;
    v_name := v_service.name;
    v_unit_name := v_service.unit;

  elsif v_kind = 'product' then
    select * into v_product from public.products
    where id = nullif(p ->> 'product_id', '')::uuid and is_active;
    if not found then
      raise exception 'product is not available' using errcode = 'P0002', hint = 'not_available';
    end if;
    if nullif(p ->> 'unit_id', '') is not null then
      select * into v_unit from public.product_units
      where id = (p ->> 'unit_id')::uuid and product_id = v_product.id and is_active and for_sale;
      if not found then
        raise exception 'unit does not belong to the product' using errcode = '22023', hint = 'bad_unit';
      end if;
      v_factor := v_unit.factor;
      v_unit_name := v_unit.name;
    else
      v_unit_name := v_product.unit;
    end if;
    v_price := public.product_unit_price(v_product.id, v_visit.branch_id, v_unit.id);
    if v_price is null then
      raise exception 'no price for this product' using errcode = 'P0001', hint = 'no_price', detail = v_product.name;
    end if;
    v_name := v_product.name;
    if v_product.track_stock and public.medical_stock_qty(v_visit.branch_id, v_product.id) < v_qty * v_factor then
      v_warnings := v_warnings || to_jsonb('low_stock'::text);
    end if;

  else
    v_name := nullif(btrim(p ->> 'name'), '');
    if v_name is null then
      raise exception 'the medicine needs a name' using errcode = '22023', hint = 'bad_input';
    end if;
  end if;

  insert into public.medical_visit_items (
    visit_id, branch_id, kind, service_id, product_id, unit_id, unit_name, unit_factor, name, qty,
    unit_price, amount, take_home, dose, frequency, days, route, instructions, created_by, created_by_name
  ) values (
    p_visit, v_visit.branch_id, v_kind, v_service.id, v_product.id, v_unit.id, v_unit_name, v_factor, v_name, v_qty,
    v_price, round(v_price * v_qty, 2),
    -- External medicine is always for the owner to take; services are never "taken home".
    case v_kind when 'external' then true when 'service' then false else coalesce((p ->> 'take_home')::boolean, false) end,
    nullif(btrim(p ->> 'dose'), ''), nullif(btrim(p ->> 'frequency'), ''), v_days,
    nullif(btrim(p ->> 'route'), ''), nullif(btrim(p ->> 'instructions'), ''),
    v_uid, public.staff_display_name(v_uid)
  ) returning id into v_id;

  perform public.medical_refresh_status(p_visit);
  return jsonb_build_object('id', v_id, 'warnings', v_warnings);
end;
$$;


ALTER FUNCTION "public"."add_medical_item"("p_visit" "uuid", "p" "jsonb") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."customer_addresses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "receiver_name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "street" "text" NOT NULL,
    "province_name" "text" NOT NULL,
    "district_name" "text" NOT NULL,
    "ward_name" "text" NOT NULL,
    "ghn_province_id" integer NOT NULL,
    "ghn_district_id" integer NOT NULL,
    "ghn_ward_code" "text" NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "customer_addresses_district_name_check" CHECK (("length"("btrim"("district_name")) > 0)),
    CONSTRAINT "customer_addresses_ghn_ward_code_check" CHECK (("length"("btrim"("ghn_ward_code")) > 0)),
    CONSTRAINT "customer_addresses_phone_check" CHECK ((("length"("regexp_replace"("phone", '\D'::"text", ''::"text", 'g'::"text")) >= 8) AND ("length"("regexp_replace"("phone", '\D'::"text", ''::"text", 'g'::"text")) <= 15))),
    CONSTRAINT "customer_addresses_province_name_check" CHECK (("length"("btrim"("province_name")) > 0)),
    CONSTRAINT "customer_addresses_receiver_name_check" CHECK (("length"("btrim"("receiver_name")) > 0)),
    CONSTRAINT "customer_addresses_street_check" CHECK (("length"("btrim"("street")) > 0)),
    CONSTRAINT "customer_addresses_ward_name_check" CHECK (("length"("btrim"("ward_name")) > 0))
);


ALTER TABLE "public"."customer_addresses" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."address_json"("a" "public"."customer_addresses") RETURNS "jsonb"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', a.id,
    'receiver_name', a.receiver_name,
    'phone', a.phone,
    'street', a.street,
    'province_name', a.province_name,
    'district_name', a.district_name,
    'ward_name', a.ward_name,
    'ghn_province_id', a.ghn_province_id,
    'ghn_district_id', a.ghn_district_id,
    'ghn_ward_code', a.ghn_ward_code,
    'is_default', a.is_default
  );
$$;


ALTER FUNCTION "public"."address_json"("a" "public"."customer_addresses") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."admit_inpatient"("p_visit" "uuid", "p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid     uuid := (select auth.uid());
  v_visit   public.medical_visits;
  v_kennel  public.kennels;
  v_type    public.kennel_types;
  v_today   date := public.business_date();
  v_out     timestamptz := coalesce(nullif(p ->> 'planned_out_at', '')::timestamptz, now() + interval '1 day');
  v_out_date date;
  v_price   numeric;
  v_stay    uuid;
  v_sp      uuid;
  v_code    text;
begin
  select * into v_visit from public.medical_visits where id = p_visit for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status <> 'in_progress' or v_visit.signed_at is not null then
    raise exception 'the visit is not open' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if exists (select 1 from public.boarding_stays where visit_id = p_visit and kind = 'inpatient' and status in ('booked', 'checked_in')) then
    raise exception 'the pet is already admitted' using errcode = 'P0001', hint = 'already_admitted';
  end if;

  select * into v_kennel from public.kennels
  where id = nullif(p ->> 'kennel_id', '')::uuid and branch_id = v_visit.branch_id and is_active for share;
  if not found then
    raise exception 'pick a kennel' using errcode = 'P0002', hint = 'no_kennel';
  end if;
  select * into v_type from public.kennel_types where id = v_kennel.kennel_type_id;
  if v_type.purpose not in ('medical', 'isolation') then
    raise exception 'the kennel is not for in-patients' using errcode = '22023', hint = 'no_kennel';
  end if;
  if v_type.purpose <> 'isolation' and exists (
    select 1 from public.medical_diagnoses where visit_id = p_visit and is_contagious
  ) then
    raise exception 'a contagious pet needs an isolation kennel' using errcode = 'P0001', hint = 'need_isolation';
  end if;
  if v_kennel.status <> 'ready' then
    raise exception 'kennel % is not ready', v_kennel.code using errcode = 'P0001', hint = 'kennel_taken', detail = v_kennel.code;
  end if;

  v_out_date := (v_out at time zone c_tz)::date;
  if v_out <= now() then
    raise exception 'pick a later departure' using errcode = '22023', hint = 'bad_input';
  end if;
  v_price := coalesce(public.kennel_night_price(v_kennel.kennel_type_id, v_visit.branch_id), 0);
  v_code := public.next_doc_code(v_visit.branch_id, 'LT');

  begin
    insert into public.boarding_stays (
      code, branch_id, customer_id, customer_name, customer_phone, status, planned_in_at, planned_out_at,
      checked_in_at, source, note, kind, visit_id, created_by
    ) values (
      v_code, v_visit.branch_id, v_visit.customer_id, v_visit.customer_name, v_visit.customer_phone,
      'checked_in', now(), v_out, now(), 'counter', nullif(btrim(p ->> 'note'), ''), 'inpatient', p_visit, v_uid
    ) returning id into v_stay;

    insert into public.boarding_stay_pets (
      stay_id, branch_id, line_no, pet_id, pet_name, kennel_type_id, kennel_id, nights, charged_nights,
      est_night_price, night_price, weight_kg, vaccine_checked
    ) values (
      v_stay, v_visit.branch_id, 1, v_visit.pet_id, v_visit.pet_name, v_kennel.kennel_type_id, v_kennel.id,
      daterange(v_today, greatest(v_out_date, v_today + 1), '[)'), greatest(v_out_date - v_today, 1),
      v_price, v_price, v_visit.weight_kg, true
    ) returning id into v_sp;
  exception when exclusion_violation then
    raise exception 'kennel % is taken tonight', v_kennel.code using errcode = 'P0001', hint = 'kennel_taken', detail = v_kennel.code;
  end;

  update public.medical_visits set outcome = 'inpatient' where id = p_visit;
  return jsonb_build_object('stay_id', v_stay, 'stay_pet_id', v_sp, 'code', v_code);
end;
$$;


ALTER FUNCTION "public"."admit_inpatient"("p_visit" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_medical_vet"("p_id" "uuid", "p_vet" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_visit public.medical_visits;
begin
  select * into v_visit from public.medical_visits where id = p_id for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not (public.can_medical('CREATE', v_visit.branch_id) or public.can_medical('UPDATE', v_visit.branch_id)) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status not in ('scheduled', 'waiting', 'in_progress') then
    raise exception 'the visit can no longer change vet' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if p_vet is null and v_visit.status = 'in_progress' then
    raise exception 'an open case needs a vet' using errcode = '22023', hint = 'bad_vet';
  end if;
  if p_vet is not null and not public.medical_user_can_update(p_vet, v_visit.branch_id) then
    raise exception 'this person cannot be the vet here' using errcode = '22023', hint = 'bad_vet';
  end if;
  update public.medical_visits set
    vet_id = p_vet,
    vet_name = case when p_vet is null then null else public.staff_display_name(p_vet) end
  where id = p_id;
end;
$$;


ALTER FUNCTION "public"."assign_medical_vet"("p_id" "uuid", "p_vet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."auto_cancel_stale_shop_orders"("p_hours" integer DEFAULT 48) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_reason text := format('Tự hủy: quá %s giờ chưa được xác nhận', p_hours);
  v_count  integer;
begin
  if p_hours is null or p_hours < 1 then
    raise exception 'p_hours must be at least 1' using errcode = '22023', hint = 'bad_hours';
  end if;

  with stale as (
    update public.shop_orders
    set status = 'cancelled', cancelled_at = now(), cancel_reason = v_reason
    where status = 'pending'
      and invoice_id is null
      and placed_at < now() - make_interval(hours => p_hours)
    returning id
  ), logged as (
    insert into public.shop_order_events (order_id, status, note, actor_name)
    select id, 'cancelled', v_reason, 'Hệ thống' from stale
    returning 1
  )
  select count(*) into v_count from logged;

  return v_count;
end;
$$;


ALTER FUNCTION "public"."auto_cancel_stale_shop_orders"("p_hours" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."billable_appointment_items"("p_branch" "uuid", "p_customer" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', i.id,
      'code', a.code,
      'name', i.name,
      'item_type', i.item_type,
      'pet_id', i.pet_id,
      'pet_name', pt.name,
      'pet_photo_url', pt.photo_url,
      'unit_price', i.unit_price
    ) order by a.start_at, i.line_no)
    from public.appointment_items i
    join public.appointments a on a.id = i.appointment_id
    left join public.pets pt on pt.id = i.pet_id
    where a.branch_id = p_branch
      and a.customer_id = p_customer
      and i.status = 'done'
      and i.invoice_line_id is null
      and i.unit_price is not null
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."billable_appointment_items"("p_branch" "uuid", "p_customer" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."billable_boarding_charges"("p_branch" "uuid", "p_customer" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'stay_id', s.id,
      'code', s.code,
      'total', c.total,
      'charges', c.charges
    ) order by s.checked_out_at, s.code)
    from public.boarding_stays s
    cross join lateral (
      select sum(bc.amount) as total,
             jsonb_agg(jsonb_build_object(
               'id', bc.id,
               'kind', bc.kind,
               'name', bc.name,
               'qty', bc.qty,
               'unit_price', bc.unit_price,
               'amount', bc.amount,
               'pet_name', (
                 select p.name
                 from public.boarding_stay_pets sp
                 join public.pets p on p.id = sp.pet_id
                 where sp.id = bc.stay_pet_id
               ),
               'pet_photo_url', (
                 select p.photo_url
                 from public.boarding_stay_pets sp
                 join public.pets p on p.id = sp.pet_id
                 where sp.id = bc.stay_pet_id
               )
             ) order by bc.created_at, bc.id) as charges
      from public.boarding_charges bc
      where bc.stay_id = s.id and bc.invoice_line_id is null
    ) c
    where s.branch_id = p_branch
      and s.customer_id = p_customer
      and s.status = 'checked_out'
      and c.charges is not null
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."billable_boarding_charges"("p_branch" "uuid", "p_customer" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."billable_medical_items"("p_branch" "uuid", "p_customer" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'visit_id', v.id,
      'code', v.code,
      'pet_name', v.pet_name,
      'pet_photo_url', (select p.photo_url from public.pets p where p.id = v.pet_id),
      'total', c.total,
      'items', c.items
    ) order by v.signed_at, v.code)
    from public.medical_visits v
    cross join lateral (
      select sum(i.amount) as total,
             jsonb_agg(jsonb_build_object(
               'id', i.id,
               'kind', i.kind,
               'name', i.name,
               'qty', i.qty,
               'unit_name', i.unit_name,
               'unit_price', i.unit_price,
               'amount', i.amount
             ) order by i.created_at, i.id) as items
      from public.medical_visit_items i
      where i.visit_id = v.id and i.kind in ('service', 'product') and i.invoice_line_id is null
    ) c
    where v.branch_id = p_branch
      and v.customer_id = p_customer
      and v.status = 'done'
      and v.signed_at is not null
      and c.items is not null
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."billable_medical_items"("p_branch" "uuid", "p_customer" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_apply_stay"("p" "jsonb", "p_id" "uuid", "p_dry" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."boarding_apply_stay"("p" "jsonb", "p_id" "uuid", "p_dry" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_availability"("p_branch" "uuid", "p_from" "date", "p_to" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."boarding_availability"("p_branch" "uuid", "p_from" "date", "p_to" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_board"("p_branch" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
           s.kind as stay_kind, s.visit_id, mv.code as visit_code,
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
           ) as has_notes,
           (select pt.photo_url from public.pets pt where pt.id = sp.pet_id) as pet_photo_url
    from public.boarding_stay_pets sp
    join public.boarding_stays s on s.id = sp.stay_id
    left join public.medical_visits mv on mv.id = s.visit_id
    where sp.branch_id = p_branch and sp.status = 'active'
      and s.status in ('booked', 'checked_in')
  ), per_kennel as (
    select k.id, k.code, k.name, k.kennel_type_id, t.name as type_name, t.purpose, k.status, k.sort_order, t.sort_order as type_sort,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name, 'pet_photo_url', p.pet_photo_url,
             'customer_name', p.customer_name, 'planned_in_at', p.planned_in_at,
             'planned_out_at', p.planned_out_at, 'has_notes', p.has_notes, 'overdue', p.overdue,
             'kind', p.stay_kind, 'visit_id', p.visit_id, 'visit_code', p.visit_code
           ) order by p.pet_name) filter (where p.in_kennel), '[]'::jsonb) as in_pets,
           coalesce(jsonb_agg(jsonb_build_object(
             'stay_id', p.stay_id, 'stay_code', p.stay_code, 'stay_status', p.stay_status,
             'stay_pet_id', p.stay_pet_id, 'pet_id', p.pet_id, 'pet_name', p.pet_name, 'pet_photo_url', p.pet_photo_url,
             'customer_name', p.customer_name, 'planned_in_at', p.planned_in_at,
             'planned_out_at', p.planned_out_at, 'has_notes', p.has_notes, 'overdue', false,
             'kind', p.stay_kind, 'visit_id', p.visit_id, 'visit_code', p.visit_code
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
           'kennel_type_id', st.kennel_type_id, 'kennel_type_name', st.type_name, 'purpose', st.purpose,
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
        'free', count(*) filter (where k ->> 'state' = 'free'),
        'inpatient', count(*) filter (where exists (
          select 1 from jsonb_array_elements(k -> 'pets') as p(pet) where p.pet ->> 'kind' = 'inpatient'))
      )
      from jsonb_array_elements(coalesce(v_kennels, '[]'::jsonb)) as t(k)
    )
  );
end;
$$;


ALTER FUNCTION "public"."boarding_board"("p_branch" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."boarding_stays" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "customer_name" "text" NOT NULL,
    "customer_phone" "text" NOT NULL,
    "status" "text" DEFAULT 'booked'::"text" NOT NULL,
    "planned_in_at" timestamp with time zone NOT NULL,
    "planned_out_at" timestamp with time zone NOT NULL,
    "checked_in_at" timestamp with time zone,
    "checked_out_at" timestamp with time zone,
    "source" "text" DEFAULT 'counter'::"text" NOT NULL,
    "emergency_phone" "text",
    "note" "text",
    "cancelled_at" timestamp with time zone,
    "cancel_reason" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "kind" "text" DEFAULT 'boarding'::"text" NOT NULL,
    "visit_id" "uuid",
    CONSTRAINT "boarding_stays_check" CHECK (("planned_out_at" > "planned_in_at")),
    CONSTRAINT "boarding_stays_kind_check" CHECK (("kind" = ANY (ARRAY['boarding'::"text", 'inpatient'::"text"]))),
    CONSTRAINT "boarding_stays_source_check" CHECK (("source" = ANY (ARRAY['counter'::"text", 'phone'::"text", 'web'::"text"]))),
    CONSTRAINT "boarding_stays_status_check" CHECK (("status" = ANY (ARRAY['booked'::"text", 'checked_in'::"text", 'checked_out'::"text", 'paid'::"text", 'cancelled'::"text", 'no_show'::"text"])))
);


ALTER TABLE "public"."boarding_stays" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_checkout_calc"("p_stay" "public"."boarding_stays", "p_at" timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."boarding_checkout_calc"("p_stay" "public"."boarding_stays", "p_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_checkout_preview"("p_id" "uuid", "p_at" timestamp with time zone DEFAULT "now"()) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."boarding_checkout_preview"("p_id" "uuid", "p_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_local_date"("p_at" timestamp with time zone) RETURNS "date"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$ select (p_at at time zone 'Asia/Ho_Chi_Minh')::date; $$;


ALTER FUNCTION "public"."boarding_local_date"("p_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_pick_kennel"("p_branch" "uuid", "p_type" "uuid", "p_nights" "daterange", "p_exclude" "uuid"[] DEFAULT '{}'::"uuid"[]) RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."boarding_pick_kennel"("p_branch" "uuid", "p_type" "uuid", "p_nights" "daterange", "p_exclude" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_public_catalog"("p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch public.branches;
  v_rules  record;
begin
  select * into v_branch
  from public.branches
  where is_active and (p_branch is null or id = p_branch)
  order by created_at
  limit 1;
  if not found then
    return jsonb_build_object('branch', null, 'rules', null, 'kennel_types', '[]'::jsonb);
  end if;
  select * into v_rules from public.boarding_rules(v_branch.id);

  return jsonb_build_object(
    'branch', jsonb_build_object('id', v_branch.id, 'name', v_branch.name, 'phone', v_branch.phone),
    'rules', jsonb_build_object(
      'check_in_from', to_char(v_rules.check_in_from, 'HH24:MI'),
      'check_out_by', to_char(v_rules.check_out_by, 'HH24:MI'),
      'late_half_until', to_char(v_rules.late_half_until, 'HH24:MI')
    ),
    'kennel_types', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'description', t.description,
        'photo_url', t.photo_url,
        'max_weight_kg', t.max_weight_kg,
        'max_pets', t.max_pets,
        'night_price', public.kennel_night_price(t.id, v_branch.id),
        'extra_pet_night_price', public.kennel_extra_pet_price(t.id, v_branch.id),
        'species', coalesce((
          select jsonb_agg(s.name order by s.name)
          from public.species s where s.id = any(t.species_ids) and s.is_active
        ), '[]'::jsonb)
      ) order by t.sort_order, t.name)
      from public.kennel_types t
      where t.is_active and t.is_public and t.purpose = 'boarding'
        and public.kennel_night_price(t.id, v_branch.id) is not null
        and exists (select 1 from public.kennels k where k.kennel_type_id = t.id and k.branch_id = v_branch.id and k.is_active)
    ), '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."boarding_public_catalog"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_quote"("p_branch" "uuid", "p" "jsonb", "p_stay" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."boarding_quote"("p_branch" "uuid", "p" "jsonb", "p_stay" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_rules"("p_branch" "uuid") RETURNS TABLE("check_in_from" time without time zone, "check_out_by" time without time zone, "late_half_until" time without time zone, "max_nights" integer, "day_stay_nights" numeric)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce(s.check_in_from, time '08:00'),
         coalesce(s.check_out_by, time '12:00'),
         coalesce(s.late_half_until, time '18:00'),
         coalesce(s.max_nights, 30),
         coalesce(s.day_stay_nights, 1)
  from (select 1) as one
  left join public.boarding_settings s on s.branch_id = p_branch;
$$;


ALTER FUNCTION "public"."boarding_rules"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_settings_get"("p_branch" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'check_in_from', to_char(coalesce(s.check_in_from, time '08:00'), 'HH24:MI'),
      'check_out_by', to_char(coalesce(s.check_out_by, time '12:00'), 'HH24:MI'),
      'late_half_until', to_char(coalesce(s.late_half_until, time '18:00'), 'HH24:MI'),
      'max_nights', coalesce(s.max_nights, 30),
      'day_stay_nights', coalesce(s.day_stay_nights, 1)
    )
    from (select 1) as one
    left join public.boarding_settings s on s.branch_id = p_branch
  );
end;
$$;


ALTER FUNCTION "public"."boarding_settings_get"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_stay_json"("p_stay" "public"."boarding_stays") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    'kind', p_stay.kind,
    'visit_id', p_stay.visit_id,
    'visit_code', (select mv.code from public.medical_visits mv where mv.id = p_stay.visit_id),
    'emergency_phone', p_stay.emergency_phone,
    'note', p_stay.note,
    'cancel_reason', p_stay.cancel_reason,
    'est_total',
      case
        when p_stay.status in ('checked_out', 'paid') then
          coalesce((select sum(c.amount) from public.boarding_charges c where c.stay_id = p_stay.id), 0)
        else
          coalesce((
            select sum(coalesce(sp.night_price, sp.est_night_price) * sp.charged_nights)
            from public.boarding_stay_pets sp where sp.stay_id = p_stay.id and sp.status = 'active'
          ), 0)
          + coalesce((select sum(c.amount) from public.boarding_charges c where c.stay_id = p_stay.id), 0)
      end,
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', sp.id,
        'line_no', sp.line_no,
        'pet_id', sp.pet_id,
        'pet_name', sp.pet_name,
        'pet_photo_url', (select pt.photo_url from public.pets pt where pt.id = sp.pet_id),
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


ALTER FUNCTION "public"."boarding_stay_json"("p_stay" "public"."boarding_stays") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."boarding_timeline"("p_branch" "uuid", "p_from" "date" DEFAULT NULL::"date", "p_days" integer DEFAULT 14) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
            'kind', s.kind, 'visit_code', mv.code,
            'from', lower(sp.nights), 'to', upper(sp.nights)
          ) order by lower(sp.nights), sp.line_no)
          from public.boarding_stay_pets sp
          join public.boarding_stays s on s.id = sp.stay_id
          left join public.medical_visits mv on mv.id = s.visit_id
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


ALTER FUNCTION "public"."boarding_timeline"("p_branch" "uuid", "p_from" "date", "p_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."book_my_appointment"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid      uuid := auth.uid();
  v_cust     uuid := public.my_customer_id();
  v_rules    jsonb := public.spa_web_rules();
  v_branch   uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_start    timestamptz;
  v_local    timestamp;
  v_hours    record;
  v_items    jsonb := coalesce(p -> 'items', '[]'::jsonb);
  v_item     jsonb;
  v_quote    jsonb;
  v_quotes   jsonb[] := '{}';
  v_minutes  int := 0;
  v_cursor   timestamptz;
  v_end      timestamptz;
  v_line     int := 0;
  v_name     text;
  v_phone    text;
  v_id       uuid;
  v_code     text;
  v_pet      uuid;
  v_kind     text;
  v_obj      uuid;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 or jsonb_array_length(v_items) > 10 then
    raise exception 'pick at least one service' using errcode = '22023', hint = 'empty';
  end if;
  if v_branch is null or not exists (select 1 from public.branches where id = v_branch and is_active) then
    raise exception 'branch not found' using errcode = 'P0002', hint = 'bad_time';
  end if;
  begin
    v_start := (p ->> 'start_at')::timestamptz;
  exception when others then
    v_start := null;
  end;
  v_local := v_start at time zone c_tz;
  if v_start is null or extract(second from v_local) <> 0 or extract(minute from v_local)::int % 15 <> 0 then
    raise exception 'start on a quarter hour' using errcode = 'P0001', hint = 'bad_time';
  end if;
  if v_start < now() + make_interval(mins => (v_rules ->> 'min_lead_minutes')::int) then
    raise exception 'too soon' using errcode = 'P0001', hint = 'too_soon';
  end if;
  if v_local::date > (now() at time zone c_tz)::date + (v_rules ->> 'max_days')::int then
    raise exception 'too far ahead' using errcode = 'P0001', hint = 'too_far';
  end if;

  -- One customer, one lock per branch and day: the slot count below stays true until we commit.
  perform pg_advisory_xact_lock(hashtextextended(v_branch::text || ':' || v_local::date::text, 0));

  if (
    select count(*) from public.appointments a
    where a.customer_id = v_cust and a.source = 'web' and a.status = 'booked' and a.start_at > now()
  ) >= (v_rules ->> 'max_open')::int then
    raise exception 'too many upcoming web bookings' using errcode = 'P0001', hint = 'too_many';
  end if;

  -- Quote every ticket first (also checks the pets are mine and the offer fits the species).
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_pet := nullif(v_item ->> 'pet_id', '')::uuid;
    if not exists (
      select 1 from public.pet_owners where pet_id = v_pet and customer_id = v_cust and to_date is null
    ) then
      raise exception 'pet not found' using errcode = 'P0002', hint = 'no_pet';
    end if;
    if exists (select 1 from public.pets where id = v_pet and status <> 'active') then
      raise exception 'the pet is not active' using errcode = 'P0001',
        hint = case when (select status from public.pets where id = v_pet) = 'deceased' then 'pet_deceased' else 'no_pet' end;
    end if;
    v_quote := public.spa_ticket_quote(v_branch, v_pet, v_item ->> 'type', nullif(v_item ->> 'id', '')::uuid);
    v_quotes := v_quotes || v_quote;
    v_minutes := v_minutes + (v_quote ->> 'minutes')::int;
  end loop;
  v_minutes := ceil(v_minutes / 15.0)::int * 15;
  if v_minutes > (v_rules ->> 'max_block_minutes')::int then
    raise exception 'too long for one booking' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  select * into v_hours from public.spa_hours(v_branch, v_local::date);
  if v_hours.is_closed then
    raise exception 'the branch is closed that day' using errcode = 'P0001', hint = 'closed';
  end if;
  v_end := v_start + make_interval(mins => v_minutes);
  if v_local::time < v_hours.open_time
     or (v_end at time zone c_tz)::date <> v_local::date
     or (v_end at time zone c_tz)::time > v_hours.close_time then
    raise exception 'outside opening hours' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  if not public.spa_block_is_free(v_branch, v_start, v_minutes) then
    raise exception 'that time is full' using errcode = 'P0001', hint = 'slot_full';
  end if;

  -- A pet cannot be in two places at once.
  for v_item in select * from jsonb_array_elements(v_items) loop
    if exists (
      select 1 from public.appointment_items i
      where i.pet_id = (v_item ->> 'pet_id')::uuid and i.status <> 'cancelled'
        and i.start_at < v_end and i.end_at > v_start
    ) then
      raise exception 'the pet already has a visit at that time' using errcode = 'P0001', hint = 'pet_busy';
    end if;
  end loop;

  select full_name, phone into v_name, v_phone from public.customers where id = v_cust;
  insert into public.appointments (
    code, branch_id, customer_id, customer_name, customer_phone, start_at, end_at, source, note, created_by
  )
  values (
    public.next_doc_code(v_branch, 'LH'), v_branch, v_cust, v_name, v_phone,
    v_start, v_end, 'web', left(nullif(btrim(p ->> 'note'), ''), 500), v_uid
  )
  returning id, code into v_id, v_code;

  v_cursor := v_start;
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_line := v_line + 1;
    v_quote := v_quotes[v_line];
    v_kind := v_item ->> 'type';
    v_obj := nullif(v_item ->> 'id', '')::uuid;
    insert into public.appointment_items (
      appointment_id, branch_id, line_no, pet_id, item_type, service_id, combo_id, name,
      duration_minutes, start_at, end_at, est_price, weight_kg
    )
    values (
      v_id, v_branch, v_line, (v_item ->> 'pet_id')::uuid, v_kind,
      case when v_kind = 'service' then v_obj end,
      case when v_kind = 'combo' then v_obj end,
      v_quote ->> 'name', (v_quote ->> 'minutes')::int,
      v_cursor, v_cursor + make_interval(mins => (v_quote ->> 'minutes')::int),
      (v_quote ->> 'price')::numeric, (v_quote ->> 'weight_kg')::numeric
    );
    v_cursor := v_cursor + make_interval(mins => (v_quote ->> 'minutes')::int);
  end loop;

  update public.appointments set end_at = v_cursor where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;


ALTER FUNCTION "public"."book_my_appointment"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."branch_prices"("p_branch" "uuid", "p_products" "uuid"[]) RETURNS TABLE("product_id" "uuid", "price" numeric)
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select bp.product_id, bp.price
  from public.product_branch_prices bp
  where bp.branch_id = p_branch and bp.product_id = any(coalesce(p_products, '{}'::uuid[]));
$$;


ALTER FUNCTION "public"."branch_prices"("p_branch" "uuid", "p_products" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."business_date"() RETURNS "date"
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select (now() at time zone 'Asia/Ho_Chi_Minh')::date;
$$;


ALTER FUNCTION "public"."business_date"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_boarding"("p_method" "text", "p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('boarding', p_method, p_branch));
$$;


ALTER FUNCTION "public"."can_boarding"("p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_edit_pet_photos"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or coalesce((select public.has_permission('pets', 'UPDATE')), false)
      or coalesce((select public.has_permission('pets', 'CREATE')), false);
$$;


ALTER FUNCTION "public"."can_edit_pet_photos"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_inventory"("p_method" "text", "p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('inventory', p_method, p_branch));
$$;


ALTER FUNCTION "public"."can_inventory"("p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_link_accounts"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or coalesce((select public.has_permission('pets', 'UPDATE')), false);
$$;


ALTER FUNCTION "public"."can_link_accounts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_medical"("p_method" "text", "p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('medical', p_method, p_branch));
$$;


ALTER FUNCTION "public"."can_medical"("p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_pos"("p_method" "text", "p_branch" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('pos', p_method, p_branch));
$$;


ALTER FUNCTION "public"."can_pos"("p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_products"("p_method" "text") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or coalesce((select public.has_permission('products', p_method)), false);
$$;


ALTER FUNCTION "public"."can_products"("p_method" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_report"("p_method" "text", "p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('reports', p_method, p_branch));
$$;


ALTER FUNCTION "public"."can_report"("p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_schedule"("p_method" "text", "p_branch" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('schedule', p_method, p_branch));
$$;


ALTER FUNCTION "public"."can_schedule"("p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_shop_orders"("p_method" "text", "p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('shop_orders', p_method, p_branch));
$$;


ALTER FUNCTION "public"."can_shop_orders"("p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_appointment"("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_appt public.appointments;
begin
  select * into v_appt from public.appointments where id = p_id for update;
  if not found then
    raise exception 'appointment % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_schedule('DELETE', v_appt.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_appt.status not in ('booked', 'checked_in') then
    raise exception 'this appointment can no longer be cancelled' using errcode = 'P0001', hint = 'not_editable';
  end if;

  update public.appointment_items set status = 'cancelled' where appointment_id = p_id;
  update public.appointments set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = nullif(btrim(p_reason), '')
  where id = p_id;
end;
$$;


ALTER FUNCTION "public"."cancel_appointment"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_boarding_stay"("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."cancel_boarding_stay"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_invoice"("p_id" "uuid", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_invoice public.invoices;
  v_freed   uuid;
  v_stay    uuid;
  v_visit   uuid;
begin
  select * into v_invoice from public.invoices where id = p_id for update;
  if not found then
    raise exception 'invoice % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_pos('DELETE', v_invoice.branch_id) then
    raise exception 'not allowed to cancel invoices' using errcode = '42501';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'invoice is already cancelled' using errcode = '22023';
  end if;
  if length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'a reason is required' using errcode = '22023';
  end if;
  -- Locked like a sale, so the shift cannot be closed and counted while this cancel commits.
  perform 1 from public.cash_shifts where id = v_invoice.shift_id and status = 'open' for share;
  if not found then
    raise exception 'the shift of this invoice is closed' using errcode = '22023', hint = 'shift_closed';
  end if;

  update public.invoices
  set status = 'cancelled',
      cancelled_at = now(),
      cancelled_by = (select auth.uid()),
      cancel_reason = btrim(p_reason)
  where id = p_id;

  -- Spa tickets on this invoice are unpaid again.
  for v_freed in
    with freed as (
      update public.appointment_items i
      set invoice_line_id = null
      from public.invoice_lines l
      where l.invoice_id = p_id and i.invoice_line_id = l.id
      returning i.appointment_id
    )
    select distinct appointment_id from freed
  loop
    perform public.refresh_appointment_status(v_freed);
  end loop;

  -- Boarding charges on this invoice are unpaid again.
  for v_stay in
    with freed as (
      update public.boarding_charges c
      set invoice_line_id = null
      from public.invoice_lines l
      where l.invoice_id = p_id and c.invoice_line_id = l.id
      returning c.stay_id
    )
    select distinct stay_id from freed
  loop
    perform public.refresh_boarding_stay_status(v_stay);
  end loop;

  -- Medical lines on this invoice are unpaid again.
  for v_visit in
    with freed as (
      update public.medical_visit_items i
      set invoice_line_id = null
      from public.invoice_lines l
      where l.invoice_id = p_id and i.invoice_line_id = l.id
      returning i.visit_id
    )
    select distinct visit_id from freed
  loop
    perform public.medical_refresh_status(v_visit);
  end loop;
end;
$$;


ALTER FUNCTION "public"."cancel_invoice"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_medical_visit"("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_visit public.medical_visits;
begin
  select * into v_visit from public.medical_visits where id = p_id for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('DELETE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status not in ('scheduled', 'waiting', 'in_progress') or v_visit.signed_at is not null then
    raise exception 'the visit can no longer be cancelled' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if exists (select 1 from public.medical_visit_items where visit_id = p_id and not auto_added) then
    raise exception 'remove the lines of the visit first' using errcode = 'P0001', hint = 'has_items';
  end if;
  delete from public.medical_visit_items where visit_id = p_id;
  update public.medical_visits set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = nullif(btrim(p_reason), '')
  where id = p_id;
end;
$$;


ALTER FUNCTION "public"."cancel_medical_visit"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_my_appointment"("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cust  uuid := public.my_customer_id();
  v_appt  public.appointments;
  v_cancel interval := make_interval(mins => (public.spa_web_rules() ->> 'cancel_before_minutes')::int);
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  select * into v_appt from public.appointments where id = p_id and customer_id = v_cust for update;
  if not found then
    raise exception 'appointment not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_appt.status <> 'booked' then
    raise exception 'this appointment can no longer be cancelled' using errcode = 'P0001', hint = 'not_cancellable';
  end if;
  if v_appt.start_at - now() <= v_cancel then
    raise exception 'too close to the appointment time' using errcode = 'P0001', hint = 'too_late';
  end if;

  update public.appointment_items set status = 'cancelled' where appointment_id = p_id;
  update public.appointments set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = coalesce(left(nullif(btrim(p_reason), ''), 200), 'cancelled by customer')
  where id = p_id;
end;
$$;


ALTER FUNCTION "public"."cancel_my_appointment"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_my_shop_order"("p_code" "text", "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid    uuid := (select auth.uid());
  v_row    public.shop_orders;
  v_reason text := left(nullif(btrim(coalesce(p_reason, '')), ''), 300);
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_row from public.shop_orders where code = p_code and user_id = v_uid for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  if v_row.status not in ('pending', 'confirmed') then
    raise exception 'this order can no longer be cancelled' using errcode = '22023', hint = 'not_cancellable';
  end if;

  update public.shop_orders
  set status = 'cancelled', cancelled_at = now(), cancel_reason = v_reason
  where id = v_row.id
  returning * into v_row;

  insert into public.shop_order_events (order_id, status, note, actor_id, actor_name)
  values (v_row.id, 'cancelled', v_reason, v_uid, 'Khách');

  return public.my_shop_order_json(v_row);
end;
$$;


ALTER FUNCTION "public"."cancel_my_shop_order"("p_code" "text", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_shop_order"("p_id" "uuid", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o        public.shop_orders := public.shop_order_for_update(p_id, array['pending', 'confirmed', 'packed']);
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_reason = '' then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  if o.invoice_id is not null then
    perform public.shop_order_cancel_invoice(o.invoice_id, v_reason);
  end if;
  update public.shop_orders set status = 'cancelled', cancel_reason = v_reason, cancelled_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'cancelled', v_reason);
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."cancel_shop_order"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cancel_stock_document"("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_doc  public.stock_documents;
  v_line public.stock_document_lines;
begin
  select * into v_doc from public.stock_documents where id = p_id for update;
  if not found then
    raise exception 'document % not found', p_id using errcode = 'P0002';
  end if;

  if v_doc.status = 'draft' then
    if not public.can_inventory('CREATE', v_doc.branch_id) then
      raise exception 'not allowed to cancel this document' using errcode = '42501';
    end if;
  elsif v_doc.status = 'posted' then
    if v_doc.doc_type <> 'receipt' then
      raise exception 'a posted write-off or count is corrected with a new count'
        using errcode = '22023', hint = 'posted_not_receipt';
    end if;
    if not public.can_inventory('DELETE', v_doc.branch_id) then
      raise exception 'not allowed to cancel a posted receipt' using errcode = '42501', hint = 'needs_manager';
    end if;
    if length(btrim(coalesce(p_reason, ''))) = 0 then
      raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
    end if;
    for v_line in select * from public.stock_document_lines where document_id = p_id order by line_no loop
      perform public.move_stock(
        v_line.lot_id, -v_line.qty, 'receipt_cancel', p_document => p_id, p_document_line => v_line.id,
        p_unit_cost => v_line.unit_cost
      );
    end loop;
  else
    raise exception 'document is already cancelled' using errcode = '22023', hint = 'not_draft';
  end if;

  update public.stock_documents
  set status = 'cancelled',
      cancelled_by = (select auth.uid()),
      cancelled_by_name = public.staff_display_name((select auth.uid())),
      cancelled_at = now(),
      cancel_reason = nullif(btrim(p_reason), '')
  where id = p_id;
end;
$$;


ALTER FUNCTION "public"."cancel_stock_document"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cash_shift_summary"("p_shift" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_shift  public.cash_shifts;
  v_result jsonb;
begin
  select * into v_shift from public.cash_shifts where id = p_shift;
  if not found then
    raise exception 'shift % not found', p_shift using errcode = 'P0002';
  end if;
  if v_shift.opened_by <> (select auth.uid()) and not public.can_pos('VIEW', v_shift.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with inv as (
    select * from public.invoices where shift_id = p_shift
  ), pay as (
    select p.method, sum(p.amount) as amount
    from public.payments p
    join inv on inv.id = p.invoice_id and inv.status = 'paid'
    group by p.method
  ), ret as (
    select refund_method, count(*) as n, sum(refund_amount) as amount
    from public.sales_returns
    where shift_id = p_shift
    group by refund_method
  )
  select jsonb_build_object(
    'shift_id',        v_shift.id,
    'opening_cash',    v_shift.opening_cash,
    'invoice_count',   (select count(*) from inv where status = 'paid'),
    'cancelled_count', (select count(*) from inv where status = 'cancelled'),
    'sales_total',     (select coalesce(sum(total), 0) from inv where status = 'paid'),
    'discount_total',  (select coalesce(sum(discount_amount), 0) from inv where status = 'paid'),
    'change_total',    (select coalesce(sum(change_amount), 0) from inv where status = 'paid'),
    'cash_in',         coalesce((select amount from pay where method = 'cash'), 0),
    'transfer_in',     coalesce((select amount from pay where method = 'transfer'), 0),
    'card_in',         coalesce((select amount from pay where method = 'card'), 0),
    'return_count',    coalesce((select sum(n) from ret), 0),
    'refund_cash',     coalesce((select amount from ret where refund_method = 'cash'), 0),
    'refund_transfer', coalesce((select amount from ret where refund_method = 'transfer'), 0),
    'expected_cash',   v_shift.opening_cash
                         + coalesce((select amount from pay where method = 'cash'), 0)
                         - (select coalesce(sum(change_amount), 0) from inv where status = 'paid')
                         - coalesce((select amount from ret where refund_method = 'cash'), 0)
  ) into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."cash_shift_summary"("p_shift" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_in_appointment"("p_id" "uuid", "p_weights" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."check_in_appointment"("p_id" "uuid", "p_weights" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_in_boarding"("p_id" "uuid", "p_pets" "jsonb", "p_emergency_phone" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."check_in_boarding"("p_id" "uuid", "p_pets" "jsonb", "p_emergency_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_in_medical_visit"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid      uuid := (select auth.uid());
  v_visit    public.medical_visits;
  v_visit_id uuid := nullif(p ->> 'visit_id', '')::uuid;
  v_branch   uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer uuid := nullif(p ->> 'customer_id', '')::uuid;
  v_pet      uuid := nullif(p ->> 'pet_id', '')::uuid;
  v_priority text := coalesce(nullif(p ->> 'priority', ''), 'normal');
  v_source   text := coalesce(nullif(p ->> 'source', ''), 'counter');
  v_reason   text := nullif(btrim(p ->> 'reason'), '');
  v_weight   numeric := nullif(p ->> 'weight_kg', '')::numeric;
  v_temp     numeric := nullif(p ->> 'temperature_c', '')::numeric;
  v_vet      uuid;
  v_vet_name text;
  v_names    jsonb;
  v_today    date := public.business_date();
  v_no       int;
  v_id       uuid;
  v_code     text;
  v_busy     text;
begin
  if v_visit_id is not null then
    select * into v_visit from public.medical_visits where id = v_visit_id for update;
    if not found then
      raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
    end if;
    if v_visit.status <> 'scheduled' then
      raise exception 'only a booked visit can be checked in' using errcode = 'P0001', hint = 'not_scheduled';
    end if;
    v_branch := v_visit.branch_id;
    v_customer := v_visit.customer_id;
    v_pet := v_visit.pet_id;
    v_vet := v_visit.vet_id;
    v_reason := coalesce(v_reason, v_visit.reason);
  end if;

  if v_branch is null or not public.can_medical('CREATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_customer is null or v_pet is null or v_priority not in ('normal', 'urgent')
     or v_source not in ('counter', 'phone', 'recheck', 'web') then
    raise exception 'customer and pet are required' using errcode = '22023', hint = 'bad_input';
  end if;
  if p ? 'vet_id' then
    v_vet := nullif(p ->> 'vet_id', '')::uuid;
  end if;
  if v_vet is not null and not public.medical_user_can_update(v_vet, v_branch) then
    raise exception 'this person cannot be the vet here' using errcode = '22023', hint = 'bad_vet';
  end if;

  v_names := public.medical_check_pet(v_customer, v_pet);

  select code into v_busy from public.medical_visits
  where pet_id = v_pet and status in ('waiting', 'in_progress') and id is distinct from v_visit_id
  limit 1;
  if found then
    raise exception 'the pet already has an open visit' using errcode = 'P0001', hint = 'pet_busy', detail = v_busy;
  end if;

  v_vet_name := case when v_vet is null then null else public.staff_display_name(v_vet) end;

  -- The queue number is the next one of the branch's business day.
  perform pg_advisory_xact_lock(hashtextextended('medical-queue:' || v_branch::text || ':' || v_today::text, 0));
  select coalesce(max(queue_no), 0) + 1 into v_no
  from public.medical_visits where branch_id = v_branch and queue_date = v_today;

  begin
    if v_visit_id is null then
      v_code := public.next_doc_code(v_branch, 'KB');
      insert into public.medical_visits (
        code, branch_id, pet_id, customer_id, pet_name, customer_name, customer_phone, status, priority,
        queue_date, queue_no, reason, vet_id, vet_name, checked_in_at, weight_kg, temperature_c, source, created_by
      ) values (
        v_code, v_branch, v_pet, v_customer, v_names ->> 'pet_name', v_names ->> 'customer_name',
        v_names ->> 'customer_phone', 'waiting', v_priority, v_today, v_no, v_reason, v_vet, v_vet_name,
        now(), v_weight, v_temp, v_source, v_uid
      ) returning id into v_id;
    else
      update public.medical_visits set
        status = 'waiting',
        priority = v_priority,
        queue_date = v_today,
        queue_no = v_no,
        reason = v_reason,
        vet_id = v_vet,
        vet_name = v_vet_name,
        checked_in_at = now(),
        weight_kg = coalesce(v_weight, weight_kg),
        temperature_c = coalesce(v_temp, temperature_c),
        pet_name = v_names ->> 'pet_name',
        customer_name = v_names ->> 'customer_name',
        customer_phone = v_names ->> 'customer_phone'
      where id = v_visit_id
      returning id, code into v_id, v_code;
    end if;
  exception when unique_violation then
    raise exception 'the pet already has an open visit' using errcode = 'P0001', hint = 'pet_busy';
  end;

  if v_weight is not null then
    insert into public.pet_weight_logs (pet_id, weight_kg, note, created_by)
    values (v_pet, v_weight, v_code, v_uid);
  end if;

  return jsonb_build_object('id', v_id, 'code', v_code, 'queue_no', v_no);
end;
$$;


ALTER FUNCTION "public"."check_in_medical_visit"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."check_out_boarding"("p_id" "uuid", "p_returned" "uuid"[] DEFAULT '{}'::"uuid"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
  if v_stay.kind = 'inpatient' then
    raise exception 'an inpatient stay is managed on the inpatient screen' using errcode = 'P0001', hint = 'inpatient_stay';
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


ALTER FUNCTION "public"."check_out_boarding"("p_id" "uuid", "p_returned" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."close_cash_shift"("p_shift" "uuid", "p_counted_cash" numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_shift   public.cash_shifts;
  v_summary jsonb;
begin
  select * into v_shift from public.cash_shifts where id = p_shift for update;
  if not found then
    raise exception 'shift % not found', p_shift using errcode = 'P0002';
  end if;
  if not (
    (v_shift.opened_by = (select auth.uid()) and public.can_pos('CREATE', v_shift.branch_id))
    or public.can_pos('UPDATE', v_shift.branch_id)
  ) then
    raise exception 'not allowed to close this shift' using errcode = '42501';
  end if;
  if v_shift.status <> 'open' then
    raise exception 'shift is already closed' using errcode = '22023';
  end if;
  if coalesce(p_counted_cash, -1) < 0 then
    raise exception 'counted cash must be zero or more' using errcode = '22023';
  end if;

  v_summary := public.cash_shift_summary(p_shift);

  update public.cash_shifts
  set status = 'closed',
      closed_by = (select auth.uid()),
      closed_by_name = public.staff_display_name((select auth.uid())),
      closed_at = now(),
      expected_cash = (v_summary ->> 'expected_cash')::numeric,
      counted_cash = p_counted_cash,
      close_note = nullif(btrim(p_note), '')
  where id = p_shift;

  return v_summary || jsonb_build_object('counted_cash', p_counted_cash);
end;
$$;


ALTER FUNCTION "public"."close_cash_shift"("p_shift" "uuid", "p_counted_cash" numeric, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirm_shop_order"("p_id" "uuid", "p_shipping_fee" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o     public.shop_orders := public.shop_order_for_update(p_id, array['pending']);
  v_fee numeric;
  v_max numeric;
begin
  if o.delivery_method = 'pickup' then
    v_fee := 0;
  else
    v_fee := round(coalesce(p_shipping_fee, o.shipping_fee_quote));
    if v_fee < 0 or v_fee > 500000 then
      raise exception 'the shipping fee must be between 0 and 500000' using errcode = '22023', hint = 'invalid_fee';
    end if;
    select cod_max into v_max from public.shop_settings where id;
    if o.subtotal + v_fee > v_max then
      raise exception 'cash on delivery is limited to % VND', v_max using errcode = '22023', hint = 'cod_limit';
    end if;
  end if;

  update public.shop_orders
  set status = 'confirmed', shipping_fee = v_fee, total = subtotal + v_fee, confirmed_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'confirmed');
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."confirm_shop_order"("p_id" "uuid", "p_shipping_fee" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_invoice"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_discount_limit constant numeric := 0.10;
  v_uid       uuid := (select auth.uid());
  v_branch    uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer  uuid := nullif(p ->> 'customer_id', '')::uuid;
  v_discount  numeric := coalesce(nullif(p ->> 'discount_amount', '')::numeric, 0);
  v_ref       uuid := nullif(p ->> 'client_ref', '')::uuid;
  v_shift     uuid;
  v_id        uuid;
  v_code      text;
  v_line      jsonb;
  v_pay       jsonb;
  v_line_no   int := 0;
  v_kind      text;
  v_item      uuid;
  v_pet       uuid;
  v_species   uuid;
  v_weight    numeric;
  v_qty       numeric;
  v_name      text;
  v_unit      text;
  v_price     numeric;
  v_subtotal  numeric := 0;
  v_total     numeric;
  v_paid      numeric := 0;
  v_cash      numeric := 0;
  v_change    numeric;
  v_method    text;
  v_amount    numeric;
  v_product   public.products;
  v_service   public.pet_services;
  v_combo     public.pet_service_combos;
  v_existing  public.invoices;
  v_ticket    public.appointment_items;
  v_ticket_appt uuid;
  v_line_id   uuid;
  v_unit_id   uuid;
  v_factor    numeric;
  v_unit_row  public.product_units;
  v_charge    public.boarding_charges;
  v_mitem     public.medical_visit_items;
  v_mvisit    public.medical_visits;
  v_lot       uuid;
begin
  if v_uid is null or v_branch is null or not public.can_pos('CREATE', v_branch) then
    raise exception 'not allowed to sell at this branch' using errcode = '42501';
  end if;

  -- The same sale sent again: one attempt at a time, and the invoice it already made.
  if v_ref is not null then
    perform pg_advisory_xact_lock(hashtextextended('create_invoice:' || v_ref::text, 0));
    select * into v_existing from public.invoices where client_ref = v_ref;
    if found then
      if v_existing.created_by <> v_uid then
        raise exception 'client_ref belongs to another sale' using errcode = '23505';
      end if;
      return jsonb_build_object(
        'id', v_existing.id, 'code', v_existing.code, 'total', v_existing.total,
        'change_amount', v_existing.change_amount, 'replayed', true
      );
    end if;
  end if;

  -- The lock keeps the shift open until this sale commits; close_cash_shift waits for it.
  select id into v_shift
  from public.cash_shifts
  where branch_id = v_branch and opened_by = v_uid and status = 'open'
  for share;
  if v_shift is null then
    raise exception 'open a cash shift before selling' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  -- The buyer: a customer, a web account that becomes one, or a new walk-in typed at the
  -- counter (matched by phone, as register_pet does). No customer = anonymous sale.
  v_customer := coalesce(v_customer, nullif(p #>> '{customer,id}', '')::uuid);
  if v_customer is null and nullif(p #>> '{customer,user_id}', '') is not null then
    select id into v_customer from public.customers where user_id = (p #>> '{customer,user_id}')::uuid;
    if v_customer is null then
      insert into public.customers (full_name, phone, email, user_id, created_by)
      select coalesce(nullif(btrim(u.full_name), ''), u.display_name, u.email), u.phone_number, u.email, u.id, v_uid
      from public.users u
      where u.id = (p #>> '{customer,user_id}')::uuid and u.phone_number is not null
      on conflict on constraint customers_phone_digits_key
        do update set user_id = coalesce(public.customers.user_id, excluded.user_id), updated_at = now()
      returning id into v_customer;
    end if;
    if v_customer is null then
      raise exception 'account has no phone number' using errcode = 'P0002';
    end if;
  elsif v_customer is null and nullif(btrim(p #>> '{customer,phone}'), '') is not null then
    insert into public.customers (full_name, phone, email, created_by)
    values (
      btrim(p #>> '{customer,full_name}'),
      btrim(p #>> '{customer,phone}'),
      nullif(btrim(p #>> '{customer,email}'), ''),
      v_uid
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  elsif v_customer is not null and not exists (select 1 from public.customers where id = v_customer) then
    raise exception 'customer % not found', v_customer using errcode = 'P0002';
  end if;

  if jsonb_array_length(coalesce(p -> 'lines', '[]'::jsonb)) = 0 then
    raise exception 'an invoice needs at least one line' using errcode = '22023';
  end if;

  v_code := public.next_doc_code(v_branch, 'HD');
  insert into public.invoices (
    code, branch_id, shift_id, customer_id, customer_name, customer_phone, cashier_name,
    subtotal, discount_amount, total, note, created_by, client_ref
  )
  select
    v_code, v_branch, v_shift, v_customer, c.full_name, c.phone, public.staff_display_name(v_uid),
    0, 0, 0, nullif(btrim(p ->> 'note'), ''), v_uid, v_ref
  from (select 1) as one
  left join public.customers c on c.id = v_customer
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p -> 'lines') loop
    v_line_no := v_line_no + 1;
    v_kind := v_line ->> 'type';
    v_item := nullif(v_line ->> 'id', '')::uuid;
    v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 1);
    v_pet := nullif(v_line ->> 'pet_id', '')::uuid;
    v_weight := null;
    v_unit := null;
    v_unit_id := null;
    v_factor := 1;
    v_ticket := null;
    v_charge := null;
    v_mitem := null;
    v_lot := null;

    -- A finished spa ticket: its price, pet and name are the ones fixed at check-in.
    if v_kind = 'appointment_item' then
      select i.* into v_ticket
      from public.appointment_items i
      join public.appointments a on a.id = i.appointment_id
      where i.id = v_item and a.branch_id = v_branch and a.customer_id is not distinct from v_customer
      for update of i;
      if not found or v_ticket.status <> 'done' or v_ticket.invoice_line_id is not null or v_ticket.unit_price is null then
        raise exception 'line %: the spa ticket cannot be paid here', v_line_no using errcode = 'P0001', hint = 'ticket_not_billable';
      end if;
      v_ticket_appt := v_ticket.appointment_id;
      v_kind := v_ticket.item_type;
      v_item := coalesce(v_ticket.service_id, v_ticket.combo_id);
      v_qty := 1;
      v_pet := v_ticket.pet_id;
      v_name := v_ticket.name;
      v_price := v_ticket.unit_price;
      v_weight := v_ticket.weight_kg;
    end if;

    -- A charge of a checked-out boarding stay: its qty, price and name are fixed at check-out.
    if v_kind = 'boarding_charge' then
      select c.* into v_charge
      from public.boarding_charges c
      join public.boarding_stays s on s.id = c.stay_id
      where c.id = v_item and s.branch_id = v_branch and s.customer_id is not distinct from v_customer
        and s.status = 'checked_out'
      for update of c;
      if not found or v_charge.invoice_line_id is not null then
        raise exception 'line %: the boarding charge cannot be paid here', v_line_no using errcode = 'P0001', hint = 'charge_not_billable';
      end if;
      v_kind := 'boarding';
      v_item := null;
      v_qty := v_charge.qty;
      v_pet := null;
      v_name := coalesce(
        (select v_charge.name || ' · ' || p.name
         from public.boarding_stay_pets sp join public.pets p on p.id = sp.pet_id
         where sp.id = v_charge.stay_pet_id),
        v_charge.name
      );
      v_price := v_charge.unit_price;
    end if;

    -- A line of a signed visit: its qty, price, unit and batch are fixed by the vet and the DB.
    if v_kind = 'medical_item' then
      select i.* into v_mitem
      from public.medical_visit_items i
      join public.medical_visits mv on mv.id = i.visit_id
      where i.id = v_item and mv.branch_id = v_branch and mv.customer_id is not distinct from v_customer
        and mv.status = 'done' and mv.signed_at is not null
        and i.kind in ('service', 'product')
      for update of i;
      if not found or v_mitem.invoice_line_id is not null then
        raise exception 'line %: the medical line cannot be paid here', v_line_no using errcode = 'P0001', hint = 'medical_item_not_billable';
      end if;
      select * into v_mvisit from public.medical_visits where id = v_mitem.visit_id;
      v_kind := v_mitem.kind;
      v_item := coalesce(v_mitem.service_id, v_mitem.product_id);
      v_qty := v_mitem.qty;
      v_pet := v_mvisit.pet_id;
      v_name := v_mitem.name;
      v_price := v_mitem.unit_price;
      v_unit := v_mitem.unit_name;
      v_unit_id := v_mitem.unit_id;
      v_factor := v_mitem.unit_factor;
      v_lot := v_mitem.lot_id;
    end if;

    if v_qty <= 0 then
      raise exception 'line %: quantity must be more than zero', v_line_no using errcode = '22023';
    end if;

    if v_pet is not null and v_mitem.id is null then
      if v_customer is null or not exists (
        select 1 from public.pet_owners
        where pet_id = v_pet and customer_id = v_customer and to_date is null
      ) then
        raise exception 'line %: the pet does not belong to this customer', v_line_no using errcode = '22023';
      end if;
    end if;

    if v_ticket.id is not null or v_charge.id is not null or v_mitem.id is not null then
      null; -- priced above
    elsif v_kind = 'product' then
      select * into v_product from public.products where id = v_item and is_active;
      if not found then
        raise exception 'line %: product is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_product.name;
      v_unit := v_product.unit;
      v_unit_id := nullif(v_line ->> 'unit_id', '')::uuid;
      if v_unit_id is not null then
        select * into v_unit_row from public.product_units
        where id = v_unit_id and product_id = v_item and is_active and for_sale;
        if not found then
          raise exception 'line %: the unit is not available', v_line_no using errcode = 'P0002', hint = 'unit_not_available';
        end if;
        v_unit := v_unit_row.name;
        v_factor := v_unit_row.factor;
      end if;
      v_price := public.product_unit_price(v_item, v_branch, v_unit_id);
      -- Stock is taken FEFO by the take_stock trigger on invoice_lines (inventory migration).
    elsif v_kind = 'combo' then
      select * into v_combo from public.pet_service_combos
      where id = v_item and status = 1 and is_active;
      if not found or v_combo.price is null then
        raise exception 'line %: combo is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_combo.name;
      v_price := v_combo.price;
    elsif v_kind = 'service' then
      select * into v_service from public.pet_services where id = v_item and is_active;
      if not found then
        raise exception 'line %: service is not available', v_line_no using errcode = 'P0002';
      end if;
      v_name := v_service.name;
      if v_service.type = 'by_weight' then
        if v_pet is null then
          raise exception 'line %: pick the pet for a by-weight service', v_line_no using errcode = '22023';
        end if;
        select species_id into v_species from public.pets where id = v_pet;
        v_weight := coalesce(
          nullif(v_line ->> 'weight_kg', '')::numeric,
          (select weight_kg from public.pet_weight_logs where pet_id = v_pet order by measured_at desc limit 1)
        );
        if v_weight is null or v_weight <= 0 then
          raise exception 'line %: the pet has no weight yet', v_line_no using errcode = '22023';
        end if;
        v_price := public.get_service_price(v_species, v_service.id, v_weight, v_branch);
      else
        v_price := v_service.general_price;
      end if;
      if v_price is null then
        raise exception 'line %: service has no price for this pet', v_line_no using errcode = 'P0002';
      end if;
    else
      raise exception 'line %: unknown type %', v_line_no, v_kind using errcode = '22023';
    end if;

    insert into public.invoice_lines (
      invoice_id, line_no, item_type, product_id, service_id, combo_id, pet_id, pet_name,
      name, unit, qty, unit_price, amount, weight_kg, unit_id, unit_factor, lot_id
    ) values (
      v_id, v_line_no, v_kind,
      case when v_kind = 'product' then v_item end,
      case when v_kind = 'service' then v_item end,
      case when v_kind = 'combo' then v_item end,
      v_pet, (select name from public.pets where id = v_pet), v_name, v_unit, v_qty, v_price, round(v_qty * v_price, 2), v_weight,
      v_unit_id, v_factor, v_lot
    )
    returning id into v_line_id;
    if v_mitem.id is not null then
      update public.medical_visit_items set invoice_line_id = v_line_id where id = v_mitem.id;
      perform public.medical_refresh_status(v_mitem.visit_id);
    end if;
    if v_charge.id is not null then
      update public.boarding_charges set invoice_line_id = v_line_id where id = v_charge.id;
      perform public.refresh_boarding_stay_status(v_charge.stay_id);
    end if;
    if v_ticket.id is not null then
      update public.appointment_items set invoice_line_id = v_line_id where id = v_ticket.id;
      perform public.refresh_appointment_status(v_ticket_appt);
    end if;
    v_subtotal := v_subtotal + round(v_qty * v_price, 2);
  end loop;

  if v_discount < 0 or v_discount > v_subtotal then
    raise exception 'discount must be between 0 and the subtotal' using errcode = '22023';
  end if;
  if v_discount > v_subtotal * c_discount_limit and not public.can_pos('UPDATE', v_branch) then
    raise exception 'a discount above 10%% needs a manager' using errcode = '42501', hint = 'discount_limit';
  end if;
  v_total := v_subtotal - v_discount;

  for v_pay in select * from jsonb_array_elements(coalesce(p -> 'payments', '[]'::jsonb)) loop
    v_method := v_pay ->> 'method';
    v_amount := coalesce(nullif(v_pay ->> 'amount', '')::numeric, 0);
    if v_amount <= 0 then
      continue;
    end if;
    if v_method not in ('cash', 'transfer', 'card') then
      raise exception 'unknown payment method %', v_method using errcode = '22023';
    end if;
    insert into public.payments (invoice_id, method, amount, bank_ref)
    values (v_id, v_method, v_amount, nullif(btrim(v_pay ->> 'bank_ref'), ''));
    v_paid := v_paid + v_amount;
    if v_method = 'cash' then
      v_cash := v_cash + v_amount;
    end if;
  end loop;

  if v_paid < v_total then
    raise exception 'payments do not cover the total' using errcode = '22023', hint = 'underpaid';
  end if;
  v_change := v_paid - v_total;
  -- Only cash can be overpaid and handed back.
  if v_change > v_cash then
    raise exception 'transfer and card cannot exceed the total' using errcode = '22023', hint = 'overpaid';
  end if;

  update public.invoices
  set subtotal = v_subtotal,
      discount_amount = v_discount,
      total = v_total,
      paid_amount = v_paid,
      change_amount = v_change
  where id = v_id;

  return jsonb_build_object('id', v_id, 'code', v_code, 'total', v_total, 'change_amount', v_change, 'replayed', false);
end;
$$;


ALTER FUNCTION "public"."create_invoice"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_order"("p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid;
  v_line jsonb;
  v_kind text;
  v_line_id uuid;
  v_name text;
  v_price numeric;
  v_minutes int;
  v_service public.pet_services;
  v_combo public.pet_service_combos;
  v_lines int := 0;
begin
  insert into public.orders (name, phone_number, pet_num, scheduled_at, user_id)
  values (
    p ->> 'name',
    p ->> 'phone_number',
    nullif(p ->> 'pet_num', '')::int,
    nullif(p ->> 'scheduled_at', '')::timestamptz,
    auth.uid()
  )
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(coalesce(p -> 'services', '[]'::jsonb)) loop
    v_kind := v_line ->> 'type';
    v_line_id := (v_line ->> 'id')::uuid;

    if v_kind = 'combo' then
      select * into v_combo from public.pet_service_combos where id = v_line_id and status = 1;
      if not found or v_combo.price is null then
        raise exception 'combo % is not available', v_line_id using errcode = 'P0002';
      end if;
      v_name := v_combo.name;
      v_price := v_combo.price;
      v_minutes := v_combo.duration_minutes;
    elsif v_kind = 'service' then
      select * into v_service from public.pet_services where id = v_line_id and is_show;
      if not found then
        raise exception 'service % is not available', v_line_id using errcode = 'P0002';
      end if;
      if v_service.type = 'by_weight' then
        v_price := public.get_service_price(
          nullif(v_line ->> 'species_id', '')::uuid,
          v_service.id,
          nullif(v_line ->> 'weight_kg', '')::numeric
        );
      else
        v_price := v_service.general_price;
      end if;
      if v_price is null then
        raise exception 'service % has no price for this pet', v_line_id using errcode = 'P0002';
      end if;
      v_name := v_service.name;
      v_minutes := v_service.duration_minutes;
    else
      raise exception 'unknown line type %', v_kind using errcode = '22023';
    end if;

    insert into public.order_items (order_id, service_id, combo_id, name, price, duration_minutes)
    values (
      v_id,
      case when v_kind = 'service' then v_line_id end,
      case when v_kind = 'combo' then v_line_id end,
      v_name,
      v_price,
      v_minutes
    );
    v_lines := v_lines + 1;
  end loop;

  if v_lines = 0 then
    raise exception 'an order needs at least one service' using errcode = '22023';
  end if;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."create_order"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sales_return"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid      uuid := (select auth.uid());
  v_invoice  public.invoices;
  v_shift    uuid;
  v_method   text := coalesce(p ->> 'refund_method', 'cash');
  v_reason   text := btrim(coalesce(p ->> 'reason', ''));
  v_id       uuid;
  v_code     text;
  v_line     jsonb;
  v_inv_line public.invoice_lines;
  v_qty      numeric;
  v_returned numeric;
  v_amount   numeric;
  v_refund   numeric := 0;
  v_left     numeric;
  v_take     numeric;
  v_lot      record;
  v_line_refunded    numeric;
  v_invoice_refunded numeric;
begin
  select * into v_invoice from public.invoices where id = nullif(p ->> 'invoice_id', '')::uuid for update;
  if not found then
    raise exception 'invoice not found' using errcode = 'P0002';
  end if;
  if v_uid is null or not public.can_pos('DELETE', v_invoice.branch_id) then
    raise exception 'not allowed to take returns' using errcode = '42501';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'invoice is cancelled' using errcode = '22023';
  end if;
  if v_method not in ('cash', 'transfer') then
    raise exception 'unknown refund method %', v_method using errcode = '22023';
  end if;
  if length(v_reason) = 0 then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  if jsonb_array_length(coalesce(p -> 'lines', '[]'::jsonb)) = 0 then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  select id into v_shift
  from public.cash_shifts
  where branch_id = v_invoice.branch_id and opened_by = v_uid and status = 'open'
  for share;
  if v_shift is null then
    raise exception 'open a cash shift before refunding' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  v_code := public.next_doc_code(v_invoice.branch_id, 'TH');
  insert into public.sales_returns (
    code, branch_id, invoice_id, shift_id, refund_method, refund_amount, reason, created_by, created_by_name
  ) values (
    v_code, v_invoice.branch_id, v_invoice.id, v_shift, v_method, 0, v_reason, v_uid,
    public.staff_display_name(v_uid)
  )
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p -> 'lines') loop
    v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
    if v_qty <= 0 then
      continue;
    end if;

    select * into v_inv_line from public.invoice_lines
    where id = nullif(v_line ->> 'invoice_line_id', '')::uuid and invoice_id = v_invoice.id
    for update;
    if not found then
      raise exception 'the line is not on this invoice' using errcode = 'P0002';
    end if;
    if v_inv_line.item_type <> 'product' then
      raise exception '% is not a product', v_inv_line.name using errcode = '22023', hint = 'return_products_only';
    end if;

    select coalesce(sum(qty), 0) into v_returned
    from public.sales_return_lines where invoice_line_id = v_inv_line.id;
    if v_qty > v_inv_line.qty - v_returned then
      raise exception 'only % of % can still be returned', v_inv_line.qty - v_returned, v_inv_line.name
        using errcode = '22023', hint = 'return_too_much', detail = v_inv_line.name;
    end if;

    -- Whole dong: what the units returned so far (this one included) cost the customer, less
    -- what earlier returns of the line refunded, and never more than is left of the invoice.
    select coalesce(sum(amount), 0) into v_line_refunded
    from public.sales_return_lines where invoice_line_id = v_inv_line.id;
    v_amount := case when v_invoice.subtotal > 0
      then round(v_inv_line.amount * (v_returned + v_qty) / v_inv_line.qty * v_invoice.total / v_invoice.subtotal)
           - v_line_refunded
      else 0 end;
    select coalesce(sum(l.amount), 0) into v_invoice_refunded
    from public.sales_return_lines l
    join public.sales_returns r on r.id = l.return_id
    where r.invoice_id = v_invoice.id;
    v_amount := greatest(0, least(v_amount, v_invoice.total - v_invoice_refunded));
    insert into public.sales_return_lines (return_id, invoice_line_id, product_id, name, qty, amount)
    values (v_id, v_inv_line.id, v_inv_line.product_id, v_inv_line.name, v_qty, v_amount);
    v_refund := v_refund + v_amount;

    -- Back into the lots this line still has out, the latest taken first. A line sold before
    -- the product tracked stock has none and returns nothing to stock.
    v_left := v_qty * v_inv_line.unit_factor;
    for v_lot in
      select lot_id, -sum(qty) as out_qty
      from public.stock_movements
      where invoice_line_id = v_inv_line.id
      group by lot_id
      having sum(qty) < 0
      order by max(created_at) desc, lot_id
    loop
      exit when v_left <= 0;
      v_take := least(v_left, v_lot.out_qty);
      perform public.move_stock(
        v_lot.lot_id, v_take, 'return', p_invoice => v_invoice.id, p_invoice_line => v_inv_line.id, p_return => v_id
      );
      v_left := v_left - v_take;
    end loop;
  end loop;

  if not exists (select 1 from public.sales_return_lines where return_id = v_id) then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  update public.sales_returns set refund_amount = v_refund where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'refund_amount', v_refund);
end;
$$;


ALTER FUNCTION "public"."create_sales_return"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."custom_access_token_hook"("event" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO ''
    AS $$
declare
  claims     jsonb;
  user_role  text;
  branch_ids jsonb;
begin
  select role into user_role
  from public.users
  where id = (event ->> 'user_id')::uuid;

  select coalesce(jsonb_agg(branch_id), '[]'::jsonb) into branch_ids
  from public.staff_branches
  where user_id = (event ->> 'user_id')::uuid;

  claims := jsonb_set(event -> 'claims', '{user_role}', to_jsonb(coalesce(user_role, 'customer')));
  claims := jsonb_set(claims, '{branch_ids}', branch_ids);
  return jsonb_set(event, '{claims}', claims);
end;
$$;


ALTER FUNCTION "public"."custom_access_token_hook"("event" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_care_log"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_log public.boarding_care_logs;
  v_uid uuid := (select auth.uid());
begin
  select * into v_log from public.boarding_care_logs where id = p_id;
  if not found then
    raise exception 'log % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('DELETE', v_log.branch_id) then
    if not public.can_boarding('VIEW', v_log.branch_id)
       or not (v_log.created_by = v_uid or public.can_boarding('UPDATE', v_log.branch_id)) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    if v_log.logged_at < now() - interval '24 hours' then
      raise exception 'the log is older than a day' using errcode = 'P0001', hint = 'too_old';
    end if;
  end if;
  delete from public.boarding_care_logs where id = p_id;
end;
$$;


ALTER FUNCTION "public"."delete_care_log"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_my_address"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid     uuid := (select auth.uid());
  v_default boolean;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('customer_addresses:' || v_uid::text, 0));
  delete from public.customer_addresses where id = p_id and user_id = v_uid returning is_default into v_default;
  if not found then
    raise exception 'address not found' using errcode = 'P0002', hint = 'address_not_found';
  end if;
  if v_default then
    update public.customer_addresses set is_default = true
    where id = (
      select id from public.customer_addresses where user_id = v_uid order by created_at desc, id limit 1
    );
  end if;
end;
$$;


ALTER FUNCTION "public"."delete_my_address"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_product_brand"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_products('DELETE') then
    raise exception 'not allowed to delete products' using errcode = '42501';
  end if;
  begin
    delete from public.product_brands where id = p_id;
  exception when foreign_key_violation then
    raise exception 'brand is in use' using errcode = '23503', hint = 'in_use';
  end;
  if not found then
    raise exception 'brand % not found', p_id using errcode = 'P0002';
  end if;
end;
$$;


ALTER FUNCTION "public"."delete_product_brand"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_product_category"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_products('DELETE') then
    raise exception 'not allowed to delete products' using errcode = '42501';
  end if;
  if exists (select 1 from public.product_categories where parent_id = p_id) then
    raise exception 'category has sub-categories' using errcode = '23503', hint = 'has_children';
  end if;
  begin
    delete from public.product_categories where id = p_id;
  exception when foreign_key_violation then
    raise exception 'category is in use' using errcode = '23503', hint = 'in_use';
  end;
  if not found then
    raise exception 'category % not found', p_id using errcode = 'P0002';
  end if;
end;
$$;


ALTER FUNCTION "public"."delete_product_category"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."deliver_shop_order"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o public.shop_orders := public.shop_order_for_update(p_id, array['shipping']);
  i public.invoices;
begin
  select * into i from public.invoices where id = o.invoice_id for update;
  update public.invoices set status = 'paid', paid_amount = total, change_amount = 0 where id = i.id;
  if i.total > 0 then
    insert into public.payments (invoice_id, method, amount) values (i.id, 'cod', i.total);
  end if;
  update public.shop_orders set status = 'completed', completed_at = now() where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'completed');
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."deliver_shop_order"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."discharge_inpatient"("p_stay" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_stay  public.boarding_stays;
  v_calc  jsonb;
  v_item  jsonb;
  v_total numeric;
begin
  select * into v_stay from public.boarding_stays where id = p_stay for update;
  if not found or v_stay.kind <> 'inpatient' then
    raise exception 'stay not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.status <> 'checked_in' then
    raise exception 'the pet is not in the clinic' using errcode = 'P0001', hint = 'not_editable';
  end if;

  v_calc := public.boarding_checkout_calc(v_stay, now());
  for v_item in select * from jsonb_array_elements(v_calc -> 'items') loop
    insert into public.boarding_charges (
      stay_id, stay_pet_id, branch_id, kind, name, qty, unit_price, amount, created_by
    )
    values (
      p_stay, (v_item ->> 'stay_pet_id')::uuid, v_stay.branch_id, v_item ->> 'kind', v_item ->> 'name',
      (v_item ->> 'qty')::numeric, (v_item ->> 'unit_price')::numeric, (v_item ->> 'amount')::numeric,
      (select auth.uid())
    );
  end loop;
  for v_item in select * from jsonb_array_elements(v_calc -> 'pets') loop
    update public.boarding_stay_pets set
      nights = daterange(lower(nights), (v_item ->> 'nights_to')::date),
      charged_nights = (v_item ->> 'charged_nights')::numeric
    where id = (v_item ->> 'stay_pet_id')::uuid;
  end loop;

  update public.kennels set status = 'cleaning'
  where status = 'ready'
    and id in (select kennel_id from public.boarding_stay_pets where stay_id = p_stay and status = 'active');
  update public.boarding_stays set status = 'checked_out', checked_out_at = now() where id = p_stay;

  update public.inpatient_orders set stopped_at = coalesce(stopped_at, now()) where stay_id = p_stay;
  delete from public.inpatient_doses d using public.inpatient_orders o
  where d.order_id = o.id and o.stay_id = p_stay and d.given_at is null and d.skipped_reason is null;

  select coalesce(sum(amount), 0) into v_total from public.boarding_charges where stay_id = p_stay;
  return jsonb_build_object('id', p_stay, 'code', v_stay.code, 'total', v_total, 'visit_id', v_stay.visit_id);
end;
$$;


ALTER FUNCTION "public"."discharge_inpatient"("p_stay" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."export_products"("p_limit" integer DEFAULT 500, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_rows  jsonb;
  v_total int;
begin
  if not public.can_products('VIEW') then
    raise exception 'not allowed to view products' using errcode = '42501';
  end if;
  select count(*) into v_total from public.products where group_id is not null;

  select coalesce(jsonb_agg(x.j order by x.n, x.gid, x.so, x.pid), '[]'::jsonb) into v_rows
  from (
    select
      lower(g.name) as n, g.id as gid, p.sort_order as so, p.id as pid,
      jsonb_build_object(
        'group', g.name,
        'category', (
          select case when c.parent_id is null then c.name
                      else (select pc.name from public.product_categories pc where pc.id = c.parent_id) || ' > ' || c.name end
          from public.product_categories c where c.id = g.category_id
        ),
        'brand', (select b.name from public.product_brands b where b.id = g.brand_id),
        'description', g.description,
        'images', coalesce((select jsonb_agg(i.url order by i.sort_order) from public.product_images i where i.group_id = g.id), '[]'::jsonb),
        'attrs', coalesce((
          select jsonb_agg(jsonb_build_object('name', a.name, 'value', v.value) order by ga.sort_order)
          from public.product_variant_values pv
          join public.product_attributes a on a.id = pv.attribute_id
          join public.product_attribute_values v on v.id = pv.value_id
          join public.product_group_attributes ga on ga.group_id = g.id and ga.attribute_id = a.id
          where pv.product_id = p.id
        ), '[]'::jsonb),
        'sku', p.sku,
        'barcode', p.barcode,
        'unit', p.unit,
        'price', p.price,
        'track_stock', p.track_stock,
        'is_active', p.is_active,
        'units', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', u.name, 'factor', u.factor, 'barcode', u.barcode, 'price', u.price,
            'for_sale', u.for_sale, 'for_purchase', u.for_purchase) order by u.factor)
          from public.product_units u where u.product_id = p.id and u.is_active
        ), '[]'::jsonb)
      ) as j
    from public.products p
    join public.product_groups g on g.id = p.group_id
    order by lower(g.name), g.id, p.sort_order, p.id
    limit greatest(p_limit, 0) offset greatest(p_offset, 0)
  ) x;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."export_products"("p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."extend_boarding_stay"("p_id" "uuid", "p_planned_out_at" timestamp with time zone) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
  if v_stay.kind = 'inpatient' then
    raise exception 'an inpatient stay is managed on the inpatient screen' using errcode = 'P0001', hint = 'inpatient_stay';
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


ALTER FUNCTION "public"."extend_boarding_stay"("p_id" "uuid", "p_planned_out_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_by_barcode"("p_code" "text", "p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  with code as (select nullif(btrim(coalesce(p_code, '')), '') as v), hit as (
    select p.id as product_id, null::uuid as unit_id, p.name, p.unit, 1::numeric as factor, 0 as ord
    from public.products p, code
    where code.v is not null and p.barcode = code.v and p.is_active
    union all
    select p.id, u.id, p.name, u.name, u.factor, 1
    from public.product_units u
    join public.products p on p.id = u.product_id, code
    where code.v is not null and u.barcode = code.v and u.is_active and u.for_sale and p.is_active
  )
  select jsonb_build_object(
    'product_id', h.product_id,
    'unit_id', h.unit_id,
    'name', h.name,
    'unit', h.unit,
    'factor', h.factor,
    'price', public.product_unit_price(h.product_id, p_branch, h.unit_id)
  )
  from hit h
  order by h.ord
  limit 1;
$$;


ALTER FUNCTION "public"."find_by_barcode"("p_code" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."find_products_by_sku"("p_skus" "text"[]) RETURNS TABLE("sku" "text", "product_id" "uuid", "name" "text", "unit" "text", "track_stock" boolean, "units" "jsonb")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_inventory('CREATE') then
    raise exception 'not allowed to receive stock' using errcode = '42501';
  end if;
  if coalesce(array_length(p_skus, 1), 0) > 2000 then
    raise exception 'at most 2000 SKUs per call' using errcode = '22023', hint = 'too_many_rows';
  end if;

  return query
  select p.sku,
         p.id,
         p.name,
         p.unit,
         p.track_stock,
         coalesce((
           select jsonb_agg(jsonb_build_object('id', u.id, 'name', u.name, 'factor', u.factor, 'for_purchase', u.for_purchase)
                            order by u.sort_order, u.factor)
           from public.product_units u
           where u.product_id = p.id and u.is_active
         ), '[]'::jsonb)
  from public.products p
  where p.is_active
    and p.sku is not null
    and lower(btrim(p.sku)) in (select lower(btrim(x)) from unnest(p_skus) as x);
end;
$$;


ALTER FUNCTION "public"."find_products_by_sku"("p_skus" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_appointment"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."get_appointment"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_boarding_stay"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_stay public.boarding_stays;
  v_uid  uuid := (select auth.uid());
begin
  select * into v_stay from public.boarding_stays where id = p_id;
  if not found then
    raise exception 'stay % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('VIEW', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return public.boarding_stay_json(v_stay) || jsonb_build_object(
    'care_logs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'stay_pet_id', l.stay_pet_id,
        'pet_name', sp.pet_name,
        'kind', l.kind,
        'meal_eaten', l.meal_eaten,
        'content', l.content,
        'visible_to_customer', l.visible_to_customer,
        'logged_at', l.logged_at,
        'created_by_name', case when l.created_by is null then null else public.staff_display_name(l.created_by) end,
        'can_delete', public.can_boarding('DELETE', l.branch_id)
          or (l.logged_at >= now() - interval '24 hours'
              and (l.created_by = v_uid or public.can_boarding('UPDATE', l.branch_id)))
      ) order by l.logged_at desc)
      from public.boarding_care_logs l
      join public.boarding_stay_pets sp on sp.id = l.stay_pet_id
      where l.stay_id = p_id
    ), '[]'::jsonb),
    'charges', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'stay_pet_id', c.stay_pet_id,
        'pet_name', sp.pet_name,
        'kind', c.kind,
        'name', c.name,
        'qty', c.qty,
        'unit_price', c.unit_price,
        'amount', c.amount,
        'invoice_line_id', c.invoice_line_id
      ) order by c.created_at, c.id)
      from public.boarding_charges c
      left join public.boarding_stay_pets sp on sp.id = c.stay_pet_id
      where c.stay_id = p_id
    ), '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."get_boarding_stay"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_medical_visit"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v public.medical_visits;
begin
  select * into v from public.medical_visits where id = p_id;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return public.medical_visit_json(v) || jsonb_build_object(
    'branch_name', (select b.name from public.branches b where b.id = v.branch_id),
    'subjective', v.subjective,
    'objective', v.objective,
    'assessment', v.assessment,
    'plan', v.plan,
    'owner_instructions', v.owner_instructions,
    'temperature_c', v.temperature_c,
    'heart_rate', v.heart_rate,
    'resp_rate', v.resp_rate,
    'vitals_note', v.vitals_note,
    'signed_by_name', v.signed_by_name,
    'cancelled_at', v.cancelled_at,
    'cancel_reason', v.cancel_reason,
    'source', v.source,
    'follow_up_code', (select f.code from public.medical_visits f where f.id = v.follow_up_of),
    'recheck_visit', (
      select jsonb_build_object('id', r.id, 'code', r.code, 'scheduled_at', r.scheduled_at, 'status', r.status)
      from public.medical_visits r where r.follow_up_of = v.id order by r.created_at desc limit 1
    ),
    'pet', (
      select jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'species_name', s.name,
        'breed', p.breed,
        'sex', p.sex,
        'neutered', p.neutered,
        'birth_date', p.birth_date,
        'allergies', p.allergies,
        'behavior_notes', p.behavior_notes,
        'status', p.status,
        'photo_url', p.photo_url,
        'last_weight_kg', (select w.weight_kg from public.pet_weight_logs w where w.pet_id = p.id order by w.measured_at desc limit 1)
      )
      from public.pets p join public.species s on s.id = p.species_id where p.id = v.pet_id
    ),
    'diagnoses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id, 'term_id', d.term_id, 'name', d.name, 'is_contagious', d.is_contagious, 'note', d.note
      ) order by d.sort_order)
      from public.medical_diagnoses d where d.visit_id = v.id
    ), '[]'::jsonb),
    'addenda', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'content', a.content, 'created_by_name', a.created_by_name, 'created_at', a.created_at
      ) order by a.created_at)
      from public.medical_addenda a where a.visit_id = v.id
    ), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', i.id, 'kind', i.kind, 'service_id', i.service_id, 'product_id', i.product_id,
        'name', i.name, 'qty', i.qty, 'unit_name', coalesce(i.unit_name, (select p.unit from public.products p where p.id = i.product_id)),
        'unit_price', i.unit_price, 'amount', i.amount, 'take_home', i.take_home, 'dose', i.dose,
        'frequency', i.frequency, 'days', i.days, 'route', i.route, 'instructions', i.instructions,
        'auto_added', i.auto_added, 'invoice_line_id', i.invoice_line_id,
        'created_by_name', i.created_by_name, 'created_at', i.created_at
      ) order by i.created_at, i.id)
      from public.medical_visit_items i where i.visit_id = v.id
    ), '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."get_medical_visit"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_service_price"("p_species_id" "uuid", "p_service_id" "uuid", "p_weight_kg" numeric, "p_branch_id" "uuid" DEFAULT NULL::"uuid") RETURNS numeric
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select case
    when sv.type = 'all' then sv.general_price
    else (
      select pr.price
      from public.weight_brackets b
      join public.pet_service_prices pr
        on pr.bracket_id = b.id
       and pr.service_id = sv.id
       and (pr.branch_id is null or pr.branch_id = p_branch_id)
      where b.species_id = p_species_id
        and p_weight_kg >= b.min_kg
        and (b.max_kg is null or p_weight_kg < b.max_kg)
      order by (pr.branch_id is not null) desc
      limit 1
    )
  end
  from public.pet_services sv
  where sv.id = p_service_id;
$$;


ALTER FUNCTION "public"."get_service_price"("p_species_id" "uuid", "p_service_id" "uuid", "p_weight_kg" numeric, "p_branch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_order"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o public.shop_orders;
begin
  select * into o from public.shop_orders where id = p_id;
  if not found or not public.can_shop_orders('VIEW', o.branch_id) then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."get_shop_order"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."give_inpatient_dose"("p_dose" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid   uuid := (select auth.uid());
  v_dose  public.inpatient_doses;
  v_order public.inpatient_orders;
  v_stay  public.boarding_stays;
  v_qty   numeric;
  v_res   jsonb := '{"warnings": []}'::jsonb;
  v_item  uuid;
begin
  select * into v_dose from public.inpatient_doses where id = p_dose for update;
  if not found then
    raise exception 'dose not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_order from public.inpatient_orders where id = v_dose.order_id for update;
  select * into v_stay from public.boarding_stays where id = v_order.stay_id;
  if not public.can_medical('UPDATE', v_order.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_stay.status <> 'checked_in' then
    raise exception 'the pet is not in the clinic' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_dose.given_at is not null or v_dose.skipped_reason is not null then
    raise exception 'the dose is already recorded' using errcode = 'P0001', hint = 'already_done';
  end if;

  if v_order.kind in ('product', 'service') then
    v_item := v_order.item_id;
    if v_item is not null then
      select qty into v_qty from public.medical_visit_items where id = v_item;
      if not found then
        v_item := null;
      end if;
    end if;
    if v_item is null then
      v_res := public.add_medical_item(v_order.visit_id, jsonb_build_object(
        'kind', v_order.kind, 'product_id', v_order.product_id, 'service_id', v_order.service_id,
        'qty', v_order.qty_per_dose, 'dose', v_order.dose
      ));
      update public.inpatient_orders set item_id = (v_res ->> 'id')::uuid where id = v_order.id;
    else
      v_res := public.update_medical_item(v_item, jsonb_build_object('qty', v_qty + v_order.qty_per_dose));
    end if;
  end if;

  update public.inpatient_doses
  set given_at = now(), given_by = v_uid, given_by_name = public.staff_display_name(v_uid),
      qty = v_order.qty_per_dose
  where id = p_dose;
  return jsonb_build_object('warnings', coalesce(v_res -> 'warnings', '[]'::jsonb));
end;
$$;


ALTER FUNCTION "public"."give_inpatient_dose"("p_dose" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."give_vaccination"("p_visit" "uuid", "p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid     uuid := (select auth.uid());
  v_visit   public.medical_visits;
  v_type    public.vaccine_types;
  v_pet     public.pets;
  v_lot     public.stock_lots;
  v_product public.products;
  v_dose    int;
  v_today   date := public.business_date();
  v_due     date;
  v_id      uuid;
  v_item    uuid;
  v_name    text;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into v_visit from public.medical_visits where id = p_visit for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status not in ('in_progress', 'done', 'paid') then
    raise exception 'the visit is not open' using errcode = 'P0001', hint = 'not_editable';
  end if;
  select * into v_type from public.vaccine_types where id = nullif(p ->> 'vaccine_type_id', '')::uuid and is_active;
  if not found then
    raise exception 'vaccine type is not available' using errcode = 'P0002', hint = 'no_vaccine';
  end if;
  select * into v_pet from public.pets where id = v_visit.pet_id;

  v_dose := coalesce(nullif(p ->> 'dose_no', '')::int, public.medical_next_dose_no(v_pet.id, v_type.id));
  if v_dose <= 0 then
    raise exception 'bad dose number' using errcode = '22023', hint = 'bad_input';
  end if;
  v_due := case when p ? 'next_due_on' then nullif(p ->> 'next_due_on', '')::date
                else public.medical_next_due(v_type.id, v_dose, v_today) end;

  if cardinality(v_type.species_ids) > 0 and not (v_pet.species_id = any (v_type.species_ids)) then
    v_warnings := v_warnings || to_jsonb('species_mismatch'::text);
  end if;
  if v_type.min_age_weeks is not null and v_pet.birth_date is not null
     and v_pet.birth_date > v_today - (v_type.min_age_weeks * 7) then
    v_warnings := v_warnings || to_jsonb('too_young'::text);
  end if;

  if v_type.product_id is not null then
    select * into v_product from public.products where id = v_type.product_id;
    if nullif(p ->> 'lot_id', '') is not null then
      select * into v_lot from public.stock_lots
      where id = (p ->> 'lot_id')::uuid and branch_id = v_visit.branch_id and product_id = v_type.product_id
        and qty_on_hand > 0 and (expiry_date is null or expiry_date >= v_today);
    else
      select * into v_lot from public.stock_lots
      where branch_id = v_visit.branch_id and product_id = v_type.product_id
        and qty_on_hand > 0 and (expiry_date is null or expiry_date >= v_today)
      order by expiry_date nulls last, received_at limit 1;
    end if;
    if v_lot.id is null then
      raise exception 'no usable batch in stock' using errcode = 'P0001', hint = 'no_lot', detail = v_type.name;
    end if;
  end if;

  insert into public.vaccinations (
    pet_id, vaccine_type_id, branch_id, dose_no, given_on, visit_id, lot_id, lot_no, expiry_date,
    vet_name, next_due_on, created_by
  ) values (
    v_pet.id, v_type.id, v_visit.branch_id, v_dose, v_today, p_visit, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
    coalesce(v_visit.vet_name, public.staff_display_name(v_uid)), v_due, v_uid
  ) returning id into v_id;

  if v_type.product_id is not null then
    v_name := v_type.name || ' (' || v_dose || ')';
    insert into public.medical_visit_items (
      visit_id, branch_id, kind, product_id, unit_name, name, qty, unit_price, amount,
      lot_id, vaccination_id, created_by, created_by_name
    ) values (
      p_visit, v_visit.branch_id, 'product', v_product.id, v_product.unit, v_name, 1,
      coalesce(public.product_unit_price(v_product.id, v_visit.branch_id, null), 0),
      round(coalesce(public.product_unit_price(v_product.id, v_visit.branch_id, null), 0), 2),
      v_lot.id, v_id, v_uid, public.staff_display_name(v_uid)
    ) returning id into v_item;
    update public.vaccinations set visit_item_id = v_item where id = v_id;
  end if;

  perform public.medical_refresh_status(p_visit);
  return jsonb_build_object('id', v_id, 'item_id', v_item, 'warnings', v_warnings);
end;
$$;


ALTER FUNCTION "public"."give_vaccination"("p_visit" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."guard_user_columns"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if (select auth.uid()) is not null then
    if new.role is distinct from old.role and not (select public.is_super_admin()) then
      raise exception 'only a superAdmin can change a role' using errcode = '42501';
    end if;
    if new.email is distinct from old.email then
      raise exception 'email is managed by authentication' using errcode = '42501';
    end if;
    if new.id is distinct from old.id then
      raise exception 'id is immutable' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."guard_user_columns"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  insert into public.users (id, email, display_name, full_name, phone_number, photo_url)
  values (
    new.id,
    new.email,
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    coalesce(nullif(new.raw_user_meta_data ->> 'full_name', ''),
             nullif(new.raw_user_meta_data ->> 'name', '')),
    nullif(new.phone, ''),
    coalesce(new.raw_user_meta_data ->> 'avatar_url',
             new.raw_user_meta_data ->> 'picture')
  );
  return new;
end;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."has_permission"("p_permission" "text", "p_method" "text", "p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select (select public.is_super_admin()) or exists (
    select 1
    from public.staff_branches sb
    join public.role_permissions rp on rp.role = sb.role
    where sb.user_id = (select auth.uid())
      and (p_branch is null or sb.branch_id = p_branch)
      and rp.permission = p_permission
      and rp.methods && array[upper(p_method), 'ALL']
  );
$$;


ALTER FUNCTION "public"."has_permission"("p_permission" "text", "p_method" "text", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."immutable_unaccent"("text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE STRICT PARALLEL SAFE
    SET "search_path" TO ''
    AS $_$ select extensions.unaccent('extensions.unaccent'::regdictionary, $1) $_$;


ALTER FUNCTION "public"."immutable_unaccent"("text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_add_error"("p_errors" "jsonb", "p_row" "text", "p_note" "text") RETURNS "jsonb"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select jsonb_set(
    coalesce(p_errors, '{}'::jsonb),
    array[p_row],
    coalesce(p_errors -> p_row, '[]'::jsonb) || to_jsonb(p_note)
  );
$$;


ALTER FUNCTION "public"."import_add_error"("p_errors" "jsonb", "p_row" "text", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_error_text"("p_hint" "text", "p_message" "text", "p_detail" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select case p_hint
    when 'duplicate_name'      then 'Tên nhóm đã có'
    when 'duplicate_sku'       then 'SKU đã được dùng: ' || coalesce(p_detail, '')
    when 'duplicate_barcode'   then 'Mã vạch đã được dùng: ' || coalesce(p_detail, '')
    when 'duplicate_variant'   then 'Hai biến thể có cùng giá trị thuộc tính'
    when 'duplicate_attribute' then 'Một thuộc tính bị lặp'
    when 'variant_options'     then 'Giá trị thuộc tính không hợp lệ'
    when 'invalid_category'    then 'Danh mục đang tắt'
    when 'invalid_brand'       then 'Thương hiệu đang tắt'
    when 'too_many_images'     then 'Tối đa 8 ảnh mỗi nhóm'
    when 'category_depth'      then 'Danh mục tối đa 2 cấp'
    when 'duplicate_unit'      then 'Tên đơn vị bị trùng: ' || coalesce(p_detail, '')
    when 'unit_factor'         then 'Hệ số đơn vị phải lớn hơn 1: ' || coalesce(p_detail, '')
    when 'unit_in_use'         then 'Đơn vị đã dùng nên không đổi hệ số: ' || coalesce(p_detail, '')
    when 'unit_name_required'  then 'Đơn vị cần có tên'
    else coalesce(p_message, 'Lỗi không rõ')
  end;
$$;


ALTER FUNCTION "public"."import_error_text"("p_hint" "text", "p_message" "text", "p_detail" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_one_group"("p_rows" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_name      text := btrim(coalesce(p_rows -> 0 ->> 'group', ''));
  v_errs      jsonb := '{}'::jsonb;
  v_acts      jsonb := '{}'::jsonb;
  v_row       jsonb;
  v_n         text;
  v_sku       text;
  v_skus      text[] := '{}';
  v_barcodes  text[] := '{}';
  v_text      text;
  v_num       numeric;
  v_other     uuid;
  v_gid       uuid;
  v_g         jsonb;
  v_names     text[] := '{}';
  v_row_names text[];
  v_a         jsonb;
  v_i         int;
  v_values    jsonb[];
  v_attrs     jsonb := '[]'::jsonb;
  v_value     text;
  v_variants  jsonb := '[]'::jsonb;
  v_options   jsonb;
  v_ev        jsonb;
  v_match     jsonb;
  v_built     jsonb;
  v_units     jsonb;
  v_unit      jsonb;
  v_old_unit  jsonb;
  v_desc      text;
  v_images    jsonb;
  v_category  record;
  v_brand     record;
  v_cat_id    uuid;
  v_brand_id  uuid;
  v_payload   jsonb;
  v_created   int := 0;
  v_updated   int := 0;
begin
  -- ---------------------------------------------------------------- each row on its own
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_n := v_row ->> 'row';
    v_sku := nullif(btrim(coalesce(v_row ->> 'sku', '')), '');
    if v_sku is null then
      v_errs := public.import_add_error(v_errs, v_n, 'Thiếu SKU');
    elsif v_sku = any (v_skus) then
      v_errs := public.import_add_error(v_errs, v_n, 'SKU lặp lại trong file: ' || v_sku);
    else
      v_skus := v_skus || v_sku;
    end if;

    v_text := nullif(btrim(coalesce(v_row ->> 'barcode', '')), '');
    if v_text is not null then
      if v_text = any (v_barcodes) then
        v_errs := public.import_add_error(v_errs, v_n, 'Mã vạch lặp lại trong file: ' || v_text);
      end if;
      v_barcodes := v_barcodes || v_text;
    end if;

    begin
      v_num := nullif(btrim(coalesce(v_row ->> 'price', '')), '')::numeric;
    exception when others then
      v_num := -1;
    end;
    if v_num is null then
      v_errs := public.import_add_error(v_errs, v_n, 'Thiếu giá');
    elsif v_num < 0 then
      v_errs := public.import_add_error(v_errs, v_n, 'Giá không hợp lệ');
    end if;

    if jsonb_typeof(v_row -> 'attrs') = 'array' then
      if jsonb_array_length(v_row -> 'attrs') > 3 then
        v_errs := public.import_add_error(v_errs, v_n, 'Tối đa 3 thuộc tính');
      end if;
      for v_a in select * from jsonb_array_elements(v_row -> 'attrs') loop
        if btrim(coalesce(v_a ->> 'name', '')) = '' or btrim(coalesce(v_a ->> 'value', '')) = '' then
          v_errs := public.import_add_error(v_errs, v_n, 'Mỗi thuộc tính cần cả tên và giá trị');
        end if;
      end loop;
    end if;

    if jsonb_typeof(v_row -> 'units') = 'array' then
      for v_unit in select * from jsonb_array_elements(v_row -> 'units') loop
        begin
          v_num := nullif(btrim(coalesce(v_unit ->> 'factor', '')), '')::numeric;
        exception when others then
          v_num := null;
        end;
        if btrim(coalesce(v_unit ->> 'name', '')) = '' then
          v_errs := public.import_add_error(v_errs, v_n, 'Đơn vị quy đổi cần có tên');
        elsif v_num is null or v_num <= 1 then
          v_errs := public.import_add_error(v_errs, v_n, 'Hệ số đơn vị "' || (v_unit ->> 'name') || '" phải lớn hơn 1');
        end if;
      end loop;
    end if;
  end loop;

  -- ------------------------------------------------------------ the group and its SKUs
  select id into v_gid from public.product_groups where lower(btrim(name)) = lower(v_name);
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_sku := nullif(btrim(coalesce(v_row ->> 'sku', '')), '');
    continue when v_sku is null;
    select group_id into v_other from public.products where sku = v_sku;
    if found and v_other is distinct from v_gid then
      v_errs := public.import_add_error(
        v_errs, v_row ->> 'row',
        'SKU ' || v_sku || ' đã thuộc nhóm "' || (select name from public.product_groups where id = v_other) || '"'
      );
    end if;
  end loop;

  -- ------------------------------------------------------------------- attributes
  if v_gid is not null then
    v_g := public.product_group_json(v_gid, true);
    select coalesce(array_agg(a ->> 'name' order by ord), '{}') into v_names
    from jsonb_array_elements(v_g -> 'attributes') with ordinality as t(a, ord);
  else
    select coalesce(array_agg(a ->> 'name' order by ord), '{}') into v_names
    from jsonb_array_elements(coalesce(p_rows -> 0 -> 'attrs', '[]'::jsonb)) with ordinality as t(a, ord);
  end if;

  for v_row in select * from jsonb_array_elements(p_rows) loop
    select coalesce(array_agg(lower(btrim(a ->> 'name')) order by lower(btrim(a ->> 'name'))), '{}') into v_row_names
    from jsonb_array_elements(coalesce(v_row -> 'attrs', '[]'::jsonb)) as t(a);
    if v_row_names is distinct from (select coalesce(array_agg(lower(btrim(x)) order by lower(btrim(x))), '{}') from unnest(v_names) as x) then
      v_errs := public.import_add_error(
        v_errs, v_row ->> 'row',
        'Thuộc tính không khớp với nhóm' || case when array_length(v_names, 1) > 0 then ': ' || array_to_string(v_names, ', ') else ' (nhóm không có thuộc tính)' end
      );
    end if;
  end loop;

  if v_errs <> '{}'::jsonb then
    return jsonb_build_object('errors', v_errs, 'actions', v_acts);
  end if;

  -- Values of each attribute: the group's own first, then the new ones from the file.
  for v_i in 1 .. coalesce(array_length(v_names, 1), 0) loop
    v_values := '{}';
    if v_gid is not null then
      select coalesce(array_agg(to_jsonb(x) order by ord), '{}') into v_values
      from jsonb_array_elements_text(v_g -> 'attributes' -> (v_i - 1) -> 'values') with ordinality as t(x, ord);
    end if;
    for v_row in select * from jsonb_array_elements(p_rows) loop
      select btrim(a ->> 'value') into v_value
      from jsonb_array_elements(v_row -> 'attrs') as t(a)
      where lower(btrim(a ->> 'name')) = lower(btrim(v_names[v_i])) limit 1;
      if not exists (select 1 from unnest(v_values) as e where lower(e #>> '{}') = lower(v_value)) then
        v_values := v_values || to_jsonb(v_value);
      end if;
    end loop;
    v_attrs := v_attrs || jsonb_build_object('name', v_names[v_i], 'values', to_jsonb(v_values));
  end loop;

  -- ----------------------------------------------------------------------- variants
  -- Existing variants first (kept as they are unless a row names their SKU), then new ones.
  if v_gid is not null then
    for v_ev in select * from jsonb_array_elements(v_g -> 'variants') loop
      v_match := null;
      select r into v_match from jsonb_array_elements(p_rows) as t(r) where btrim(r ->> 'sku') = (v_ev ->> 'sku') limit 1;
      if v_match is null then
        v_variants := v_variants || jsonb_build_object(
          'id', v_ev -> 'id', 'options', v_ev -> 'options', 'sku', v_ev -> 'sku', 'barcode', v_ev -> 'barcode',
          'unit', v_ev -> 'unit', 'price', v_ev -> 'price', 'track_stock', v_ev -> 'track_stock',
          'is_active', v_ev -> 'is_active', 'image_url', v_ev -> 'image_url'
        );
      end if;
    end loop;
  end if;

  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_sku := btrim(v_row ->> 'sku');
    v_ev := null;
    if v_gid is not null then
      select e into v_ev from jsonb_array_elements(v_g -> 'variants') as t(e) where e ->> 'sku' = v_sku limit 1;
    end if;

    v_options := '[]'::jsonb;
    for v_i in 1 .. coalesce(array_length(v_names, 1), 0) loop
      select btrim(a ->> 'value') into v_value
      from jsonb_array_elements(v_row -> 'attrs') as t(a)
      where lower(btrim(a ->> 'name')) = lower(btrim(v_names[v_i])) limit 1;
      -- the stored spelling of a value that differs only in case
      v_options := v_options || to_jsonb(coalesce(
        (select x from jsonb_array_elements_text(v_attrs -> (v_i - 1) -> 'values') as t(x) where lower(x) = lower(v_value) limit 1),
        v_value
      ));
    end loop;

    v_built := jsonb_build_object(
      'id', v_ev -> 'id',
      'options', v_options,
      'sku', v_sku,
      'barcode', nullif(btrim(coalesce(v_row ->> 'barcode', '')), ''),
      'unit', coalesce(nullif(btrim(coalesce(v_row ->> 'unit', '')), ''), v_ev ->> 'unit', 'cái'),
      'price', (v_row ->> 'price')::numeric,
      'track_stock', coalesce((v_row ->> 'track_stock')::boolean, (v_ev ->> 'track_stock')::boolean, true),
      'is_active', coalesce((v_row ->> 'is_active')::boolean, true),
      'image_url', v_ev -> 'image_url'
    );

    -- Units named in the file replace the ones with the same name; the others stay.
    if jsonb_typeof(v_row -> 'units') = 'array' then
      v_units := coalesce((
        select jsonb_agg(u) from jsonb_array_elements(coalesce(v_ev -> 'units', '[]'::jsonb)) as t(u)
        where not exists (
          select 1 from jsonb_array_elements(v_row -> 'units') as f(x)
          where lower(btrim(x ->> 'name')) = lower(u ->> 'name')
        )
      ), '[]'::jsonb);
      for v_unit in select * from jsonb_array_elements(v_row -> 'units') loop
        select u into v_old_unit from jsonb_array_elements(coalesce(v_ev -> 'units', '[]'::jsonb)) as t(u)
        where lower(u ->> 'name') = lower(btrim(v_unit ->> 'name')) limit 1;
        v_units := v_units || jsonb_build_object(
          'id', v_old_unit -> 'id',
          'name', btrim(v_unit ->> 'name'),
          'factor', (v_unit ->> 'factor')::numeric,
          'barcode', nullif(btrim(coalesce(v_unit ->> 'barcode', '')), ''),
          'price', nullif(btrim(coalesce(v_unit ->> 'price', '')), '')::numeric,
          'for_sale', coalesce((v_unit ->> 'for_sale')::boolean, true),
          'for_purchase', coalesce((v_unit ->> 'for_purchase')::boolean, false),
          'is_active', coalesce((v_unit ->> 'is_active')::boolean, true)
        );
      end loop;
      v_built := v_built || jsonb_build_object('units', v_units);
    end if;

    v_variants := v_variants || v_built;
    if v_ev is null then
      v_created := v_created + 1;
      v_acts := jsonb_set(v_acts, array[v_row ->> 'row'], '"create"');
    else
      v_updated := v_updated + 1;
      v_acts := jsonb_set(v_acts, array[v_row ->> 'row'], '"update"');
    end if;
  end loop;

  -- ------------------------------------------------------------------- the group
  select r ->> 'description' into v_desc
  from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'description', '')), '') is not null limit 1;

  select r -> 'images' into v_images
  from jsonb_array_elements(p_rows) as t(r)
  where jsonb_typeof(r -> 'images') = 'array' and jsonb_array_length(r -> 'images') > 0 limit 1;
  if v_images is not null then
    -- keep the storage path of a picture the group already has
    select jsonb_agg(jsonb_build_object(
      'url', btrim(x),
      'storage_path', (select i ->> 'storage_path' from jsonb_array_elements(coalesce(v_g -> 'images', '[]'::jsonb)) as e(i) where i ->> 'url' = btrim(x) limit 1)
    ) order by ord) into v_images
    from jsonb_array_elements_text(v_images) with ordinality as t(x, ord)
    where btrim(x) <> '';
  end if;

  select * into v_category from public.import_resolve_category(
    (select r ->> 'category' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'category', '')), '') is not null limit 1)
  );
  select * into v_brand from public.import_resolve_brand(
    (select r ->> 'brand' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'brand', '')), '') is not null limit 1)
  );
  v_cat_id := coalesce(v_category.o_id, (v_g ->> 'category_id')::uuid);
  v_brand_id := coalesce(v_brand.o_id, (v_g ->> 'brand_id')::uuid);

  v_payload := jsonb_build_object(
    'id', v_gid,
    'name', coalesce(v_g ->> 'name', v_name),
    'description', coalesce(v_desc, v_g ->> 'description'),
    'image_url', v_g ->> 'image_url',
    'is_active', coalesce((v_g ->> 'is_active')::boolean, true),
    'category_id', v_cat_id,
    'brand_id', v_brand_id,
    'attributes', v_attrs,
    'variants', v_variants
  );
  if v_images is not null then
    v_payload := v_payload || jsonb_build_object('images', v_images);
  end if;

  perform public.save_product_group(v_payload);

  return jsonb_build_object(
    'errors', v_errs,
    'actions', v_acts,
    'created_group', v_gid is null,
    'created_variants', v_created,
    'updated_variants', v_updated,
    'new_category', case when v_category.o_created then (select r ->> 'category' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'category', '')), '') is not null limit 1) end,
    'new_brand', case when v_brand.o_created then (select r ->> 'brand' from jsonb_array_elements(p_rows) as t(r) where nullif(btrim(coalesce(r ->> 'brand', '')), '') is not null limit 1) end
  );
end;
$$;


ALTER FUNCTION "public"."import_one_group"("p_rows" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_pets"("p_rows" "jsonb", "p_dry_run" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."import_pets"("p_rows" "jsonb", "p_dry_run" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_pets_row"("p_row" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."import_pets_row"("p_row" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_pets_run"("p_rows" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."import_pets_run"("p_rows" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_products"("p_rows" "jsonb", "p_dry_run" boolean DEFAULT true, "p_file_name" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_result jsonb;
begin
  if not (public.can_products('IMPORT') or (public.can_products('CREATE') and public.can_products('UPDATE'))) then
    raise exception 'not allowed to import products' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'rows must be a list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 500 then
    raise exception 'at most 500 rows per call' using errcode = '22023', hint = 'too_many_rows';
  end if;

  if p_dry_run then
    begin
      v_result := public.import_products_run(p_rows);
      raise exception 'dry run' using errcode = 'P0099';
    exception when sqlstate 'P0099' then
      return v_result;
    end;
  end if;

  v_result := public.import_products_run(p_rows);
  if not (v_result ->> 'ok')::boolean then
    raise exception 'the file has errors' using errcode = '22023', hint = 'import_invalid';
  end if;
  insert into public.product_imports (file_name, row_count, created_count, updated_count, created_by)
  values (
    nullif(btrim(p_file_name), ''),
    jsonb_array_length(p_rows),
    (v_result ->> 'created_variants')::int,
    (v_result ->> 'updated_variants')::int,
    (select auth.uid())
  );
  return v_result;
end;
$$;


ALTER FUNCTION "public"."import_products"("p_rows" "jsonb", "p_dry_run" boolean, "p_file_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_products_run"("p_rows" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_keys    text[] := '{}';
  v_key     text;
  v_row     jsonb;
  v_group   jsonb;
  v_one     jsonb;
  v_notes   jsonb := '{}'::jsonb;
  v_actions jsonb := '{}'::jsonb;
  v_n       text;
  v_item    record;
  v_msg     text;
  v_hint    text;
  v_detail  text;
  v_c_groups int := 0;
  v_u_groups int := 0;
  v_c_vars   int := 0;
  v_u_vars   int := 0;
  v_cats     jsonb := '[]'::jsonb;
  v_brands   jsonb := '[]'::jsonb;
  v_out     jsonb := '[]'::jsonb;
  v_ok      boolean;
begin
  -- first-appearance order of the groups
  for v_row in select * from jsonb_array_elements(p_rows) loop
    v_n := v_row ->> 'row';
    v_key := lower(btrim(coalesce(v_row ->> 'group', '')));
    if v_key = '' then
      v_notes := public.import_add_error(v_notes, v_n, 'Thiếu tên nhóm');
    elsif not (v_key = any (v_keys)) then
      v_keys := v_keys || v_key;
    end if;
  end loop;

  foreach v_key in array v_keys loop
    select jsonb_agg(r order by ord) into v_group
    from jsonb_array_elements(p_rows) with ordinality as t(r, ord)
    where lower(btrim(coalesce(r ->> 'group', ''))) = v_key;

    begin
      v_one := public.import_one_group(v_group);
      for v_item in select key, value from jsonb_each(v_one -> 'errors') loop
        for v_n in select jsonb_array_elements_text(v_item.value) loop
          v_notes := public.import_add_error(v_notes, v_item.key, v_n);
        end loop;
      end loop;
      if v_one -> 'errors' = '{}'::jsonb then
        v_actions := v_actions || (v_one -> 'actions');
        if (v_one ->> 'created_group')::boolean then v_c_groups := v_c_groups + 1; else v_u_groups := v_u_groups + 1; end if;
        v_c_vars := v_c_vars + (v_one ->> 'created_variants')::int;
        v_u_vars := v_u_vars + (v_one ->> 'updated_variants')::int;
        if v_one ->> 'new_category' is not null then v_cats := v_cats || to_jsonb(v_one ->> 'new_category'); end if;
        if v_one ->> 'new_brand' is not null then v_brands := v_brands || to_jsonb(v_one ->> 'new_brand'); end if;
      end if;
    exception when others then
      if sqlstate = '42501' then raise; end if;
      get stacked diagnostics v_msg = message_text, v_hint = pg_exception_hint, v_detail = pg_exception_detail;
      for v_n in select r ->> 'row' from jsonb_array_elements(v_group) as t(r) loop
        v_notes := public.import_add_error(v_notes, v_n, public.import_error_text(v_hint, v_msg, v_detail));
      end loop;
    end;
  end loop;

  v_ok := v_notes = '{}'::jsonb;
  select coalesce(jsonb_agg(jsonb_build_object(
    'row', r ->> 'row',
    'action', case when v_notes ? (r ->> 'row') then 'skip' else coalesce(v_actions ->> (r ->> 'row'), 'skip') end,
    'errors', coalesce(v_notes -> (r ->> 'row'), '[]'::jsonb)
  ) order by ord), '[]'::jsonb) into v_out
  from jsonb_array_elements(p_rows) with ordinality as t(r, ord);

  return jsonb_build_object(
    'ok', v_ok,
    'created_groups', v_c_groups,
    'updated_groups', v_u_groups,
    'created_variants', v_c_vars,
    'updated_variants', v_u_vars,
    'new_categories', v_cats,
    'new_brands', v_brands,
    'rows', v_out
  );
end;
$$;


ALTER FUNCTION "public"."import_products_run"("p_rows" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_resolve_brand"("p_name" "text", OUT "o_id" "uuid", OUT "o_created" boolean) RETURNS "record"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_name text := btrim(coalesce(p_name, ''));
begin
  o_created := false;
  if v_name = '' then
    return;
  end if;
  select id into o_id from public.product_brands
  where lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_name));
  if o_id is null then
    o_id := public.save_product_brand(jsonb_build_object('name', v_name));
    o_created := true;
  end if;
end;
$$;


ALTER FUNCTION "public"."import_resolve_brand"("p_name" "text", OUT "o_id" "uuid", OUT "o_created" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_resolve_category"("p_path" "text", OUT "o_id" "uuid", OUT "o_created" boolean) RETURNS "record"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_parts  text[];
  v_part   text;
  v_parent uuid;
  v_found  uuid;
begin
  o_created := false;
  select array_agg(btrim(x)) into v_parts
  from unnest(string_to_array(coalesce(p_path, ''), '>')) as x
  where btrim(x) <> '';
  if v_parts is null then
    return;
  end if;
  if array_length(v_parts, 1) > 2 then
    raise exception 'a category has two levels at most' using errcode = '22023', hint = 'category_depth';
  end if;
  foreach v_part in array v_parts loop
    v_found := null;
    select id into v_found from public.product_categories
    where parent_id is not distinct from v_parent
      and lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_part));
    if v_found is null then
      v_found := public.save_product_category(jsonb_build_object('name', v_part, 'parent_id', v_parent));
      o_created := true;
    end if;
    v_parent := v_found;
  end loop;
  o_id := v_parent;
end;
$$;


ALTER FUNCTION "public"."import_resolve_category"("p_path" "text", OUT "o_id" "uuid", OUT "o_created" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_suppliers"("p_rows" "jsonb", "p_dry_run" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_result jsonb;
begin
  if not (coalesce((select public.is_admin()), false) or coalesce((select public.has_permission('inventory', 'IMPORT')), false)) then
    raise exception 'not allowed to import suppliers' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) is distinct from 'array' then
    raise exception 'rows must be a list' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 500 then
    raise exception 'at most 500 rows per call' using errcode = '22023', hint = 'too_many_rows';
  end if;

  if p_dry_run then
    begin
      v_result := public.import_suppliers_run(p_rows);
      raise exception 'dry run' using errcode = 'P0099';
    exception when sqlstate 'P0099' then
      return v_result;
    end;
  end if;

  v_result := public.import_suppliers_run(p_rows);
  if not (v_result ->> 'ok')::boolean then
    raise exception 'the file has errors' using errcode = '22023', hint = 'import_invalid';
  end if;
  return v_result;
end;
$$;


ALTER FUNCTION "public"."import_suppliers"("p_rows" "jsonb", "p_dry_run" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_suppliers_row"("p_row" "jsonb") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_name    text := nullif(btrim(coalesce(p_row ->> 'name', '')), '');
  v_phone   text := nullif(btrim(coalesce(p_row ->> 'phone', '')), '');
  v_email   text := nullif(btrim(coalesce(p_row ->> 'email', '')), '');
  v_address text := nullif(btrim(coalesce(p_row ->> 'address', '')), '');
  v_tax     text := nullif(btrim(coalesce(p_row ->> 'tax_code', '')), '');
  v_note    text := nullif(btrim(coalesce(p_row ->> 'note', '')), '');
  v_active  boolean := case when p_row ->> 'is_active' is null then null else (p_row ->> 'is_active')::boolean end;
  v_ids     uuid[];
begin
  if v_name is null then
    raise exception 'Thiếu tên nhà cung cấp' using errcode = '22023';
  end if;

  if v_tax is not null then
    select array_agg(id order by created_at) into v_ids
    from public.suppliers where lower(btrim(tax_code)) = lower(v_tax);
  else
    select array_agg(id order by created_at) into v_ids
    from public.suppliers where lower(btrim(name)) = lower(v_name);
  end if;

  if coalesce(array_length(v_ids, 1), 0) > 1 then
    raise exception 'Có nhiều nhà cung cấp trùng, hãy kiểm tra lại mã số thuế hoặc tên' using errcode = '22023';
  end if;

  if v_ids is null then
    insert into public.suppliers (name, phone, email, address, tax_code, note, is_active)
    values (v_name, v_phone, v_email, v_address, v_tax, v_note, coalesce(v_active, true));
    return 'create';
  end if;

  update public.suppliers
  set name      = v_name,
      phone     = coalesce(v_phone, phone),
      email     = coalesce(v_email, email),
      address   = coalesce(v_address, address),
      tax_code  = coalesce(v_tax, tax_code),
      note      = coalesce(v_note, note),
      is_active = coalesce(v_active, is_active)
  where id = v_ids[1];
  return 'update';
end;
$$;


ALTER FUNCTION "public"."import_suppliers_row"("p_row" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."import_suppliers_run"("p_rows" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_item    record;
  v_action  text;
  v_out     jsonb := '[]'::jsonb;
  v_ok      boolean := true;
  v_created int := 0;
  v_updated int := 0;
  v_msg     text;
begin
  for v_item in select r, ord from jsonb_array_elements(p_rows) with ordinality as t(r, ord) order by ord loop
    begin
      v_action := public.import_suppliers_row(v_item.r);
      if v_action = 'create' then v_created := v_created + 1; else v_updated := v_updated + 1; end if;
      v_out := v_out || jsonb_build_array(jsonb_build_object('row', v_item.r ->> 'row', 'action', v_action, 'errors', '[]'::jsonb));
    exception when others then
      get stacked diagnostics v_msg = message_text;
      v_ok := false;
      v_out := v_out || jsonb_build_array(jsonb_build_object(
        'row', v_item.r ->> 'row',
        'action', 'skip',
        'errors', jsonb_build_array(case sqlstate when '22P02' then 'Có ô không đúng định dạng' else v_msg end)
      ));
    end;
  end loop;

  return jsonb_build_object('ok', v_ok, 'created', v_created, 'updated', v_updated, 'rows', v_out);
end;
$$;


ALTER FUNCTION "public"."import_suppliers_run"("p_rows" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inpatient_kennels"("p_branch" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_today date := public.business_date();
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', k.id, 'code', k.code, 'type_name', t.name, 'purpose', t.purpose,
      'free', k.status = 'ready' and not exists (
        select 1 from public.boarding_stay_pets sp
        join public.boarding_stays s on s.id = sp.stay_id
        where sp.kennel_id = k.id and sp.status = 'active' and s.status in ('booked', 'checked_in')
          and sp.nights && daterange(v_today, v_today + 1)
      )
    ) order by t.purpose desc, k.sort_order, k.code)
    from public.kennels k
    join public.kennel_types t on t.id = k.kennel_type_id
    where k.branch_id = p_branch and k.is_active and t.is_active and t.purpose in ('medical', 'isolation')
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."inpatient_kennels"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inpatient_log_change"("p_order" "uuid", "p_visit" "uuid", "p_action" "text", "p_before" "jsonb", "p_after" "jsonb", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := (select auth.uid());
begin
  insert into public.inpatient_order_changes (order_id, visit_id, action, before, after, reason, changed_by, changed_by_name)
  values (
    p_order, p_visit, p_action, p_before, p_after, nullif(btrim(p_reason), ''),
    v_uid, case when v_uid is null then null else public.staff_display_name(v_uid) end
  );
end;
$$;


ALTER FUNCTION "public"."inpatient_log_change"("p_order" "uuid", "p_visit" "uuid", "p_action" "text", "p_before" "jsonb", "p_after" "jsonb", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inpatient_order_history"("p_order" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch uuid;
begin
  select branch_id into v_branch from public.inpatient_orders where id = p_order;
  if v_branch is null then
    raise exception 'order not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('VIEW', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'action', c.action, 'before', c.before, 'after', c.after, 'reason', c.reason,
      'changed_by_name', c.changed_by_name, 'changed_at', c.changed_at
    ) order by c.changed_at desc, c.id)
    from public.inpatient_order_changes c where c.order_id = p_order
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."inpatient_order_history"("p_order" "uuid") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inpatient_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "stay_pet_id" "uuid" NOT NULL,
    "stay_id" "uuid" NOT NULL,
    "visit_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "product_id" "uuid",
    "service_id" "uuid",
    "name" "text" NOT NULL,
    "dose" "text",
    "qty_per_dose" numeric(10,2) DEFAULT 1 NOT NULL,
    "times" "text"[] NOT NULL,
    "start_on" "date" NOT NULL,
    "end_on" "date" NOT NULL,
    "note" "text",
    "item_id" "uuid",
    "stopped_at" timestamp with time zone,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "inpatient_orders_check" CHECK ((("end_on" >= "start_on") AND ("end_on" <= ("start_on" + 30)))),
    CONSTRAINT "inpatient_orders_check1" CHECK (((("kind" = 'product'::"text") AND ("product_id" IS NOT NULL) AND ("service_id" IS NULL)) OR (("kind" = 'service'::"text") AND ("service_id" IS NOT NULL) AND ("product_id" IS NULL)) OR (("kind" = 'care'::"text") AND ("product_id" IS NULL) AND ("service_id" IS NULL)))),
    CONSTRAINT "inpatient_orders_kind_check" CHECK (("kind" = ANY (ARRAY['product'::"text", 'service'::"text", 'care'::"text"]))),
    CONSTRAINT "inpatient_orders_name_check" CHECK (("length"("btrim"("name")) > 0)),
    CONSTRAINT "inpatient_orders_qty_per_dose_check" CHECK (("qty_per_dose" > (0)::numeric)),
    CONSTRAINT "inpatient_orders_times_check" CHECK ((("cardinality"("times") >= 1) AND ("cardinality"("times") <= 8)))
);


ALTER TABLE "public"."inpatient_orders" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inpatient_order_snapshot"("p_order" "public"."inpatient_orders") RETURNS "jsonb"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'dose', p_order.dose, 'qty_per_dose', p_order.qty_per_dose, 'times', to_jsonb(p_order.times),
    'start_on', p_order.start_on, 'end_on', p_order.end_on, 'note', p_order.note
  );
$$;


ALTER FUNCTION "public"."inpatient_order_snapshot"("p_order" "public"."inpatient_orders") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inpatient_signed_lock"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_visit uuid;
begin
  if tg_table_name = 'inpatient_orders' then
    v_visit := coalesce(new.visit_id, old.visit_id);
  else
    select o.visit_id into v_visit from public.inpatient_orders o where o.id = coalesce(new.order_id, old.order_id);
  end if;
  if v_visit is not null and exists (select 1 from public.medical_visits where id = v_visit and signed_at is not null) then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."inpatient_signed_lock"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inpatient_ward"("p_branch" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_date date := coalesce(p_date, public.business_date());
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return jsonb_build_object('date', v_date, 'rows', coalesce((
    select jsonb_agg(jsonb_build_object(
      'stay_id', s.id,
      'stay_code', s.code,
      'stay_pet_id', sp.id,
      'visit_id', v.id,
      'visit_code', v.code,
      'pet_id', sp.pet_id,
      'pet_name', sp.pet_name,
      'pet_photo_url', pt.photo_url,
      'customer_name', s.customer_name,
      'customer_phone', s.customer_phone,
      'kennel_code', k.code,
      'purpose', t.purpose,
      'since', s.checked_in_at,
      'planned_out_at', s.planned_out_at,
      'overdue', s.planned_out_at < now(),
      'allergies', nullif(btrim(pt.allergies), ''),
      'orders', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', o.id, 'kind', o.kind, 'product_id', o.product_id, 'service_id', o.service_id, 'name', o.name, 'dose', o.dose, 'qty_per_dose', o.qty_per_dose,
          'times', o.times, 'start_on', o.start_on, 'end_on', o.end_on, 'note', o.note,
          'stopped', o.stopped_at is not null,
          'edited', (select count(*) from public.inpatient_order_changes c where c.order_id = o.id and c.action = 'update'),
          'missed', (
            select count(*) from public.inpatient_doses d
            where d.order_id = o.id and public.medical_local_date(d.due_at) = v_date and d.due_at < now()
              and d.given_at is null and d.skipped_reason is null
          )
        ) order by o.created_at)
        from public.inpatient_orders o where o.stay_pet_id = sp.id and o.stopped_at is null
      ), '[]'::jsonb),
      'doses', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', d.id, 'order_id', d.order_id, 'due_at', d.due_at, 'given_at', d.given_at,
          'given_by_name', d.given_by_name, 'skipped_reason', d.skipped_reason, 'qty', d.qty
        ) order by d.due_at)
        from public.inpatient_doses d
        join public.inpatient_orders o on o.id = d.order_id
        where o.stay_pet_id = sp.id and public.medical_local_date(d.due_at) = v_date
      ), '[]'::jsonb),
      'last_vitals', (
        select jsonb_build_object('content', l.content, 'logged_at', l.logged_at)
        from public.boarding_care_logs l
        where l.stay_pet_id = sp.id and l.kind = 'vitals'
        order by l.logged_at desc limit 1
      )
    ) order by k.code)
    from public.boarding_stays s
    join public.boarding_stay_pets sp on sp.stay_id = s.id and sp.status = 'active'
    join public.kennels k on k.id = sp.kennel_id
    join public.kennel_types t on t.id = k.kennel_type_id
    join public.medical_visits v on v.id = s.visit_id
    join public.pets pt on pt.id = sp.pet_id
    where s.branch_id = p_branch and s.kind = 'inpatient' and s.status = 'checked_in'
  ), '[]'::jsonb));
end;
$$;


ALTER FUNCTION "public"."inpatient_ward"("p_branch" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invoice_cancel_restock"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_row record;
begin
  if exists (select 1 from public.sales_returns where invoice_id = new.id) then
    raise exception 'invoice % has returns', new.code using errcode = 'P0001', hint = 'has_returns';
  end if;

  for v_row in
    select lot_id, invoice_line_id, -sum(qty) as qty
    from public.stock_movements
    where invoice_id = new.id
    group by lot_id, invoice_line_id
    having sum(qty) < 0
  loop
    perform public.move_stock(
      v_row.lot_id, v_row.qty, 'sale_cancel', p_invoice => new.id, p_invoice_line => v_row.invoice_line_id
    );
  end loop;
  return null;
end;
$$;


ALTER FUNCTION "public"."invoice_cancel_restock"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invoice_line_take_stock"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch uuid;
  v_cost   numeric;
begin
  select branch_id into v_branch from public.invoices where id = new.invoice_id;
  v_cost := public.take_stock_lot_first(v_branch, new.product_id, new.base_qty, new.lot_id, new.invoice_id, new.id);
  if v_cost is not null then
    update public.invoice_lines set cost_amount = v_cost where id = new.id;
  end if;
  return null;
end;
$$;


ALTER FUNCTION "public"."invoice_line_take_stock"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select auth.jwt() ->> 'user_role') in ('admin', 'superAdmin'), false);
$$;


ALTER FUNCTION "public"."is_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_display_name_available"("p_display_name" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select not exists (
    select 1 from public.users where lower(display_name) = lower(p_display_name)
  );
$$;


ALTER FUNCTION "public"."is_display_name_available"("p_display_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_staff"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce(
    (select auth.jwt() ->> 'user_role') in ('admin', 'superAdmin', 'cashier')
      or jsonb_array_length(coalesce((select auth.jwt() -> 'branch_ids'), '[]'::jsonb)) > 0,
    false
  );
$$;


ALTER FUNCTION "public"."is_staff"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_super_admin"() RETURNS boolean
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select coalesce((select auth.jwt() ->> 'user_role') = 'superAdmin', false);
$$;


ALTER FUNCTION "public"."is_super_admin"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."issue_shop_order_invoice"("p_order" "uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o         public.shop_orders;
  v_id      uuid;
  v_cust    public.customers;
begin
  select * into o from public.shop_orders where id = p_order;
  select * into v_cust from public.customers where id = o.customer_id;

  insert into public.invoices (
    code, branch_id, shift_id, channel, status, customer_id, customer_name, customer_phone, cashier_name,
    subtotal, discount_amount, total, note, created_by
  ) values (
    public.next_doc_code(o.branch_id, 'HD'), o.branch_id, null, 'online', 'unpaid', o.customer_id,
    v_cust.full_name, coalesce(nullif(o.receiver_phone, ''), v_cust.phone),
    public.staff_display_name((select auth.uid())),
    o.subtotal, 0, o.subtotal, o.code, (select auth.uid())
  )
  returning id into v_id;

  insert into public.invoice_lines (
    invoice_id, line_no, item_type, product_id, name, unit, qty, unit_price, amount, unit_id, unit_factor
  )
  select v_id, l.line_no, 'product', l.product_id, l.name, l.unit, l.qty, l.unit_price, l.amount, l.unit_id, l.unit_factor
  from public.shop_order_lines l where l.order_id = o.id order by l.line_no;

  update public.shop_orders set invoice_id = v_id where id = o.id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."issue_shop_order_invoice"("p_order" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kennel_extra_pet_price"("p_type" "uuid", "p_branch" "uuid") RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce(p.extra_pet_night_price, p.night_price)
  from public.kennel_type_prices p
  where p.kennel_type_id = p_type and (p.branch_id = p_branch or p.branch_id is null)
  order by (p.branch_id is null)
  limit 1;
$$;


ALTER FUNCTION "public"."kennel_extra_pet_price"("p_type" "uuid", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."kennel_night_price"("p_type" "uuid", "p_branch" "uuid") RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select p.night_price
  from public.kennel_type_prices p
  where p.kennel_type_id = p_type and (p.branch_id = p_branch or p.branch_id is null)
  order by (p.branch_id is null)
  limit 1;
$$;


ALTER FUNCTION "public"."kennel_night_price"("p_type" "uuid", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."link_customer_account"("p_customer" "uuid", "p_user" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_owner uuid;
begin
  if not public.can_link_accounts() then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  select user_id into v_owner from public.customers where id = p_customer for update;
  if not found then
    raise exception 'customer not found' using errcode = 'P0002', hint = 'customer_not_found';
  end if;
  if v_owner is not null then
    raise exception 'customer already has an account' using errcode = '22023', hint = 'customer_has_account';
  end if;
  if not exists (select 1 from public.users where id = p_user) then
    raise exception 'account not found' using errcode = 'P0002', hint = 'account_not_found';
  end if;
  if exists (select 1 from public.customers where user_id = p_user) then
    raise exception 'account already has a customer record' using errcode = '22023', hint = 'account_has_customer';
  end if;
  update public.customers set user_id = p_user, updated_at = now() where id = p_customer;
end;
$$;


ALTER FUNCTION "public"."link_customer_account"("p_customer" "uuid", "p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_appointments"("p_branch" "uuid", "p_from" "date" DEFAULT NULL::"date", "p_to" "date" DEFAULT NULL::"date", "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_digits text := regexp_replace(coalesce(p_search, ''), '\D', '', 'g');
  v_from   timestamptz := case when p_from is null then null else (p_from::timestamp at time zone c_tz) end;
  v_to     timestamptz := case when p_to is null then null else ((p_to + 1)::timestamp at time zone c_tz) end;
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select a.*
    from public.appointments a
    where a.branch_id = p_branch
      and (v_from is null or a.start_at >= v_from)
      and (v_to is null or a.start_at < v_to)
      and (nullif(p_status, '') is null or a.status = p_status)
      and (
        v_term = ''
        or lower(a.code) like v_like
        or lower(public.immutable_unaccent(a.customer_name)) like v_like
        or (length(v_digits) >= 3 and regexp_replace(a.customer_phone, '\D', '', 'g') like v_digits || '%')
        or exists (
          select 1 from public.appointment_items i
          join public.pets pt on pt.id = i.pet_id
          where i.appointment_id = a.id and lower(public.immutable_unaccent(pt.name)) like v_like
        )
      )
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'code', a.code,
        'source', a.source,
        'status', a.status,
        'start_at', a.start_at,
        'end_at', a.end_at,
        'customer_id', a.customer_id,
        'customer_name', a.customer_name,
        'customer_phone', a.customer_phone,
        'note', a.note,
        'checked_in_at', a.checked_in_at,
        'items', (
          select coalesce(jsonb_agg(jsonb_build_object(
            'id', i.id,
            'name', i.name,
            'item_type', i.item_type,
            'service_id', i.service_id,
            'combo_id', i.combo_id,
            'status', i.status,
            'pet_id', i.pet_id,
            'pet_name', pt.name,
            'pet_photo_url', pt.photo_url,
            'staff_id', i.staff_id,
            'staff_name', case when i.staff_id is null then null else public.staff_display_name(i.staff_id) end,
            'resource_id', i.resource_id,
            'resource_name', rs.name,
            'start_at', i.start_at,
            'end_at', i.end_at,
            'est_price', i.est_price,
            'weight_kg', i.weight_kg,
            'unit_price', i.unit_price,
            'billed', i.invoice_line_id is not null
          ) order by i.line_no), '[]'::jsonb)
          from public.appointment_items i
          left join public.pets pt on pt.id = i.pet_id
          left join public.spa_resources rs on rs.id = i.resource_id
          where i.appointment_id = a.id
        )
      ) order by a.start_at desc, a.code desc)
      from (select * from f order by start_at desc, code desc limit v_size offset v_offset) a
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$$;


ALTER FUNCTION "public"."list_appointments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_boarding_stays"("p_branch" "uuid", "p_from" "date" DEFAULT NULL::"date", "p_to" "date" DEFAULT NULL::"date", "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."list_boarding_stays"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_branch_staff"("p_branch" "uuid") RETURNS TABLE("user_id" "uuid", "name" "text", "role" "text", "does_services" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return query
    select sb.user_id, public.staff_display_name(sb.user_id), sb.role, sb.does_services
    from public.staff_branches sb
    where sb.branch_id = p_branch
    order by 2;
end;
$$;


ALTER FUNCTION "public"."list_branch_staff"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_diagnosis_terms"("p_search" "text" DEFAULT NULL::"text", "p_species" "uuid" DEFAULT NULL::"uuid", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_active_only" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.is_staff() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select d.*
    from public.diagnosis_terms d
    where (not p_active_only or d.is_active)
      and (p_species is null or cardinality(d.species_ids) = 0 or p_species = any (d.species_ids))
      and (v_term = '' or lower(public.immutable_unaccent(d.name)) like v_like)
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id,
        'name', d.name,
        'species_ids', to_jsonb(d.species_ids),
        'species_names', coalesce((
          select jsonb_agg(s.name order by s.name) from public.species s where s.id = any (d.species_ids)
        ), '[]'::jsonb),
        'is_contagious', d.is_contagious,
        'is_active', d.is_active,
        'sort_order', d.sort_order
      ) order by d.sort_order, lower(d.name), d.id)
      from (select * from f order by sort_order, lower(name), id limit v_size offset v_offset) d
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."list_diagnosis_terms"("p_search" "text", "p_species" "uuid", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_kennel_types"("p_branch" "uuid", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_active_only" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select k.*
    from public.kennel_types k
    where (not p_active_only or k.is_active)
      and (v_term = '' or lower(public.immutable_unaccent(k.name)) like v_like)
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', k.id,
        'name', k.name,
        'description', k.description,
        'photo_url', k.photo_url,
        'species_ids', to_jsonb(k.species_ids),
        'species_names', coalesce((
          select jsonb_agg(s.name order by s.name) from public.species s where s.id = any (k.species_ids)
        ), '[]'::jsonb),
        'max_weight_kg', k.max_weight_kg,
        'max_pets', k.max_pets,
        'purpose', k.purpose,
        'is_active', k.is_active,
        'is_public', k.is_public,
        'sort_order', k.sort_order,
        'night_price', public.kennel_night_price(k.id, p_branch),
        'extra_pet_night_price', public.kennel_extra_pet_price(k.id, p_branch),
        'has_branch_price', exists (
          select 1 from public.kennel_type_prices p where p.kennel_type_id = k.id and p.branch_id = p_branch
        ),
        'shared_night_price', (
          select p.night_price from public.kennel_type_prices p where p.kennel_type_id = k.id and p.branch_id is null
        ),
        'shared_extra_pet_night_price', (
          select p.extra_pet_night_price from public.kennel_type_prices p where p.kennel_type_id = k.id and p.branch_id is null
        ),
        'branch_prices', coalesce((
          select jsonb_agg(jsonb_build_object(
            'branch_id', p.branch_id,
            'branch_name', b.name,
            'night_price', p.night_price,
            'extra_pet_night_price', p.extra_pet_night_price
          ) order by b.name)
          from public.kennel_type_prices p join public.branches b on b.id = p.branch_id
          where p.kennel_type_id = k.id
        ), '[]'::jsonb),
        'kennel_count', (
          select count(*) from public.kennels n where n.kennel_type_id = k.id and n.branch_id = p_branch
        )
      ) order by k.sort_order, lower(k.name), k.id)
      from (select * from f order by sort_order, lower(name), id limit v_size offset v_offset) k
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."list_kennel_types"("p_branch" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_kennels"("p_branch" "uuid", "p_search" "text" DEFAULT NULL::"text", "p_type" "uuid" DEFAULT NULL::"uuid", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_boarding('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select n.*, t.name as type_name, t.sort_order as type_sort
    from public.kennels n
    join public.kennel_types t on t.id = n.kennel_type_id
    where n.branch_id = p_branch
      and (p_type is null or n.kennel_type_id = p_type)
      and (
        v_term = ''
        or lower(public.immutable_unaccent(n.code)) like v_like
        or lower(public.immutable_unaccent(coalesce(n.name, ''))) like v_like
        or lower(public.immutable_unaccent(t.name)) like v_like
      )
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', k.id,
        'branch_id', k.branch_id,
        'kennel_type_id', k.kennel_type_id,
        'kennel_type_name', k.type_name,
        'code', k.code,
        'name', k.name,
        'status', k.status,
        'is_active', k.is_active,
        'sort_order', k.sort_order
      ) order by k.type_sort, lower(k.type_name), k.sort_order, lower(k.code), k.id)
      from (
        select * from f order by type_sort, lower(type_name), sort_order, lower(code), id
        limit v_size offset v_offset
      ) k
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."list_kennels"("p_branch" "uuid", "p_search" "text", "p_type" "uuid", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_medical_attachments"("p_visit" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', a.id, 'visit_id', a.visit_id, 'kind', a.kind, 'title', a.title, 'file_path', a.file_path,
      'mime_type', a.mime_type, 'size_bytes', a.size_bytes, 'created_by_name', a.created_by_name,
      'created_at', a.created_at
    ) order by a.created_at, a.id)
    from public.medical_attachments a where a.visit_id = p_visit
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."list_medical_attachments"("p_visit" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_medical_visits"("p_branch" "uuid", "p_from" "date" DEFAULT NULL::"date", "p_to" "date" DEFAULT NULL::"date", "p_status" "text" DEFAULT NULL::"text", "p_vet" "uuid" DEFAULT NULL::"uuid", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_digits text := regexp_replace(coalesce(p_search, ''), '\D', '', 'g');
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select v.*
    from public.medical_visits v
    where v.branch_id = p_branch
      and (nullif(p_status, '') is null or v.status = p_status)
      and (p_vet is null or v.vet_id = p_vet)
      and (
        v_term = ''
        or lower(v.code) like v_like
        or lower(public.immutable_unaccent(v.customer_name)) like v_like
        or lower(public.immutable_unaccent(v.pet_name)) like v_like
        or (length(v_digits) >= 3 and regexp_replace(v.customer_phone, '\D', '', 'g') like v_digits || '%')
        or exists (
          select 1 from public.medical_diagnoses d
          where d.visit_id = v.id and lower(public.immutable_unaccent(d.name)) like v_like
        )
      )
  ), g as (
    select * from f
    where (p_from is null or public.medical_local_date(coalesce(f.checked_in_at, f.scheduled_at, f.created_at)) >= p_from)
      and (p_to is null or public.medical_local_date(coalesce(f.checked_in_at, f.scheduled_at, f.created_at)) <= p_to)
  )
  select
    (select count(*) from g),
    coalesce((
      select jsonb_agg(
        public.medical_visit_json(s) || jsonb_build_object(
          'day', public.medical_local_date(coalesce(s.checked_in_at, s.scheduled_at, s.created_at)))
        order by coalesce(s.checked_in_at, s.scheduled_at, s.created_at) desc, s.id)
      from (select * from g order by coalesce(checked_in_at, scheduled_at, created_at) desc, id limit v_size offset v_offset) s
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."list_medical_visits"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_vet" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_product_brands"("p_search" "text" DEFAULT NULL::"text", "p_include_inactive" boolean DEFAULT false, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term
  ), matched as (
    select b.* from public.product_brands b, params
    where (p_include_inactive or b.is_active)
      and (params.term is null or lower(public.immutable_unaccent(b.name)) like '%' || params.term || '%')
  ), page as (
    select * from matched order by lower(name), id limit greatest(p_limit, 1) offset greatest(p_offset, 0)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', page.id,
        'name', page.name,
        'slug', page.slug,
        'image_url', page.image_url,
        'is_active', page.is_active,
        'product_count', (select count(*) from public.product_groups g where g.brand_id = page.id)
      ) order by lower(page.name), page.id)
      from page
    ), '[]'::jsonb)
  );
$$;


ALTER FUNCTION "public"."list_product_brands"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_product_categories"("p_search" "text" DEFAULT NULL::"text", "p_include_inactive" boolean DEFAULT false, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_roots_only" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term
  ), matched as (
    select c.*, par.name as parent_name,
           coalesce(par.sort_order, c.sort_order) as root_sort,
           lower(coalesce(par.name, c.name)) as root_name
    from public.product_categories c
    left join public.product_categories par on par.id = c.parent_id, params
    where (p_include_inactive or c.is_active)
      and (not p_roots_only or c.parent_id is null)
      and (params.term is null or lower(public.immutable_unaccent(c.name)) like '%' || params.term || '%')
  ), page as (
    select * from matched
    order by root_sort, root_name, (parent_id is not null), sort_order, lower(name), id
    limit greatest(p_limit, 1) offset greatest(p_offset, 0)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', page.id,
        'parent_id', page.parent_id,
        'parent_name', page.parent_name,
        'name', page.name,
        'slug', page.slug,
        'image_url', page.image_url,
        'sort_order', page.sort_order,
        'is_active', page.is_active,
        'product_count', (
          select count(*) from public.product_groups g
          where g.category_id = page.id
             or g.category_id in (select id from public.product_categories where parent_id = page.id)
        ),
        'child_count', (select count(*) from public.product_categories where parent_id = page.id)
      ) order by page.root_sort, page.root_name, (page.parent_id is not null), page.sort_order, lower(page.name), page.id)
      from page
    ), '[]'::jsonb)
  );
$$;


ALTER FUNCTION "public"."list_product_categories"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer, "p_roots_only" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_product_groups"("p_search" "text" DEFAULT NULL::"text", "p_include_archived" boolean DEFAULT false, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_category" "uuid" DEFAULT NULL::"uuid", "p_brand" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term,
           nullif(btrim(coalesce(p_search, '')), '') as code
  ), matched as (
    select g.id, g.name
    from public.product_groups g, params
    where (p_include_archived or g.is_active)
      and (p_brand is null or g.brand_id = p_brand)
      and (
        p_category is null
        or g.category_id = p_category
        or g.category_id in (select id from public.product_categories where parent_id = p_category)
      )
      and (
        params.term is null
        or lower(public.immutable_unaccent(g.name)) like '%' || params.term || '%'
        or exists (
          select 1 from public.products p
          where p.group_id = g.id
            and (p.sku ilike '%' || params.code || '%' or p.barcode ilike '%' || params.code || '%')
        )
      )
  ), page as (
    select * from matched order by lower(name) limit greatest(p_limit, 1) offset greatest(p_offset, 0)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(public.product_group_json(page.id, p_include_archived) order by lower(page.name))
      from page
    ), '[]'::jsonb)
  );
$$;


ALTER FUNCTION "public"."list_product_groups"("p_search" "text", "p_include_archived" boolean, "p_limit" integer, "p_offset" integer, "p_category" "uuid", "p_brand" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shop_orders"("p_branch" "uuid" DEFAULT NULL::"uuid", "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch uuid := coalesce(p_branch, (select online_branch_id from public.shop_settings where id));
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_off    int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_rows   jsonb;
  v_total  bigint;
  v_counts jsonb;
begin
  if not public.can_shop_orders('VIEW', v_branch) then
    raise exception 'not allowed to see online orders' using errcode = '42501';
  end if;

  with hits as (
    select o.* from public.shop_orders o
    where o.branch_id = v_branch
      and (v_term = '' or lower(public.immutable_unaccent(
             o.code || ' ' || o.receiver_name || ' ' || o.receiver_phone || ' ' || coalesce(o.tracking_code, '')))
           like '%' || v_term || '%')
  ), shown as (
    select h.* from hits h
    where p_status is null or h.status = p_status or (p_status = 'closed' and h.status in ('cancelled', 'returned'))
  )
  select
    (select coalesce(jsonb_object_agg(c.status, c.n), '{}'::jsonb)
       from (select status, count(*) as n from hits group by status) c),
    (select count(*) from shown),
    (select coalesce(jsonb_agg(r order by r.placed_at desc, r.id), '[]'::jsonb)
       from (
         select sh.id, sh.code, sh.placed_at, sh.receiver_name, sh.receiver_phone, sh.delivery_method, sh.status,
                sh.total, sh.tracking_code, sh.shipping_fee is not null as fee_confirmed,
                (select count(*) from public.shop_order_lines l where l.order_id = sh.id) as line_count
         from shown sh
         order by sh.placed_at desc, sh.id
         limit v_size offset v_off
       ) r)
  into v_counts, v_total, v_rows;

  return jsonb_build_object('rows', v_rows, 'total_count', v_total, 'counts', v_counts);
end;
$$;


ALTER FUNCTION "public"."list_shop_orders"("p_branch" "uuid", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_vaccine_types"("p_search" "text" DEFAULT NULL::"text", "p_kind" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_branch" "uuid" DEFAULT NULL::"uuid", "p_species" "uuid" DEFAULT NULL::"uuid", "p_active_only" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.is_staff() then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select v.*
    from public.vaccine_types v
    where (not p_active_only or v.is_active)
      and (p_kind is null or v.kind = p_kind)
      and (p_species is null or cardinality(v.species_ids) = 0 or p_species = any (v.species_ids))
      and (v_term = '' or lower(public.immutable_unaccent(v.name)) like v_like)
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', v.id,
        'name', v.name,
        'kind', v.kind,
        'species_ids', to_jsonb(v.species_ids),
        'species_names', coalesce((
          select jsonb_agg(s.name order by s.name) from public.species s where s.id = any (v.species_ids)
        ), '[]'::jsonb),
        'product_id', v.product_id,
        'product_name', pr.name,
        'product_unit', pr.unit,
        'stock_qty', case when v.product_id is null or p_branch is null or not coalesce(pr.track_stock, false) then null
          else (
            select coalesce(sum(l.qty_on_hand), 0)
            from public.stock_lots l
            where l.product_id = v.product_id and l.branch_id = p_branch and l.qty_on_hand > 0
              and (l.expiry_date is null or l.expiry_date >= public.business_date())
          ) end,
        'series_doses', v.series_doses,
        'series_interval_days', v.series_interval_days,
        'booster_interval_days', v.booster_interval_days,
        'min_age_weeks', v.min_age_weeks,
        'is_active', v.is_active,
        'sort_order', v.sort_order
      ) order by v.sort_order, lower(v.name), v.id)
      from (select * from f order by sort_order, lower(name), id limit v_size offset v_offset) v
      left join public.products pr on pr.id = v.product_id
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."list_vaccine_types"("p_search" "text", "p_kind" "text", "p_page" integer, "p_page_size" integer, "p_branch" "uuid", "p_species" "uuid", "p_active_only" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_boarding_no_show"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."mark_boarding_no_show"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_medical_no_show"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_visit public.medical_visits;
begin
  select * into v_visit from public.medical_visits where id = p_id for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('DELETE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status <> 'scheduled' then
    raise exception 'only a booked visit can be a no-show' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if public.medical_local_date(v_visit.scheduled_at) >= public.business_date() then
    raise exception 'the booked day has not passed' using errcode = 'P0001', hint = 'not_due';
  end if;
  update public.medical_visits set status = 'no_show' where id = p_id;
end;
$$;


ALTER FUNCTION "public"."mark_medical_no_show"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_no_show"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."mark_no_show"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_pet_deceased"("p_pet" "uuid", "p" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."mark_pet_deceased"("p_pet" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."mark_reminded"("p_vaccination" "uuid", "p_note" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_medical('CREATE') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.vaccinations set
    reminded_at = now(),
    reminded_by = (select auth.uid()),
    remind_note = nullif(btrim(p_note), '')
  where id = p_vaccination and voided_at is null;
  if not found then
    raise exception 'shot not found' using errcode = 'P0002', hint = 'not_found';
  end if;
end;
$$;


ALTER FUNCTION "public"."mark_reminded"("p_vaccination" "uuid", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_addenda_frozen"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  raise exception 'an addendum cannot be changed' using errcode = 'P0001', hint = 'signed';
end;
$$;


ALTER FUNCTION "public"."medical_addenda_frozen"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_check_pet"("p_customer" "uuid", "p_pet" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_customer public.customers;
  v_pet public.pets;
begin
  select * into v_customer from public.customers where id = p_customer and is_active;
  if not found then
    raise exception 'customer not found' using errcode = 'P0002', hint = 'no_customer';
  end if;
  select p.* into v_pet
  from public.pets p
  join public.pet_owners o on o.pet_id = p.id and o.customer_id = p_customer and o.to_date is null
  where p.id = p_pet;
  if not found then
    raise exception 'the customer does not own this pet' using errcode = 'P0002', hint = 'no_pet';
  end if;
  if v_pet.status = 'deceased' then
    raise exception 'the pet is deceased' using errcode = 'P0001', hint = 'pet_deceased', detail = v_pet.name;
  end if;
  return jsonb_build_object(
    'pet_name', v_pet.name,
    'customer_name', v_customer.full_name,
    'customer_phone', v_customer.phone
  );
end;
$$;


ALTER FUNCTION "public"."medical_check_pet"("p_customer" "uuid", "p_pet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_diagnoses_lock"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_visit uuid := coalesce(new.visit_id, old.visit_id);
begin
  if exists (select 1 from public.medical_visits where id = v_visit and signed_at is not null) then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  return coalesce(new, old);
end;
$$;


ALTER FUNCTION "public"."medical_diagnoses_lock"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_local_date"("p_at" timestamp with time zone) RETURNS "date"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$ select (p_at at time zone 'Asia/Ho_Chi_Minh')::date; $$;


ALTER FUNCTION "public"."medical_local_date"("p_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_next_dose_no"("p_pet" "uuid", "p_type" "uuid") RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select count(*)::int + 1 from public.vaccinations
  where pet_id = p_pet and vaccine_type_id = p_type and voided_at is null;
$$;


ALTER FUNCTION "public"."medical_next_dose_no"("p_pet" "uuid", "p_type" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_next_due"("p_type" "uuid", "p_dose_no" integer, "p_given_on" "date") RETURNS "date"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select case
    when p_dose_no < t.series_doses then p_given_on + t.series_interval_days
    when t.booster_interval_days is not null then p_given_on + t.booster_interval_days
  end
  from public.vaccine_types t where t.id = p_type;
$$;


ALTER FUNCTION "public"."medical_next_due"("p_type" "uuid", "p_dose_no" integer, "p_given_on" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_prescription"("p_visit" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v public.medical_visits;
begin
  select * into v from public.medical_visits where id = p_visit;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return jsonb_build_object(
    'code', v.code,
    'date', public.medical_local_date(coalesce(v.signed_at, v.checked_in_at, v.created_at)),
    'branch_name', (select b.name from public.branches b where b.id = v.branch_id),
    'pet_name', v.pet_name,
    'species_name', (select s.name from public.pets p join public.species s on s.id = p.species_id where p.id = v.pet_id),
    'weight_kg', v.weight_kg,
    'customer_name', v.customer_name,
    'customer_phone', v.customer_phone,
    'vet_name', coalesce(v.signed_by_name, v.vet_name),
    'signed', v.signed_at is not null,
    'owner_instructions', v.owner_instructions,
    'recheck_on', v.recheck_on,
    'diagnoses', coalesce((
      select jsonb_agg(d.name order by d.sort_order) from public.medical_diagnoses d where d.visit_id = v.id
    ), '[]'::jsonb),
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', i.name, 'qty', i.qty,
        'unit_name', coalesce(i.unit_name, (select p.unit from public.products p where p.id = i.product_id)),
        'dose', i.dose, 'frequency', i.frequency, 'days', i.days, 'route', i.route,
        'instructions', i.instructions, 'external', i.kind = 'external'
      ) order by i.created_at, i.id)
      from public.medical_visit_items i where i.visit_id = v.id and i.take_home
    ), '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."medical_prescription"("p_visit" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_queue"("p_branch" "uuid", "p_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_today date := public.business_date();
  v_date  date := coalesce(p_date, public.business_date());
  v_days  int;
  v_rows  jsonb;
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select coalesce((select contagious_days from public.medical_settings where branch_id = p_branch), 30) into v_days;

  with q as (
    select v.*
    from public.medical_visits v
    where v.branch_id = p_branch
      and (
        (v.status = 'scheduled' and public.medical_local_date(v.scheduled_at) = v_date)
        or (v.status in ('waiting', 'in_progress', 'done')
            and (v.queue_date = v_date or (v_date = v_today and v.queue_date < v_today)))
      )
  )
  select coalesce(jsonb_agg(
    public.medical_visit_json(q) || jsonb_build_object(
      'has_allergy', coalesce(nullif(btrim(p.allergies), '') is not null, false),
      'has_behavior', coalesce(nullif(btrim(p.behavior_notes), '') is not null, false),
      'contagious', exists (
        select 1
        from public.medical_visits o
        join public.medical_diagnoses d on d.visit_id = o.id and d.is_contagious
        where o.pet_id = q.pet_id
          and coalesce(o.signed_at, o.started_at, o.created_at) >= now() - make_interval(days => v_days)
      )
    )
    order by (q.status = 'scheduled'), (q.priority = 'urgent') desc, coalesce(q.checked_in_at, q.scheduled_at), q.id
  ), '[]'::jsonb)
  into v_rows
  from q join public.pets p on p.id = q.pet_id;

  return jsonb_build_object(
    'date', v_date,
    'counts', jsonb_build_object(
      'scheduled', (select count(*) from jsonb_array_elements(v_rows) r where r ->> 'status' = 'scheduled'),
      'waiting', (select count(*) from jsonb_array_elements(v_rows) r where r ->> 'status' = 'waiting'),
      'in_progress', (select count(*) from jsonb_array_elements(v_rows) r where r ->> 'status' = 'in_progress'),
      'done', (select count(*) from jsonb_array_elements(v_rows) r where r ->> 'status' = 'done')
    ),
    'rows', v_rows
  );
end;
$$;


ALTER FUNCTION "public"."medical_queue"("p_branch" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_refresh_status"("p_visit" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  update public.medical_visits v set status = case
    when exists (
      select 1 from public.medical_visit_items i
      where i.visit_id = v.id and i.kind in ('service', 'product') and i.invoice_line_id is null
    ) then 'done' else 'paid' end
  where v.id = p_visit and v.signed_at is not null and v.status in ('done', 'paid');
$$;


ALTER FUNCTION "public"."medical_refresh_status"("p_visit" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_reminders"("p_branch" "uuid", "p_scope" "text" DEFAULT 'due'::"text", "p_search" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_today  date := public.business_date();
  v_ahead  int;
  v_term   text := lower(public.immutable_unaccent(btrim(coalesce(p_search, ''))));
  v_like   text := '%' || replace(replace(replace(v_term, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  v_digits text := regexp_replace(coalesce(p_search, ''), '\D', '', 'g');
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_scope not in ('due', 'overdue', 'recheck') then
    raise exception 'unknown scope' using errcode = '22023', hint = 'bad_input';
  end if;
  select coalesce((select remind_ahead_days from public.medical_settings where branch_id = p_branch), 7) into v_ahead;

  with owner as (
    select o.pet_id, c.id as customer_id, c.full_name, c.phone
    from public.pet_owners o
    join public.customers c on c.id = o.customer_id and c.is_active
    where o.role = 'primary' and o.to_date is null
  ), shots as (
    select distinct on (v.pet_id, v.vaccine_type_id)
      v.id, v.pet_id, v.vaccine_type_id, v.given_on, v.next_due_on, v.reminded_at, v.remind_note, v.reminded_by
    from public.vaccinations v
    where v.voided_at is null
    order by v.pet_id, v.vaccine_type_id, v.given_on desc, v.created_at desc
  ), items as (
    select 'vaccination'::text as kind, s.id as vaccination_id, null::uuid as visit_id, p.id as pet_id, p.name as pet_name,
           sp.name as species_name, ow.customer_id, ow.full_name as customer_name, ow.phone as customer_phone,
           t.name as vaccine_name, s.next_due_on as due_on, s.given_on as last_given_on,
           s.reminded_at, s.remind_note, s.reminded_by
    from shots s
    join public.pets p on p.id = s.pet_id and p.status = 'active'
    join public.species sp on sp.id = p.species_id
    join public.vaccine_types t on t.id = s.vaccine_type_id
    join owner ow on ow.pet_id = p.id
    where s.next_due_on is not null
      and ((p_scope = 'overdue' and s.next_due_on < v_today)
        or (p_scope = 'due' and s.next_due_on >= v_today and s.next_due_on <= v_today + v_ahead))
    union all
    select 'recheck', null, m.id, p.id, p.name, sp.name, ow.customer_id, ow.full_name, ow.phone,
           m.reason, public.medical_local_date(m.scheduled_at), null, null, null, null
    from public.medical_visits m
    join public.pets p on p.id = m.pet_id and p.status = 'active'
    join public.species sp on sp.id = p.species_id
    join owner ow on ow.pet_id = p.id
    where p_scope = 'recheck' and m.branch_id = p_branch and m.status = 'scheduled' and m.source = 'recheck'
      and public.medical_local_date(m.scheduled_at) <= v_today + v_ahead
  ), f as (
    select * from items i
    where v_term = ''
      or lower(public.immutable_unaccent(i.pet_name)) like v_like
      or lower(public.immutable_unaccent(i.customer_name)) like v_like
      or (length(v_digits) >= 3 and regexp_replace(i.customer_phone, '\D', '', 'g') like v_digits || '%')
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(jsonb_build_object(
        'kind', s.kind, 'vaccination_id', s.vaccination_id, 'visit_id', s.visit_id,
        'pet_id', s.pet_id, 'pet_name', s.pet_name, 'species_name', s.species_name,
        'customer_id', s.customer_id, 'customer_name', s.customer_name, 'customer_phone', s.customer_phone,
        'vaccine_name', s.vaccine_name, 'due_on', s.due_on, 'last_given_on', s.last_given_on,
        'reminded_at', s.reminded_at, 'remind_note', s.remind_note,
        'reminded_by_name', case when s.reminded_by is null then null else public.staff_display_name(s.reminded_by) end
      ) order by s.due_on, s.pet_name, s.vaccination_id)
      from (select * from f order by due_on, pet_name limit v_size offset v_offset) s
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."medical_reminders"("p_branch" "uuid", "p_scope" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_settings_get"("p_branch" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_build_object(
      'exam_service_id', s.exam_service_id,
      'exam_service_name', (select v.name from public.pet_services v where v.id = s.exam_service_id),
      'remind_ahead_days', coalesce(s.remind_ahead_days, 7),
      'contagious_days', coalesce(s.contagious_days, 30),
      'require_vaccine_for_boarding', coalesce(s.require_vaccine_for_boarding, false)
    )
    from (select 1) as one
    left join public.medical_settings s on s.branch_id = p_branch
  );
end;
$$;


ALTER FUNCTION "public"."medical_settings_get"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_stock_qty"("p_branch" "uuid", "p_product" "uuid") RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce(sum(qty_on_hand), 0)
  from public.stock_lots
  where branch_id = p_branch and product_id = p_product
    and (expiry_date is null or expiry_date >= public.business_date());
$$;


ALTER FUNCTION "public"."medical_stock_qty"("p_branch" "uuid", "p_product" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_user_can_update"("p_user" "uuid", "p_branch" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select exists (select 1 from public.users u where u.id = p_user and u.role in ('admin', 'superAdmin'))
      or exists (
        select 1
        from public.staff_branches sb
        join public.role_permissions rp on rp.role = sb.role
        where sb.user_id = p_user and sb.branch_id = p_branch
          and rp.permission = 'medical' and rp.methods && array['UPDATE', 'ALL']
      );
$$;


ALTER FUNCTION "public"."medical_user_can_update"("p_user" "uuid", "p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_vets"("p_branch" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', u.id, 'name', public.staff_display_name(u.id))
                     order by public.staff_display_name(u.id))
    from public.users u
    where u.role <> 'customer' and public.medical_user_can_update(u.id, p_branch)
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."medical_vets"("p_branch" "uuid") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_visits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "pet_name" "text" NOT NULL,
    "customer_name" "text" NOT NULL,
    "customer_phone" "text" NOT NULL,
    "status" "text" DEFAULT 'waiting'::"text" NOT NULL,
    "priority" "text" DEFAULT 'normal'::"text" NOT NULL,
    "queue_date" "date",
    "queue_no" integer,
    "scheduled_at" timestamp with time zone,
    "reason" "text",
    "vet_id" "uuid",
    "vet_name" "text",
    "checked_in_at" timestamp with time zone,
    "started_at" timestamp with time zone,
    "weight_kg" numeric(6,2),
    "temperature_c" numeric(4,1),
    "heart_rate" integer,
    "resp_rate" integer,
    "vitals_note" "text",
    "subjective" "text",
    "objective" "text",
    "assessment" "text",
    "plan" "text",
    "owner_instructions" "text",
    "outcome" "text",
    "recheck_on" "date",
    "follow_up_of" "uuid",
    "signed_at" timestamp with time zone,
    "signed_by" "uuid",
    "signed_by_name" "text",
    "source" "text" DEFAULT 'counter'::"text" NOT NULL,
    "cancelled_at" timestamp with time zone,
    "cancel_reason" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "medical_visits_check" CHECK ((("status" = 'scheduled'::"text") OR ("queue_no" IS NOT NULL) OR ("status" = ANY (ARRAY['cancelled'::"text", 'no_show'::"text"])))),
    CONSTRAINT "medical_visits_check1" CHECK ((("status" <> 'scheduled'::"text") OR ("scheduled_at" IS NOT NULL))),
    CONSTRAINT "medical_visits_heart_rate_check" CHECK (("heart_rate" > 0)),
    CONSTRAINT "medical_visits_outcome_check" CHECK (("outcome" = ANY (ARRAY['home'::"text", 'recheck'::"text", 'inpatient'::"text", 'referred'::"text", 'deceased'::"text"]))),
    CONSTRAINT "medical_visits_priority_check" CHECK (("priority" = ANY (ARRAY['normal'::"text", 'urgent'::"text"]))),
    CONSTRAINT "medical_visits_queue_no_check" CHECK (("queue_no" > 0)),
    CONSTRAINT "medical_visits_resp_rate_check" CHECK (("resp_rate" > 0)),
    CONSTRAINT "medical_visits_source_check" CHECK (("source" = ANY (ARRAY['counter'::"text", 'phone'::"text", 'recheck'::"text", 'web'::"text"]))),
    CONSTRAINT "medical_visits_status_check" CHECK (("status" = ANY (ARRAY['scheduled'::"text", 'waiting'::"text", 'in_progress'::"text", 'done'::"text", 'paid'::"text", 'cancelled'::"text", 'no_show'::"text"]))),
    CONSTRAINT "medical_visits_temperature_c_check" CHECK ((("temperature_c" >= (25)::numeric) AND ("temperature_c" <= (45)::numeric))),
    CONSTRAINT "medical_visits_weight_kg_check" CHECK (("weight_kg" > (0)::numeric))
);


ALTER TABLE "public"."medical_visits" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_visit_json"("v" "public"."medical_visits") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', v.id,
    'code', v.code,
    'branch_id', v.branch_id,
    'status', v.status,
    'priority', v.priority,
    'queue_date', v.queue_date,
    'queue_no', v.queue_no,
    'scheduled_at', v.scheduled_at,
    'checked_in_at', v.checked_in_at,
    'started_at', v.started_at,
    'signed_at', v.signed_at,
    'created_at', v.created_at,
    'pet_id', v.pet_id,
    'pet_name', v.pet_name,
    'pet_photo_url', (select p.photo_url from public.pets p where p.id = v.pet_id),
    'species_name', (select s.name from public.pets p join public.species s on s.id = p.species_id where p.id = v.pet_id),
    'customer_id', v.customer_id,
    'customer_name', v.customer_name,
    'customer_phone', v.customer_phone,
    'reason', v.reason,
    'vet_id', v.vet_id,
    'vet_name', v.vet_name,
    'weight_kg', v.weight_kg,
    'outcome', v.outcome,
    'recheck_on', v.recheck_on,
    'follow_up_of', v.follow_up_of,
    'diagnoses_text', (
      select string_agg(d.name, ', ' order by d.sort_order) from public.medical_diagnoses d where d.visit_id = v.id
    ),
    -- What the visit will cost: the service and product lines (external medicine is free).
    'est_total', coalesce((
      select sum(i.amount) from public.medical_visit_items i where i.visit_id = v.id and i.kind in ('service', 'product')
    ), 0)
  );
$$;


ALTER FUNCTION "public"."medical_visit_json"("v" "public"."medical_visits") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_visits_inpatient_guard"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if ((old.signed_at is null and new.signed_at is not null) or (old.status <> 'cancelled' and new.status = 'cancelled'))
     and exists (
       select 1 from public.boarding_stays s
       where s.visit_id = new.id and s.kind = 'inpatient' and s.status = 'checked_in'
     ) then
    raise exception 'the pet is still in the clinic' using errcode = 'P0001', hint = 'inpatient_active';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."medical_visits_inpatient_guard"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."medical_visits_lock"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if old.signed_at is null then
    return new;
  end if;
  if new.signed_at is distinct from old.signed_at
     or new.signed_by is distinct from old.signed_by
     or new.pet_id is distinct from old.pet_id
     or new.customer_id is distinct from old.customer_id
     or new.weight_kg is distinct from old.weight_kg
     or new.temperature_c is distinct from old.temperature_c
     or new.heart_rate is distinct from old.heart_rate
     or new.resp_rate is distinct from old.resp_rate
     or new.vitals_note is distinct from old.vitals_note
     or new.subjective is distinct from old.subjective
     or new.objective is distinct from old.objective
     or new.assessment is distinct from old.assessment
     or new.plan is distinct from old.plan
     or new.owner_instructions is distinct from old.owner_instructions
     or new.outcome is distinct from old.outcome
     or new.recheck_on is distinct from old.recheck_on then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."medical_visits_lock"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."move_boarding_pet"("p_stay_pet" "uuid", "p_kennel" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."move_boarding_pet"("p_stay_pet" "uuid", "p_kennel" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."move_product_category"("p_id" "uuid", "p_direction" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_parent uuid;
  v_ids    uuid[];
  v_pos    int;
  v_other  int;
begin
  if not public.can_products('UPDATE') then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if p_direction not in ('up', 'down') then
    raise exception 'direction must be up or down' using errcode = '22023';
  end if;
  select parent_id into v_parent from public.product_categories where id = p_id;
  if not found then
    raise exception 'category % not found', p_id using errcode = 'P0002';
  end if;

  select array_agg(id order by sort_order, lower(name), id) into v_ids
  from public.product_categories where parent_id is not distinct from v_parent;
  v_pos := array_position(v_ids, p_id);
  v_other := case when p_direction = 'up' then v_pos - 1 else v_pos + 1 end;
  if v_other < 1 or v_other > array_length(v_ids, 1) then
    return;
  end if;
  v_ids[v_pos] := v_ids[v_other];
  v_ids[v_other] := p_id;

  -- Rewrite the siblings' order 1..n so ties never keep two rows in the same place.
  update public.product_categories c
  set sort_order = o.ord::int
  from unnest(v_ids) with ordinality as o(id, ord)
  where c.id = o.id and c.sort_order is distinct from o.ord::int;
end;
$$;


ALTER FUNCTION "public"."move_product_category"("p_id" "uuid", "p_direction" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."move_stock"("p_lot" "uuid", "p_qty" numeric, "p_reason" "text", "p_document" "uuid" DEFAULT NULL::"uuid", "p_document_line" "uuid" DEFAULT NULL::"uuid", "p_invoice" "uuid" DEFAULT NULL::"uuid", "p_invoice_line" "uuid" DEFAULT NULL::"uuid", "p_return" "uuid" DEFAULT NULL::"uuid", "p_unit_cost" numeric DEFAULT NULL::numeric) RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_lot  public.stock_lots;
  v_name text;
begin
  select * into v_lot from public.stock_lots where id = p_lot for update;
  if not found then
    raise exception 'lot % not found', p_lot using errcode = 'P0002';
  end if;
  if v_lot.qty_on_hand + p_qty < 0 then
    select name into v_name from public.products where id = v_lot.product_id;
    raise exception 'lot "%" of % holds only %', v_lot.lot_no, v_name, v_lot.qty_on_hand
      using errcode = 'P0001', hint = 'lot_short', detail = v_name;
  end if;

  update public.stock_lots set qty_on_hand = qty_on_hand + p_qty where id = p_lot;

  insert into public.stock_movements (
    branch_id, product_id, lot_id, qty, unit_cost, reason, balance_after,
    document_id, document_line_id, invoice_id, invoice_line_id, return_id, created_by
  ) values (
    v_lot.branch_id, v_lot.product_id, p_lot, p_qty, coalesce(p_unit_cost, v_lot.unit_cost), p_reason,
    v_lot.qty_on_hand + p_qty, p_document, p_document_line, p_invoice, p_invoice_line, p_return,
    (select auth.uid())
  );
  return coalesce(p_unit_cost, v_lot.unit_cost);
end;
$$;


ALTER FUNCTION "public"."move_stock"("p_lot" "uuid", "p_qty" numeric, "p_reason" "text", "p_document" "uuid", "p_document_line" "uuid", "p_invoice" "uuid", "p_invoice_line" "uuid", "p_return" "uuid", "p_unit_cost" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_addresses"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(public.address_json(a) order by a.is_default desc, a.created_at desc, a.id)
    from public.customer_addresses a
    where a.user_id = v_uid
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."my_addresses"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_appointments"("p_scope" "text" DEFAULT 'upcoming'::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 10) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cust   uuid := public.my_customer_id();
  v_size   int := least(greatest(coalesce(p_page_size, 10), 1), 50);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_cancel interval := make_interval(mins => (public.spa_web_rules() ->> 'cancel_before_minutes')::int);
  v_upcoming boolean;
  v_total  bigint;
  v_rows   jsonb;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if p_scope not in ('upcoming', 'past') then
    raise exception 'unknown scope' using errcode = '22023', hint = 'invalid_scope';
  end if;
  v_upcoming := p_scope = 'upcoming';
  if v_cust is null then
    return jsonb_build_object('total', 0, 'rows', '[]'::jsonb);
  end if;

  with f as (
    select a.*
    from public.appointments a
    where a.customer_id = v_cust
      and (a.status in ('booked', 'checked_in', 'in_progress')) = v_upcoming
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', a.id,
          'code', a.code,
          'status', a.status,
          'start_at', a.start_at,
          'end_at', a.end_at,
          'note', a.note,
          'branch_name', b.name,
          'branch_phone', b.phone,
          'can_cancel', a.status = 'booked' and a.start_at - now() > v_cancel,
          'est_total', (
            select coalesce(sum(i.est_price), 0)
            from public.appointment_items i where i.appointment_id = a.id and i.status <> 'cancelled'
          ),
          'has_unpriced', exists (
            select 1 from public.appointment_items i
            where i.appointment_id = a.id and i.status <> 'cancelled' and i.est_price is null
          ),
          'items', (
            select coalesce(jsonb_agg(
              jsonb_build_object(
                'name', i.name,
                'pet_name', pt.name,
                'pet_photo_url', pt.photo_url,
                'start_at', i.start_at,
                'status', i.status,
                'est_price', i.est_price
              ) order by i.line_no), '[]'::jsonb)
            from public.appointment_items i
            left join public.pets pt on pt.id = i.pet_id
            where i.appointment_id = a.id
          )
        )
        order by case when v_upcoming then a.start_at end asc, case when not v_upcoming then a.start_at end desc
      )
      from (
        select * from f
        order by case when v_upcoming then start_at end asc, case when not v_upcoming then start_at end desc
        limit v_size offset v_offset
      ) a
      join public.branches b on b.id = a.branch_id
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."my_appointments"("p_scope" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_boarding_stay"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cust uuid := public.my_customer_id();
  v_stay public.boarding_stays;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  select * into v_stay from public.boarding_stays where id = p_id and customer_id = v_cust;
  if not found then
    raise exception 'stay not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  return public.my_boarding_stay_json(v_stay) || jsonb_build_object(
    'care_logs', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', l.id,
        'pet_name', sp.pet_name,
        'kind', l.kind,
        'meal_eaten', l.meal_eaten,
        'content', l.content,
        'logged_at', l.logged_at
      ) order by l.logged_at desc)
      from public.boarding_care_logs l
      join public.boarding_stay_pets sp on sp.id = l.stay_pet_id
      where sp.stay_id = v_stay.id and l.visible_to_customer
    ), '[]'::jsonb),
    'charges', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', c.id,
        'pet_name', sp.pet_name,
        'kind', c.kind,
        'name', c.name,
        'qty', c.qty,
        'unit_price', c.unit_price,
        'amount', c.amount
      ) order by c.created_at, c.id)
      from public.boarding_charges c
      left join public.boarding_stay_pets sp on sp.id = c.stay_pet_id
      where c.stay_id = v_stay.id
    ), '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."my_boarding_stay"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_boarding_stay_json"("p_stay" "public"."boarding_stays") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', p_stay.id,
    'code', p_stay.code,
    'status', p_stay.status,
    'planned_in_at', p_stay.planned_in_at,
    'planned_out_at', p_stay.planned_out_at,
    'checked_in_at', p_stay.checked_in_at,
    'checked_out_at', p_stay.checked_out_at,
    'branch_name', b.name,
    'branch_phone', b.phone,
    'est_total', (public.boarding_stay_json(p_stay) ->> 'est_total')::numeric,
    'is_final', p_stay.status in ('checked_out', 'paid'),
    'pets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'pet_name', sp.pet_name,
        'pet_photo_url', (select pt.photo_url from public.pets pt where pt.id = sp.pet_id),
        'status', sp.status,
        'kennel_type_name', t.name,
        'nights_from', lower(sp.nights),
        'nights_to', upper(sp.nights),
        'charged_nights', sp.charged_nights,
        'feeding', sp.feeding,
        'medication', sp.medication
      ) order by sp.line_no)
      from public.boarding_stay_pets sp
      join public.kennel_types t on t.id = sp.kennel_type_id
      where sp.stay_id = p_stay.id
    ), '[]'::jsonb)
  )
  from public.branches b
  where b.id = p_stay.branch_id;
$$;


ALTER FUNCTION "public"."my_boarding_stay_json"("p_stay" "public"."boarding_stays") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_boarding_stays"("p_scope" "text" DEFAULT 'upcoming'::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 10) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cust   uuid := public.my_customer_id();
  v_size   int := least(greatest(coalesce(p_page_size, 10), 1), 50);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_states text[];
  v_total  bigint;
  v_rows   jsonb;
begin
  if auth.uid() is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  v_states := case p_scope
    when 'upcoming' then array['booked']
    when 'current' then array['checked_in']
    when 'past' then array['checked_out', 'paid', 'cancelled', 'no_show']
  end;
  if v_states is null then
    raise exception 'unknown scope' using errcode = '22023', hint = 'invalid_scope';
  end if;
  if v_cust is null then
    return jsonb_build_object('total', 0, 'rows', '[]'::jsonb);
  end if;

  select count(*) into v_total
  from public.boarding_stays s where s.customer_id = v_cust and s.status = any(v_states);

  select coalesce(jsonb_agg(public.my_boarding_stay_json(s) order by
           case when p_scope = 'past' then null else s.planned_in_at end asc,
           s.planned_in_at desc), '[]'::jsonb)
  into v_rows
  from (
    select * from public.boarding_stays s
    where s.customer_id = v_cust and s.status = any(v_states)
    order by case when p_scope = 'past' then null else s.planned_in_at end asc, s.planned_in_at desc
    limit v_size offset v_offset
  ) s;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."my_boarding_stays"("p_scope" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_customer_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select id from public.customers where user_id = (select auth.uid());
$$;


ALTER FUNCTION "public"."my_customer_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_permissions"("p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("branch_id" "uuid", "role" "text", "permission" "text", "methods" "text"[])
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select b.id, 'superAdmin', p.name, p.methods
  from public.branches b
  cross join public.permissions p
  where (select public.is_super_admin())
    and (p_branch is null or b.id = p_branch)
  union all
  select sb.branch_id, sb.role, rp.permission, rp.methods
  from public.staff_branches sb
  join public.role_permissions rp on rp.role = sb.role
  where not (select public.is_super_admin())
    and sb.user_id = (select auth.uid())
    and (p_branch is null or sb.branch_id = p_branch);
$$;


ALTER FUNCTION "public"."my_permissions"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_pet_health"("p_pet" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid   uuid := (select auth.uid());
  v_cust  uuid := public.my_customer_id();
  v_today date := public.business_date();
  v_pet   public.pets;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  select p.* into v_pet
  from public.pets p
  join public.pet_owners po on po.pet_id = p.id
  where p.id = p_pet and po.customer_id = v_cust and po.to_date is null and p.status in ('active', 'deceased');
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  return jsonb_build_object(
    'pet_id', v_pet.id,
    'pet_name', v_pet.name,
    'status', v_pet.status,
    'deceased_on', v_pet.deceased_on,
    'pet_photo_url', v_pet.photo_url,
    'phone', (
      select b.phone from public.branches b where b.is_active and b.phone is not null
      order by b.created_at limit 1
    ),
    'vaccines', coalesce((
      select jsonb_agg(entry order by (entry ->> 'last_given_on') desc, entry ->> 'name')
      from (
        select jsonb_build_object(
          'vaccine_type_id', t.id,
          'name', t.name,
          'kind', t.kind,
          'last_given_on', last.given_on,
          'next_due_on', case when v_pet.status = 'active' then last.next_due_on end,
          'state', case
            when last.next_due_on is null or v_pet.status <> 'active' then 'ok'
            when last.next_due_on < v_today then 'overdue'
            when last.next_due_on <= v_today + 14 then 'due_soon'
            else 'ok' end,
          'doses', (
            select jsonb_agg(jsonb_build_object(
              'dose_no', d.dose_no, 'given_on', d.given_on,
              'is_external', d.is_external, 'external_place', d.external_place
            ) order by d.given_on desc, d.created_at desc)
            from public.vaccinations d
            where d.pet_id = v_pet.id and d.vaccine_type_id = t.id and d.voided_at is null
          )
        ) as entry
        from public.vaccine_types t
        join lateral (
          select v.given_on, v.next_due_on from public.vaccinations v
          where v.pet_id = v_pet.id and v.vaccine_type_id = t.id and v.voided_at is null
          order by v.given_on desc, v.created_at desc limit 1
        ) last on true
      ) e
    ), '[]'::jsonb),
    'visits', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', mv.id,
        'date', public.medical_local_date(mv.signed_at),
        'reason', mv.reason,
        'diagnoses', coalesce((
          select jsonb_agg(d.name order by d.sort_order, d.created_at)
          from public.medical_diagnoses d where d.visit_id = mv.id
        ), '[]'::jsonb),
        'owner_instructions', mv.owner_instructions,
        'recheck_on', mv.recheck_on,
        'branch_name', (select b.name from public.branches b where b.id = mv.branch_id),
        'take_home', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', i.name, 'dose', i.dose, 'frequency', i.frequency, 'days', i.days,
            'route', i.route, 'instructions', i.instructions
          ) order by i.created_at, i.id)
          from public.medical_visit_items i
          where i.visit_id = mv.id and i.take_home and i.kind in ('product', 'external')
        ), '[]'::jsonb)
      ) order by mv.signed_at desc)
      from public.medical_visits mv
      where mv.pet_id = v_pet.id and mv.signed_at is not null and mv.status in ('done', 'paid')
    ), '[]'::jsonb)
  );
end;
$$;


ALTER FUNCTION "public"."my_pet_health"("p_pet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_pets"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
               'photo_url', p.photo_url,
               'sex', p.sex,
               'neutered', p.neutered,
               'birth_date', p.birth_date,
               'status', p.status,
               'deceased_on', p.deceased_on,
               'allergies', p.allergies,
               'behavior_notes', p.behavior_notes,
               'weight_kg', (
                 select l.weight_kg from public.pet_weight_logs l
                 where l.pet_id = p.id order by l.measured_at desc limit 1
               ),
               'role', po.role,
               'can_edit', po.role = 'primary',
               'has_open_appointment', p.status = 'active' and exists (
                 select 1
                 from public.appointment_items ai
                 join public.appointments a on a.id = ai.appointment_id
                 where ai.pet_id = p.id and a.status in ('booked', 'checked_in', 'in_progress')
               ),
               'next_vaccine', (
                 select jsonb_build_object('name', t.name, 'due_on', l.next_due_on)
                 from public.vaccine_types t
                 join lateral (
                   select v.next_due_on from public.vaccinations v
                   where v.pet_id = p.id and v.vaccine_type_id = t.id and v.voided_at is null
                   order by v.given_on desc, v.created_at desc limit 1
                 ) l on true
                 where l.next_due_on is not null and p.status = 'active'
                 order by l.next_due_on, t.name
                 limit 1
               )
             )
             order by (p.status = 'active') desc, lower(p.name), p.created_at
           )
    from public.pet_owners po
    join public.pets p on p.id = po.pet_id
    join public.species s on s.id = p.species_id
    where po.customer_id = v_cust and po.to_date is null and p.status in ('active', 'deceased')
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."my_pets"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_profile"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := auth.uid();
  v_row jsonb;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  select jsonb_build_object(
           'email', u.email,
           'full_name', coalesce(nullif(btrim(c.full_name), ''), u.full_name, u.display_name),
           'phone', coalesce(c.phone, u.phone_number),
           'birth_date', c.birth_date,
           'customer_id', c.id
         )
    into v_row
  from public.users u
  left join public.customers c on c.user_id = u.id
  where u.id = v_uid;
  return coalesce(v_row, jsonb_build_object('email', null, 'full_name', null, 'phone', null,
                                            'birth_date', null, 'customer_id', null));
end;
$$;


ALTER FUNCTION "public"."my_profile"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_shop_order"("p_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := (select auth.uid());
  v_row public.shop_orders;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  select * into v_row from public.shop_orders where code = p_code and user_id = v_uid;
  if not found then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  return public.my_shop_order_json(v_row);
end;
$$;


ALTER FUNCTION "public"."my_shop_order"("p_code" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'pending'::"text" NOT NULL,
    "delivery_method" "text" NOT NULL,
    "payment_method" "text" NOT NULL,
    "receiver_name" "text" NOT NULL,
    "receiver_phone" "text" NOT NULL,
    "ship_street" "text",
    "ship_ward_name" "text",
    "ship_district_name" "text",
    "ship_province_name" "text",
    "ghn_district_id" integer,
    "ghn_ward_code" "text",
    "weight_g" integer DEFAULT 0 NOT NULL,
    "subtotal" numeric(14,2) NOT NULL,
    "shipping_fee_quote" numeric(14,0) DEFAULT 0 NOT NULL,
    "shipping_fee" numeric(14,0),
    "total" numeric(14,2) NOT NULL,
    "customer_note" "text",
    "invoice_id" "uuid",
    "carrier" "text",
    "tracking_code" "text",
    "cancel_reason" "text",
    "client_ref" "uuid",
    "placed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "confirmed_at" timestamp with time zone,
    "packed_at" timestamp with time zone,
    "shipped_at" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "shop_orders_carrier_check" CHECK (("carrier" = 'ghn'::"text")),
    CONSTRAINT "shop_orders_check" CHECK ((("delivery_method" = 'delivery'::"text") = (("ghn_district_id" IS NOT NULL) AND ("ghn_ward_code" IS NOT NULL)))),
    CONSTRAINT "shop_orders_check1" CHECK ((("delivery_method" = 'pickup'::"text") OR ("length"("btrim"(COALESCE("ship_street", ''::"text"))) > 0))),
    CONSTRAINT "shop_orders_check2" CHECK ((("delivery_method" = 'pickup'::"text") = ("payment_method" = 'pay_at_store'::"text"))),
    CONSTRAINT "shop_orders_check3" CHECK (("total" = ("subtotal" + COALESCE("shipping_fee", "shipping_fee_quote")))),
    CONSTRAINT "shop_orders_delivery_method_check" CHECK (("delivery_method" = ANY (ARRAY['delivery'::"text", 'pickup'::"text"]))),
    CONSTRAINT "shop_orders_payment_method_check" CHECK (("payment_method" = ANY (ARRAY['cod'::"text", 'pay_at_store'::"text"]))),
    CONSTRAINT "shop_orders_receiver_name_check" CHECK (("length"("btrim"("receiver_name")) > 0)),
    CONSTRAINT "shop_orders_shipping_fee_check" CHECK (("shipping_fee" >= (0)::numeric)),
    CONSTRAINT "shop_orders_shipping_fee_quote_check" CHECK (("shipping_fee_quote" >= (0)::numeric)),
    CONSTRAINT "shop_orders_status_check" CHECK (("status" = ANY (ARRAY['pending'::"text", 'confirmed'::"text", 'packed'::"text", 'shipping'::"text", 'completed'::"text", 'cancelled'::"text", 'returned'::"text"]))),
    CONSTRAINT "shop_orders_subtotal_check" CHECK (("subtotal" >= (0)::numeric)),
    CONSTRAINT "shop_orders_weight_g_check" CHECK (("weight_g" >= 0))
);


ALTER TABLE "public"."shop_orders" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_shop_order_json"("o" "public"."shop_orders") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', o.id,
    'code', o.code,
    'status', o.status,
    'delivery_method', o.delivery_method,
    'payment_method', o.payment_method,
    'receiver_name', o.receiver_name,
    'receiver_phone', o.receiver_phone,
    'ship_street', o.ship_street,
    'ship_ward_name', o.ship_ward_name,
    'ship_district_name', o.ship_district_name,
    'ship_province_name', o.ship_province_name,
    'weight_g', o.weight_g,
    'subtotal', o.subtotal,
    'shipping_fee_quote', o.shipping_fee_quote,
    'shipping_fee', o.shipping_fee,
    'shipping_fee_confirmed', o.shipping_fee is not null,
    'total', o.total,
    'customer_note', o.customer_note,
    'carrier', o.carrier,
    'tracking_code', o.tracking_code,
    'cancel_reason', o.cancel_reason,
    'placed_at', o.placed_at,
    'payment_status', case
      when exists (select 1 from public.invoices i where i.id = o.invoice_id and i.status = 'paid') then 'paid'
      else 'unpaid'
    end,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', l.product_id, 'unit_id', l.unit_id, 'name', l.name, 'unit', l.unit,
        'image_url', l.image_url, 'qty', l.qty, 'unit_price', l.unit_price, 'amount', l.amount
      ) order by l.line_no)
      from public.shop_order_lines l where l.order_id = o.id
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object('status', e.status, 'note', e.note, 'created_at', e.created_at)
                       order by e.created_at, e.id)
      from public.shop_order_events e where e.order_id = o.id
    ), '[]'::jsonb)
  );
$$;


ALTER FUNCTION "public"."my_shop_order_json"("o" "public"."shop_orders") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."my_shop_orders"("p_status" "text" DEFAULT NULL::"text", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 10) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid  uuid := (select auth.uid());
  v_size int := least(greatest(coalesce(p_page_size, 10), 1), 50);
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_rows jsonb;
  v_total bigint;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;

  select count(*) into v_total from public.shop_orders o
  where o.user_id = v_uid and (p_status is null or o.status = p_status);

  select coalesce(jsonb_agg(x order by x.placed_at desc, x.code desc), '[]'::jsonb) into v_rows
  from (
    select o.id, o.code, o.status, o.delivery_method, o.total, o.placed_at,
           (select count(*) from public.shop_order_lines l where l.order_id = o.id) as line_count,
           (select l.name from public.shop_order_lines l where l.order_id = o.id order by l.line_no limit 1) as first_name,
           (select l.image_url from public.shop_order_lines l where l.order_id = o.id order by l.line_no limit 1) as first_image
    from public.shop_orders o
    where o.user_id = v_uid and (p_status is null or o.status = p_status)
    order by o.placed_at desc, o.code desc
    offset (v_page - 1) * v_size limit v_size
  ) x;

  return jsonb_build_object('rows', v_rows, 'total_count', v_total);
end;
$$;


ALTER FUNCTION "public"."my_shop_orders"("p_status" "text", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."next_doc_code"("p_branch" "uuid", "p_type" "text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_code text;
  v_no   bigint;
begin
  select code into v_code from public.branches where id = p_branch;
  if v_code is null then
    raise exception 'branch % not found', p_branch using errcode = 'P0002';
  end if;

  insert into public.doc_sequences as s (branch_id, doc_type, last_no)
  values (p_branch, p_type, 1)
  on conflict (branch_id, doc_type) do update set last_no = s.last_no + 1
  returning last_no into v_no;

  return v_code || '-' || p_type || '-' || lpad(v_no::text, 6, '0');
end;
$$;


ALTER FUNCTION "public"."next_doc_code"("p_branch" "uuid", "p_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."open_cash_shift"("p_branch" "uuid", "p_opening_cash" numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid;
begin
  if (select auth.uid()) is null or not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed to sell at this branch' using errcode = '42501';
  end if;
  if coalesce(p_opening_cash, -1) < 0 then
    raise exception 'opening cash must be zero or more' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.cash_shifts
    where branch_id = p_branch and opened_by = (select auth.uid()) and status = 'open'
  ) then
    raise exception 'a shift is already open' using errcode = '23505';
  end if;

  insert into public.cash_shifts (code, branch_id, opened_by, opened_by_name, opening_cash, open_note)
  values (
    public.next_doc_code(p_branch, 'CA'),
    p_branch,
    (select auth.uid()),
    public.staff_display_name((select auth.uid())),
    p_opening_cash,
    nullif(btrim(p_note), '')
  )
  returning id into v_id;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."open_cash_shift"("p_branch" "uuid", "p_opening_cash" numeric, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pack_shop_order"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o public.shop_orders := public.shop_order_for_update(p_id, array['confirmed']);
begin
  perform public.issue_shop_order_invoice(o.id);
  update public.shop_orders set status = 'packed', packed_at = now() where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'packed');
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."pack_shop_order"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pay_pickup_shop_order"("p_id" "uuid", "p_payments" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid    uuid := (select auth.uid());
  o        public.shop_orders;
  i        public.invoices;
  v_shift  uuid;
  v_pay    jsonb;
  v_method text;
  v_amount numeric;
  v_paid   numeric := 0;
  v_cash   numeric := 0;
  v_change numeric;
begin
  select * into o from public.shop_orders where id = p_id for update;
  if not found or v_uid is null or not public.can_pos('CREATE', o.branch_id) then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  if o.delivery_method <> 'pickup' then
    raise exception 'only a pickup order is paid at the counter' using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;
  if o.status = 'completed' then
    return public.staff_shop_order_json(o);
  end if;
  if o.status <> 'packed' then
    raise exception 'the order is % now', o.status using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;

  -- Locked like a sale, so the shift cannot be closed and counted while this payment commits.
  select id into v_shift
  from public.cash_shifts
  where branch_id = o.branch_id and opened_by = v_uid and status = 'open'
  for share;
  if v_shift is null then
    raise exception 'open a cash shift before taking payment' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  select * into i from public.invoices where id = o.invoice_id for update;

  for v_pay in select * from jsonb_array_elements(coalesce(p_payments, '[]'::jsonb)) loop
    v_method := v_pay ->> 'method';
    v_amount := coalesce(nullif(v_pay ->> 'amount', '')::numeric, 0);
    if v_amount <= 0 then
      continue;
    end if;
    if v_method not in ('cash', 'transfer', 'card') then
      raise exception 'unknown payment method %', v_method using errcode = '22023';
    end if;
    insert into public.payments (invoice_id, method, amount, bank_ref)
    values (i.id, v_method, v_amount, nullif(btrim(v_pay ->> 'bank_ref'), ''));
    v_paid := v_paid + v_amount;
    if v_method = 'cash' then
      v_cash := v_cash + v_amount;
    end if;
  end loop;

  if v_paid < i.total then
    raise exception 'payments do not cover the total' using errcode = '22023', hint = 'underpaid';
  end if;
  v_change := v_paid - i.total;
  -- Only cash can be overpaid and handed back.
  if v_change > v_cash then
    raise exception 'transfer and card cannot exceed the total' using errcode = '22023', hint = 'overpaid';
  end if;

  update public.invoices
  set status = 'paid', shift_id = v_shift, paid_amount = v_paid, change_amount = v_change,
      cashier_name = public.staff_display_name(v_uid)
  where id = i.id;

  update public.shop_orders set status = 'completed', completed_at = now() where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'completed');
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."pay_pickup_shop_order"("p_id" "uuid", "p_payments" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pet_deceased_cleanup"("p_pet" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."pet_deceased_cleanup"("p_pet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pet_deceased_impact"("p_pet" "uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."pet_deceased_impact"("p_pet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pet_deceased_preview"("p_pet" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."pet_deceased_preview"("p_pet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pet_health_flags"("p_pet_ids" "uuid"[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_today date := public.business_date();
  v_days  int;
begin
  if not public.is_staff() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select coalesce(max(contagious_days), 30) into v_days from public.medical_settings;

  return coalesce((
    select jsonb_object_agg(p.id::text, jsonb_build_object(
      'contagious', exists (
        select 1
        from public.medical_visits o
        join public.medical_diagnoses d on d.visit_id = o.id and d.is_contagious
        where o.pet_id = p.id and o.status not in ('cancelled', 'no_show')
          and coalesce(o.signed_at, o.started_at, o.created_at) >= now() - make_interval(days => v_days)
      ),
      'vaccine_overdue', exists (
        select 1
        from public.vaccine_types t
        join lateral (
          select v.next_due_on from public.vaccinations v
          where v.pet_id = p.id and v.vaccine_type_id = t.id and v.voided_at is null
          order by v.given_on desc, v.created_at desc limit 1
        ) last on true
        where last.next_due_on is not null and last.next_due_on < v_today
      ),
      'allergies', nullif(btrim(p.allergies), '')
    ))
    from public.pets p
    where p.id = any (coalesce(p_pet_ids, '{}'::uuid[]))
  ), '{}'::jsonb);
end;
$$;


ALTER FUNCTION "public"."pet_health_flags"("p_pet_ids" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pet_medical_history"("p_pet" "uuid", "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_size   int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset int := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  bigint;
  v_rows   jsonb;
begin
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  with f as (
    select v.*
    from public.medical_visits v
    where v.pet_id = p_pet and v.status in ('waiting', 'in_progress', 'done', 'paid')
  )
  select
    (select count(*) from f),
    coalesce((
      select jsonb_agg(
        public.medical_visit_json(s) || jsonb_build_object(
          'branch_name', (select b.name from public.branches b where b.id = s.branch_id),
          'owner_instructions', s.owner_instructions
        )
        order by s.created_at desc, s.id)
      from (select * from f order by created_at desc, id limit v_size offset v_offset) s
    ), '[]'::jsonb)
  into v_total, v_rows;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end;
$$;


ALTER FUNCTION "public"."pet_medical_history"("p_pet" "uuid", "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pet_vaccinations"("p_pet" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_today date := public.business_date();
begin
  if not public.can_medical('VIEW') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(entry order by (entry ->> 'last_given_on') desc, entry ->> 'name')
    from (
      select jsonb_build_object(
        'vaccine_type_id', t.id,
        'name', t.name,
        'kind', t.kind,
        'last_given_on', last.given_on,
        'next_due_on', last.next_due_on,
        'state', case
          when last.next_due_on is null then 'ok'
          when last.next_due_on < v_today then 'overdue'
          when last.next_due_on <= v_today + 14 then 'due_soon'
          else 'ok' end,
        'doses', (
          select jsonb_agg(jsonb_build_object(
            'id', d.id, 'dose_no', d.dose_no, 'given_on', d.given_on, 'lot_no', d.lot_no,
            'expiry_date', d.expiry_date, 'is_external', d.is_external, 'external_place', d.external_place,
            'vet_name', d.vet_name, 'next_due_on', d.next_due_on, 'visit_id', d.visit_id,
            'branch_name', (select b.name from public.branches b where b.id = d.branch_id),
            'voided_at', d.voided_at
          ) order by d.given_on desc, d.created_at desc)
          from public.vaccinations d where d.pet_id = p_pet and d.vaccine_type_id = t.id
        )
      ) as entry
      from public.vaccine_types t
      join lateral (
        select v.given_on, v.next_due_on from public.vaccinations v
        where v.pet_id = p_pet and v.vaccine_type_id = t.id and v.voided_at is null
        order by v.given_on desc, v.created_at desc limit 1
      ) last on true
    ) e
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."pet_vaccinations"("p_pet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pets_deceased_after"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  perform public.pet_deceased_cleanup(new.id);
  return new;
end;
$$;


ALTER FUNCTION "public"."pets_deceased_after"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pets_deceased_before"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."pets_deceased_before"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."place_shop_order"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid      uuid := (select auth.uid());
  v_ref      uuid := nullif(p ->> 'client_ref', '')::uuid;
  v_old      public.shop_orders;
  v_s        public.shop_settings;
  v_user     public.users;
  v_method   text := coalesce(p ->> 'delivery_method', '');
  v_addr     public.customer_addresses;
  v_name     text;
  v_phone    text;
  v_n        int := 0;
  r          record;
  v_prod     record;
  v_unit     public.product_units;
  v_factor   numeric;
  v_price    numeric;
  v_lines    jsonb := '[]'::jsonb;
  v_ids      uuid[] := '{}';
  v_subtotal numeric := 0;
  v_goods_g  numeric := 0;
  v_weight   int;
  v_quote    numeric;
  v_missing  text;
  v_customer uuid;
  v_id       uuid;
  v_code     text;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if v_ref is null then
    raise exception 'client_ref is required' using errcode = '22023', hint = 'client_ref_required';
  end if;

  -- A retry of the same press returns the order that press made.
  select * into v_old from public.shop_orders where client_ref = v_ref;
  if found then
    if v_old.user_id <> v_uid then
      raise exception 'client_ref is already used' using errcode = '22023', hint = 'client_ref_required';
    end if;
    return jsonb_build_object('id', v_old.id, 'code', v_old.code, 'total', v_old.total, 'replayed', true);
  end if;

  select * into v_s from public.shop_settings where id;
  if not found then
    raise exception 'shop settings are missing' using errcode = 'P0002';
  end if;
  select * into v_user from public.users where id = v_uid;

  -- --------------------------------------------------- delivery method and receiver
  if v_method not in ('delivery', 'pickup') then
    raise exception 'choose delivery or pickup' using errcode = '22023', hint = 'invalid_delivery';
  end if;
  if v_method = 'delivery' then
    if not v_s.allow_cod then
      raise exception 'delivery is switched off' using errcode = '22023', hint = 'delivery_disabled';
    end if;
    select * into v_addr from public.customer_addresses
    where id = nullif(p ->> 'address_id', '')::uuid and user_id = v_uid;
    if not found then
      raise exception 'address not found' using errcode = '22023', hint = 'address_not_found';
    end if;
    v_name := v_addr.receiver_name;
    v_phone := v_addr.phone;
  else
    if not v_s.allow_pickup then
      raise exception 'pickup is switched off' using errcode = '22023', hint = 'pickup_disabled';
    end if;
    v_name := coalesce(nullif(btrim(p #>> '{receiver,name}'), ''),
                       nullif(btrim(v_user.full_name), ''), nullif(btrim(v_user.display_name), ''), '');
    v_phone := coalesce(nullif(btrim(p #>> '{receiver,phone}'), ''), nullif(btrim(v_user.phone_number), ''), '');
    if v_name = '' then
      raise exception 'receiver name is required' using errcode = '22023', hint = 'receiver_required';
    end if;
    if length(regexp_replace(v_phone, '\D', '', 'g')) not between 8 and 15 then
      raise exception 'invalid phone number' using errcode = '22023', hint = 'invalid_phone';
    end if;
  end if;

  -- ------------------------------------------------------------------- lines
  if jsonb_typeof(p -> 'lines') <> 'array' or jsonb_array_length(p -> 'lines') = 0 then
    raise exception 'the cart is empty' using errcode = '22023', hint = 'cart_empty';
  end if;
  if jsonb_array_length(p -> 'lines') > 30 then
    raise exception 'a cart has 30 lines at most' using errcode = '22023', hint = 'cart_too_big';
  end if;

  -- The same product in the same unit twice is one line.
  for r in
    with input as (
      select nullif(t.x ->> 'product_id', '')::uuid as product_id,
             nullif(t.x ->> 'unit_id', '')::uuid as unit_id,
             coalesce(nullif(t.x ->> 'qty', '')::numeric, 0) as qty,
             t.ord
      from jsonb_array_elements(p -> 'lines') with ordinality as t(x, ord)
    )
    select product_id, unit_id, sum(qty) as qty
    from input
    group by product_id, unit_id
    order by min(ord)
  loop
    v_n := v_n + 1;
    if r.product_id is null or r.qty <> floor(r.qty) or r.qty < 1 or r.qty > 99 then
      raise exception 'invalid quantity on line %', v_n using errcode = '22023', hint = 'invalid_qty';
    end if;

    select pr.id, pr.name, pr.unit as base_unit, pr.track_stock, pr.weight_g, pr.ship_policy,
           coalesce(pr.image_url, (
             select pi.url from public.product_images pi where pi.group_id = pr.group_id
             order by pi.sort_order, pi.created_at, pi.id limit 1), g.image_url) as image_url
    into v_prod
    from public.products pr
    join public.product_groups g on g.id = pr.group_id
    where pr.id = r.product_id and pr.is_active and g.is_active and not g.clinic_only;
    if not found then
      raise exception 'a product is no longer sold' using errcode = '22023', hint = 'product_unavailable';
    end if;

    v_factor := 1;
    if r.unit_id is not null then
      select * into v_unit from public.product_units
      where id = r.unit_id and product_id = r.product_id and is_active and for_sale;
      if not found then
        raise exception '% is no longer sold in this unit', v_prod.name
          using errcode = '22023', hint = 'product_unavailable', detail = v_prod.name;
      end if;
      v_factor := v_unit.factor;
    end if;

    v_price := public.product_unit_price(r.product_id, null, r.unit_id);
    if v_price is null then
      raise exception '% has no price', v_prod.name
        using errcode = '22023', hint = 'product_unavailable', detail = v_prod.name;
    end if;
    if v_method = 'delivery' and v_prod.ship_policy = 'in_store_only' then
      raise exception '% can only be picked up in store', v_prod.name
        using errcode = '22023', hint = 'in_store_only', detail = v_prod.name;
    end if;

    v_subtotal := v_subtotal + v_price * r.qty;
    v_goods_g := v_goods_g + coalesce(v_prod.weight_g, v_s.default_weight_g) * v_factor * r.qty;
    v_ids := v_ids || r.product_id;
    v_lines := v_lines || jsonb_build_object(
      'product_id', r.product_id,
      'unit_id', r.unit_id,
      'unit_factor', v_factor,
      'name', v_prod.name,
      'unit', case when r.unit_id is null then v_prod.base_unit else v_unit.name end,
      'image_url', v_prod.image_url,
      'qty', r.qty,
      'unit_price', v_price,
      'amount', v_price * r.qty,
      'base_qty', r.qty * v_factor,
      'track_stock', v_prod.track_stock
    );
  end loop;

  -- ----------------------------------------------------------------- stock
  -- Orders placed at the same moment check their stock one after another, so the last item
  -- goes to one of them only.
  perform pg_advisory_xact_lock(hashtextextended('shop_order:' || v_s.online_branch_id::text, 0));

  select string_agg(n.name, ', ' order by n.name) into v_missing
  from (
    select (l ->> 'product_id')::uuid as product_id, min(l ->> 'name') as name,
           sum((l ->> 'base_qty')::numeric) as need
    from jsonb_array_elements(v_lines) as t(l)
    where (l ->> 'track_stock')::boolean
    group by 1
  ) n
  left join public.shop_available_qty(v_ids) a on a.product_id = n.product_id
  where n.need > coalesce(a.qty, 0);
  if v_missing is not null then
    raise exception 'not enough stock: %', v_missing using errcode = '22023', hint = 'out_of_stock', detail = v_missing;
  end if;

  -- ------------------------------------------------------- weight and shipping
  v_weight := ceil(v_goods_g)::int + 100;
  if v_method = 'delivery' and v_weight > 30000 then
    raise exception 'parcel is too heavy to deliver' using errcode = '22023', hint = 'too_heavy';
  end if;

  if v_method = 'pickup' or (v_s.free_ship_from is not null and v_subtotal >= v_s.free_ship_from) then
    v_quote := 0;
  else
    -- The browser sends the estimate it showed; it is only an estimate, kept inside a sane range.
    -- Staff fix the real fee when they confirm the order.
    v_quote := least(greatest(round(coalesce(nullif(p ->> 'shipping_fee_quote', '')::numeric, v_s.flat_shipping_fee)), 0), 500000);
  end if;

  if v_method = 'delivery' and v_subtotal + v_quote > v_s.cod_max then
    raise exception 'cash on delivery is limited to % VND', v_s.cod_max using errcode = '22023', hint = 'cod_limit';
  end if;

  -- ----------------------------------------------------- customer to bill
  -- The account's own customer; else the customer with the receiver's phone (billing only, the
  -- account is never linked to someone else's record); else a new customer linked to the account.
  select id into v_customer from public.customers where user_id = v_uid;
  if v_customer is null then
    select id into v_customer from public.customers
    where phone_digits = regexp_replace(v_phone, '\D', '', 'g');
  end if;
  if v_customer is null then
    insert into public.customers (full_name, phone, email, user_id)
    values (coalesce(nullif(btrim(v_user.full_name), ''), v_name), v_phone, v_user.email, v_uid)
    on conflict do nothing
    returning id into v_customer;
    if v_customer is null then
      select id into v_customer from public.customers
      where user_id = v_uid or phone_digits = regexp_replace(v_phone, '\D', '', 'g')
      order by (user_id = v_uid) desc nulls last limit 1;
    end if;
  end if;

  -- ------------------------------------------------------------------ order
  v_code := public.next_doc_code(v_s.online_branch_id, 'DH');
  begin
    insert into public.shop_orders (
      code, branch_id, user_id, customer_id, delivery_method, payment_method,
      receiver_name, receiver_phone, ship_street, ship_ward_name, ship_district_name, ship_province_name,
      ghn_district_id, ghn_ward_code, weight_g, subtotal, shipping_fee_quote, total, customer_note, client_ref
    ) values (
      v_code, v_s.online_branch_id, v_uid, v_customer, v_method,
      case when v_method = 'delivery' then 'cod' else 'pay_at_store' end,
      v_name, v_phone, v_addr.street, v_addr.ward_name, v_addr.district_name, v_addr.province_name,
      v_addr.ghn_district_id, v_addr.ghn_ward_code, v_weight, v_subtotal, v_quote, v_subtotal + v_quote,
      left(nullif(btrim(coalesce(p ->> 'note', '')), ''), 300), v_ref
    )
    returning id into v_id;
  exception when unique_violation then
    -- Two presses of the same button raced; the other one won.
    select * into v_old from public.shop_orders where client_ref = v_ref and user_id = v_uid;
    if not found then
      raise;
    end if;
    return jsonb_build_object('id', v_old.id, 'code', v_old.code, 'total', v_old.total, 'replayed', true);
  end;

  insert into public.shop_order_lines (
    order_id, line_no, product_id, unit_id, unit_factor, name, unit, image_url, qty, unit_price, amount
  )
  select v_id, t.ord, (t.l ->> 'product_id')::uuid, nullif(t.l ->> 'unit_id', '')::uuid,
         (t.l ->> 'unit_factor')::numeric, t.l ->> 'name', t.l ->> 'unit', t.l ->> 'image_url',
         (t.l ->> 'qty')::numeric, (t.l ->> 'unit_price')::numeric, (t.l ->> 'amount')::numeric
  from jsonb_array_elements(v_lines) with ordinality as t(l, ord);

  insert into public.shop_order_events (order_id, status, actor_id, actor_name)
  values (v_id, 'pending', v_uid, 'Khách');

  return jsonb_build_object('id', v_id, 'code', v_code, 'total', v_subtotal + v_quote, 'replayed', false);
end;
$$;


ALTER FUNCTION "public"."place_shop_order"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."post_stock_document"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_doc    public.stock_documents;
  v_line   public.stock_document_lines;
  v_lot    public.stock_lots;
  v_lot_id uuid;
  v_diff   numeric;
  v_total  numeric := 0;
begin
  select * into v_doc from public.stock_documents where id = p_id for update;
  if not found then
    raise exception 'document % not found', p_id using errcode = 'P0002';
  end if;
  if not public.can_inventory(case when v_doc.doc_type = 'receipt' then 'CREATE' else 'UPDATE' end, v_doc.branch_id) then
    raise exception 'not allowed to post this document' using errcode = '42501', hint = 'needs_manager';
  end if;
  if v_doc.status <> 'draft' then
    raise exception 'only a draft can be posted' using errcode = '22023', hint = 'not_draft';
  end if;
  if not exists (select 1 from public.stock_document_lines where document_id = p_id) then
    raise exception 'the document has no lines' using errcode = '22023', hint = 'no_lines';
  end if;

  for v_line in select * from public.stock_document_lines where document_id = p_id order by line_no loop
    if v_doc.doc_type = 'receipt' then
      insert into public.stock_lots as l (branch_id, product_id, lot_no, expiry_date, unit_cost)
      values (v_doc.branch_id, v_line.product_id, v_line.lot_no, v_line.expiry_date, v_line.unit_cost)
      on conflict on constraint stock_lots_identity_key do update set updated_at = now()
      returning id into v_lot_id;

      -- Weighted cost when the lot already holds stock.
      update public.stock_lots
      set unit_cost = round((qty_on_hand * unit_cost + v_line.qty * v_line.unit_cost) / (qty_on_hand + v_line.qty), 2)
      where id = v_lot_id;

      perform public.move_stock(
        v_lot_id, v_line.qty, 'receipt', p_document => p_id, p_document_line => v_line.id,
        p_unit_cost => v_line.unit_cost
      );
      update public.stock_document_lines set lot_id = v_lot_id where id = v_line.id;
      v_total := v_total + round(v_line.qty * v_line.unit_cost, 2);

    elsif v_doc.doc_type = 'writeoff' then
      perform public.move_stock(v_line.lot_id, -v_line.qty, 'writeoff', p_document => p_id, p_document_line => v_line.id);
      select * into v_lot from public.stock_lots where id = v_line.lot_id;
      update public.stock_document_lines set unit_cost = v_lot.unit_cost where id = v_line.id;
      v_total := v_total + round(v_line.qty * v_lot.unit_cost, 2);

    else
      -- The difference is taken against the lot as it stands now, not when the draft was saved.
      select * into v_lot from public.stock_lots where id = v_line.lot_id for update;
      v_diff := v_line.counted_qty - v_lot.qty_on_hand;
      update public.stock_document_lines
      set system_qty = v_lot.qty_on_hand, qty = v_diff, unit_cost = v_lot.unit_cost
      where id = v_line.id;
      if v_diff <> 0 then
        perform public.move_stock(v_line.lot_id, v_diff, 'count', p_document => p_id, p_document_line => v_line.id);
      end if;
      v_total := v_total + round(v_diff * v_lot.unit_cost, 2);
    end if;
  end loop;

  update public.stock_documents
  set status = 'posted',
      posted_by = (select auth.uid()),
      posted_by_name = public.staff_display_name((select auth.uid())),
      posted_at = now(),
      total_cost = v_total
  where id = p_id;
end;
$$;


ALTER FUNCTION "public"."post_stock_document"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."product_categories_check_depth"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  if new.parent_id is null then
    return new;
  end if;
  if exists (select 1 from public.product_categories where id = new.parent_id and parent_id is not null) then
    raise exception 'categories have two levels at most' using errcode = '22023', hint = 'too_deep';
  end if;
  if exists (select 1 from public.product_categories where parent_id = new.id) then
    raise exception 'a category with sub-categories cannot have a parent' using errcode = '22023', hint = 'too_deep';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."product_categories_check_depth"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."product_group_json"("p_group" "uuid", "p_all" boolean) RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  with variants as (
    select * from public.products where group_id = p_group and (p_all or is_active)
  )
  select jsonb_build_object(
    'id', g.id,
    'name', g.name,
    'description', g.description,
    'image_url', g.image_url,
    'is_active', g.is_active,
    'category_id', g.category_id,
    'category_name', (select c.name from public.product_categories c where c.id = g.category_id),
    'category_parent_name', (
      select par.name from public.product_categories c
      join public.product_categories par on par.id = c.parent_id
      where c.id = g.category_id
    ),
    'brand_id', g.brand_id,
    'brand_name', (select b.name from public.product_brands b where b.id = g.brand_id),
    'images', coalesce((
      select jsonb_agg(jsonb_build_object('id', i.id, 'url', i.url, 'storage_path', i.storage_path)
                       order by i.sort_order, i.created_at, i.id)
      from public.product_images i where i.group_id = g.id
    ), '[]'::jsonb),
    'min_price', (select min(price) from variants),
    'max_price', (select max(price) from variants),
    'attributes', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'name', a.name,
        'values', coalesce((
          select jsonb_agg(v.value order by v.sort_order, v.value)
          from public.product_attribute_values v
          where v.attribute_id = a.id
            and exists (
              select 1 from public.product_variant_values pv
              join variants p on p.id = pv.product_id
              where pv.value_id = v.id
            )
        ), '[]'::jsonb)
      ) order by ga.sort_order)
      from public.product_group_attributes ga
      join public.product_attributes a on a.id = ga.attribute_id
      where ga.group_id = g.id
    ), '[]'::jsonb),
    'variants', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'name', p.name,
        'options', coalesce((
          select jsonb_agg(v.value order by ga.sort_order)
          from public.product_group_attributes ga
          join public.product_variant_values pv on pv.attribute_id = ga.attribute_id and pv.product_id = p.id
          join public.product_attribute_values v on v.id = pv.value_id
          where ga.group_id = g.id
        ), '[]'::jsonb),
        'sku', p.sku,
        'barcode', p.barcode,
        'unit', p.unit,
        'price', p.price,
        'track_stock', p.track_stock,
        'is_active', p.is_active,
        'image_url', p.image_url,
        'weight_g', p.weight_g,
        'ship_policy', p.ship_policy,
        'units', coalesce((
          select jsonb_agg(jsonb_build_object(
            'id', u.id,
            'name', u.name,
            'factor', u.factor,
            'barcode', u.barcode,
            'price', u.price,
            'for_sale', u.for_sale,
            'for_purchase', u.for_purchase,
            'is_active', u.is_active
          ) order by u.sort_order, u.name)
          from public.product_units u where u.product_id = p.id
        ), '[]'::jsonb)
      ) order by p.sort_order, p.name)
      from variants p
    ), '[]'::jsonb)
  )
  from public.product_groups g
  where g.id = p_group;
$$;


ALTER FUNCTION "public"."product_group_json"("p_group" "uuid", "p_all" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."product_unit_price"("p_product" "uuid", "p_branch" "uuid" DEFAULT NULL::"uuid", "p_unit" "uuid" DEFAULT NULL::"uuid") RETURNS numeric
    LANGUAGE "sql" STABLE
    SET "search_path" TO ''
    AS $$
  select case
    when p_unit is null then base.price
    when u.id is null then null
    else coalesce(u.price, round(base.price * u.factor, 2))
  end
  from (
    select p.id, coalesce(bp.price, p.price) as price
    from public.products p
    left join public.product_branch_prices bp on bp.product_id = p.id and bp.branch_id = p_branch
    where p.id = p_product
  ) base
  left join public.product_units u on u.id = p_unit and u.product_id = base.id;
$$;


ALTER FUNCTION "public"."product_unit_price"("p_product" "uuid", "p_branch" "uuid", "p_unit" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_appointment_status"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_live   int;
  v_done   int;
  v_busy   int;
  v_billed int;
begin
  select count(*) filter (where status <> 'cancelled'),
         count(*) filter (where status = 'done'),
         count(*) filter (where status = 'in_progress'),
         count(*) filter (where status <> 'cancelled' and invoice_line_id is not null)
  into v_live, v_done, v_busy, v_billed
  from public.appointment_items where appointment_id = p_id;

  update public.appointments set status = case
    when v_live > 0 and v_billed = v_live then 'paid'
    when v_busy > 0 then 'in_progress'
    when v_live > 0 and v_done = v_live then 'done'
    else 'checked_in'
  end
  where id = p_id and status in ('checked_in', 'in_progress', 'done', 'paid');
end;
$$;


ALTER FUNCTION "public"."refresh_appointment_status"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_boarding_stay_status"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_open int;
begin
  select count(*) into v_open from public.boarding_charges where stay_id = p_id and invoice_line_id is null;

  update public.boarding_stays set status = case when v_open = 0 then 'paid' else 'checked_out' end
  where id = p_id and status in ('checked_out', 'paid');
end;
$$;


ALTER FUNCTION "public"."refresh_boarding_stay_status"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_variant_names"("p_group" "uuid") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  update public.products p
  set name = g.name || coalesce(' · ' || (
        select string_agg(v.value, ' / ' order by coalesce(ga.sort_order, 2147483647), v.value)
        from public.product_variant_values pv
        join public.product_attribute_values v on v.id = pv.value_id
        left join public.product_group_attributes ga
          on ga.group_id = p.group_id and ga.attribute_id = pv.attribute_id
        where pv.product_id = p.id
      ), ''),
      description = g.description,
      updated_at = now()
  from public.product_groups g
  where g.id = p_group and p.group_id = g.id;
$$;


ALTER FUNCTION "public"."refresh_variant_names"("p_group" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_pet"("p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_customer uuid;
  v_account uuid := nullif(p #>> '{customer,user_id}', '')::uuid;
  v_pet uuid;
  v_weight numeric := nullif(p ->> 'weight_kg', '')::numeric;
begin
  v_customer := nullif(p #>> '{customer,id}', '')::uuid;

  if v_customer is null and v_account is not null then
    select id into v_customer from public.customers where user_id = v_account;
    if v_customer is null then
      insert into public.customers (full_name, phone, email, user_id)
      select coalesce(nullif(btrim(u.full_name), ''), u.display_name, u.email), u.phone_number, u.email, u.id
      from public.users u
      where u.id = v_account
      on conflict on constraint customers_phone_digits_key
        do update set user_id = coalesce(public.customers.user_id, excluded.user_id), updated_at = now()
      returning id into v_customer;
    end if;
    if v_customer is null then
      raise exception 'account % not found or has no phone number', v_account using errcode = 'P0002';
    end if;
  end if;

  if v_customer is null then
    insert into public.customers (full_name, phone, email)
    values (
      p #>> '{customer,full_name}',
      p #>> '{customer,phone}',
      nullif(p #>> '{customer,email}', '')
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  end if;

  insert into public.pets
    (species_id, name, breed, sex, neutered, birth_date, microchip, photo_url, allergies, behavior_notes)
  values (
    (p #>> '{pet,species_id}')::uuid,
    p #>> '{pet,name}',
    nullif(p #>> '{pet,breed}', ''),
    coalesce(nullif(p #>> '{pet,sex}', ''), 'unknown'),
    coalesce((p #>> '{pet,neutered}')::boolean, false),
    nullif(p #>> '{pet,birth_date}', '')::date,
    nullif(p #>> '{pet,microchip}', ''),
    nullif(p #>> '{pet,photo_url}', ''),
    nullif(p #>> '{pet,allergies}', ''),
    nullif(p #>> '{pet,behavior_notes}', '')
  )
  returning id into v_pet;

  insert into public.pet_owners (pet_id, customer_id, role) values (v_pet, v_customer, 'primary');

  if v_weight is not null then
    insert into public.pet_weight_logs (pet_id, weight_kg) values (v_pet, v_weight);
  end if;

  return v_pet;
end;
$$;


ALTER FUNCTION "public"."register_pet"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_boarding_extra"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_charge public.boarding_charges;
begin
  select * into v_charge from public.boarding_charges where id = p_id;
  if not found or v_charge.kind <> 'extra' then
    raise exception 'extra % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_charge.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_charge.invoice_line_id is not null then
    raise exception 'the extra is already billed' using errcode = 'P0001', hint = 'not_editable';
  end if;
  delete from public.boarding_charges where id = p_id;
end;
$$;


ALTER FUNCTION "public"."remove_boarding_extra"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_medical_attachment"("p_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_row public.medical_attachments;
  v_branch uuid;
begin
  select * into v_row from public.medical_attachments where id = p_id for update;
  if not found then
    raise exception 'file not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select branch_id into v_branch from public.medical_visits where id = v_row.visit_id;
  if not public.can_medical('UPDATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from public.medical_attachments where id = p_id;
  return v_row.file_path;
end;
$$;


ALTER FUNCTION "public"."remove_medical_attachment"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_medical_item"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_item  public.medical_visit_items;
  v_visit public.medical_visits;
begin
  select * into v_item from public.medical_visit_items where id = p_id for update;
  if not found then
    raise exception 'line not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_visit from public.medical_visits where id = v_item.visit_id for update;
  if not public.can_medical('UPDATE', v_item.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.invoice_line_id is not null or v_visit.status not in ('in_progress', 'done', 'paid') then
    raise exception 'the line can no longer be removed' using errcode = 'P0001', hint = 'not_editable';
  end if;
  -- Taking a shot off the bill takes it out of the e-book too (kept, but struck out).
  update public.vaccinations set voided_at = now(), void_reason = 'line removed'
  where visit_item_id = p_id and voided_at is null;
  delete from public.medical_visit_items where id = p_id;
  perform public.medical_refresh_status(v_item.visit_id);
end;
$$;


ALTER FUNCTION "public"."remove_medical_item"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."replace_inpatient_order"("p_id" "uuid", "p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_order public.inpatient_orders;
  v_new   uuid;
begin
  select * into v_order from public.inpatient_orders where id = p_id for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_order.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_order.stopped_at is not null then
    raise exception 'the order is stopped' using errcode = 'P0001', hint = 'order_stopped';
  end if;

  -- The new order goes first: if it is refused, the old one keeps running.
  v_new := public.save_inpatient_order(p || jsonb_build_object('stay_pet_id', v_order.stay_pet_id));
  update public.inpatient_orders set stopped_at = now() where id = p_id;
  delete from public.inpatient_doses
  where order_id = p_id and given_at is null and skipped_reason is null and due_at > now();
  perform public.inpatient_log_change(
    p_id, v_order.visit_id, 'replace', public.inpatient_order_snapshot(v_order),
    jsonb_build_object('new_order_id', v_new), p ->> 'reason'
  );
  return v_new;
end;
$$;


ALTER FUNCTION "public"."replace_inpatient_order"("p_id" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_adjustments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text" DEFAULT 'all'::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("kind" "text", "id" "uuid", "branch_id" "uuid", "code" "text", "invoice_id" "uuid", "invoice_code" "text", "at" timestamp with time zone, "amount" numeric, "method" "text", "reason" "text", "by_name" "text", "item_summary" "text", "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
  v_term     text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if coalesce(p_kind, 'all') not in ('all', 'return', 'cancel') then
    raise exception 'kind must be all, return or cancel' using errcode = '22023';
  end if;

  return query
  with returns_ as (
    select 'return'::text as kind,
           r.id,
           r.branch_id,
           r.code,
           r.invoice_id,
           i.code as invoice_code,
           r.created_at as at,
           r.refund_amount as amount,
           r.refund_method as method,
           r.reason,
           r.created_by_name as by_name,
           (select string_agg(x.name || ' x' || trim_scale(x.qty)::text, ', ' order by x.name)
            from (select l.name, l.qty from public.sales_return_lines l
                  where l.return_id = r.id order by l.name limit 3) x) as item_summary
    from public.sales_returns r
    join public.invoices i on i.id = r.invoice_id
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
  ), cancels as (
    select 'cancel'::text,
           i.id,
           i.branch_id,
           i.code,
           i.id,
           i.code,
           i.cancelled_at,
           i.total,
           null::text,
           i.cancel_reason,
           public.staff_display_name(i.cancelled_by),
           (select string_agg(x.name || ' x' || trim_scale(x.qty)::text, ', ' order by x.name)
            from (select l.name, l.qty from public.invoice_lines l
                  where l.invoice_id = i.id order by l.line_no limit 3) x)
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'cancelled'
      and i.cancelled_at >= lower(v_range) and i.cancelled_at < upper(v_range)
  ), merged as (
    select * from returns_ where coalesce(p_kind, 'all') in ('all', 'return')
    union all
    select * from cancels where coalesce(p_kind, 'all') in ('all', 'cancel')
  )
  select m.kind, m.id, m.branch_id, m.code, m.invoice_id, m.invoice_code, m.at, m.amount, m.method,
         m.reason, m.by_name, m.item_summary, count(*) over ()
  from merged m
  where v_term is null
     or m.code ilike '%' || v_term || '%'
     or m.invoice_code ilike '%' || v_term || '%'
     or m.reason ilike '%' || v_term || '%'
  order by m.at desc
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."report_adjustments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_branch_ids"("p_branch" "uuid") RETURNS "uuid"[]
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_ids uuid[];
begin
  if p_branch is not null then
    if not public.can_report('VIEW', p_branch) then
      raise exception 'not allowed to see reports at this branch' using errcode = '42501';
    end if;
    return array[p_branch];
  end if;

  select coalesce(array_agg(b.id), '{}') into v_ids
  from public.branches b
  where public.can_report('VIEW', b.id);

  if cardinality(v_ids) = 0 then
    raise exception 'not allowed to see reports' using errcode = '42501';
  end if;
  return v_ids;
end;
$$;


ALTER FUNCTION "public"."report_branch_ids"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_limit"("p_limit" integer) RETURNS integer
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select least(greatest(coalesce(p_limit, 20), 1), 5000);
$$;


ALTER FUNCTION "public"."report_limit"("p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_overview"("p_branch" "uuid", "p_from" "date", "p_to" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
  v_days     int := p_to - p_from + 1;
  v_now      jsonb;
  v_prev     jsonb;
begin
  v_now  := public.report_overview_core(v_branches, v_range);
  v_prev := public.report_overview_core(v_branches, public.report_range(p_from - v_days, p_from - 1));

  return v_now || jsonb_build_object(
    'previous', jsonb_build_object(
      'net_revenue',   v_prev -> 'net_revenue',
      'invoice_count', v_prev -> 'invoice_count',
      'avg_ticket',    v_prev -> 'avg_ticket',
      'refunds',       v_prev -> 'refunds'
    )
  );
end;
$$;


ALTER FUNCTION "public"."report_overview"("p_branch" "uuid", "p_from" "date", "p_to" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_overview_core"("p_branches" "uuid"[], "p_range" "tstzrange") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with inv as (
    select id, status, subtotal, discount_amount, total, change_amount
    from public.invoices
    where branch_id = any(p_branches)
      and status = 'paid'
      and created_at >= lower(p_range) and created_at < upper(p_range)
  ), cancelled as (
    select total
    from public.invoices
    where branch_id = any(p_branches)
      and status = 'cancelled'
      and cancelled_at >= lower(p_range) and cancelled_at < upper(p_range)
  ), pay as (
    select p.method, sum(p.amount) as amount
    from public.payments p
    join inv on inv.id = p.invoice_id
    group by p.method
  ), ret as (
    select id, refund_amount, refund_method
    from public.sales_returns
    where branch_id = any(p_branches)
      and created_at >= lower(p_range) and created_at < upper(p_range)
  ), ret_cost as (
    select coalesce(sum(m.qty * m.unit_cost), 0) as cost
    from public.stock_movements m
    join ret on ret.id = m.return_id
    where m.reason = 'return'
  ), lines as (
    select * from public.report_sales_lines(p_branches, lower(p_range), upper(p_range))
  ), t as (
    select
      coalesce((select sum(subtotal) from inv), 0)          as gross,
      coalesce((select sum(discount_amount) from inv), 0)   as discount,
      coalesce((select sum(total) from inv), 0)             as net_sales,
      coalesce((select sum(refund_amount) from ret), 0)     as refunds,
      (select count(*) from inv)                            as invoice_count,
      (select count(*) from cancelled)                      as cancelled_count,
      coalesce((select sum(total) from cancelled), 0)       as cancelled_amount,
      (select count(*) from ret)                            as return_count,
      coalesce((select sum(line_net) from lines where segment = 'shop'), 0) as shop,
      coalesce((select sum(line_net) from lines where segment = 'spa'), 0)  as spa,
      coalesce((select sum(line_net) from lines where segment = 'boarding'), 0) as boarding,
      coalesce((select sum(line_net) from lines where segment = 'medical'), 0) as medical,
      coalesce((select sum(line_net) from lines where segment = 'medical' and item_type = 'product'), 0) as medical_goods,
      coalesce((select sum(line_net) from lines
                where segment = 'spa' and appointment_item_id is not null), 0) as spa_appointment,
      coalesce((select amount from pay where method = 'cash'), 0)
        - coalesce((select sum(change_amount) from inv), 0) as cash,
      coalesce((select amount from pay where method = 'transfer'), 0) as transfer,
      coalesce((select amount from pay where method = 'card'), 0)     as card,
      coalesce((select amount from pay where method = 'cod'), 0)      as cod,
      coalesce((select sum(refund_amount) from ret where refund_method = 'cash'), 0)     as refund_cash,
      coalesce((select sum(refund_amount) from ret where refund_method = 'transfer'), 0) as refund_transfer,
      coalesce((select sum(cost_amount) from lines where segment = 'shop' or (segment = 'medical' and item_type = 'product')), 0) as cost_sold,
      (select cost from ret_cost)                                              as cost_returned,
      (select count(*) from lines where (segment = 'shop' or (segment = 'medical' and item_type = 'product')) and cost_amount is null) as missing_cost_lines
  )
  select jsonb_build_object(
    'gross',         round(gross),
    'discount',      round(discount),
    'net_sales',     round(net_sales),
    'refunds',       round(refunds),
    'net_revenue',   round(net_sales - refunds),
    'invoice_count', invoice_count,
    'avg_ticket',    case when invoice_count = 0 then 0 else round(net_sales / invoice_count) end,
    'cancelled_count',  cancelled_count,
    'cancelled_amount', round(cancelled_amount),
    'return_count',  return_count,
    'segments', jsonb_build_object(
      'shop', round(shop),
      'spa', round(spa),
      'spa_appointment', round(spa_appointment),
      'spa_walk_in', round(spa - spa_appointment),
      'boarding', round(boarding),
      'medical', round(medical)
    ),
    'payments', jsonb_build_object(
      'cash', round(cash),
      'transfer', round(transfer),
      'card', round(card),
      'cod', round(cod),
      'refund_cash', round(refund_cash),
      'refund_transfer', round(refund_transfer)
    ),
    'gross_profit',  round((shop + medical_goods - refunds) - (cost_sold - cost_returned)),
    'missing_cost_lines', missing_cost_lines
  )
  from t;
$$;


ALTER FUNCTION "public"."report_overview_core"("p_branches" "uuid"[], "p_range" "tstzrange") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_range"("p_from" "date", "p_to" "date") RETURNS "tstzrange"
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
begin
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from + 1 > 366 then
    raise exception 'date range is longer than 366 days' using errcode = '22023', hint = 'range_too_long';
  end if;
  return tstzrange(
    p_from::timestamp at time zone 'Asia/Ho_Chi_Minh',
    (p_to + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh',
    '[)');
end;
$$;


ALTER FUNCTION "public"."report_range"("p_from" "date", "p_to" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_revenue_series"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_bucket" "text" DEFAULT 'day'::"text") RETURNS TABLE("bucket" "date", "invoice_count" integer, "gross" numeric, "discount" numeric, "net_sales" numeric, "refunds" numeric, "net_revenue" numeric, "shop" numeric, "spa" numeric, "boarding" numeric, "medical" numeric, "cash" numeric, "transfer" numeric, "card" numeric)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
begin
  if coalesce(p_bucket, 'day') not in ('day', 'week', 'month') then
    raise exception 'bucket must be day, week or month' using errcode = '22023';
  end if;

  return query
  with days as (
    select d::date as day,
           case coalesce(p_bucket, 'day')
             when 'week'  then date_trunc('week', d)::date
             when 'month' then date_trunc('month', d)::date
             else d::date
           end as bkt
    from generate_series(p_from::timestamp, p_to::timestamp, interval '1 day') d
  ), inv as (
    select (i.created_at at time zone 'Asia/Ho_Chi_Minh')::date as day,
           count(*) as n, sum(i.subtotal) as gross, sum(i.discount_amount) as discount,
           sum(i.total) as net_sales, sum(i.change_amount) as change
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.created_at >= lower(v_range) and i.created_at < upper(v_range)
    group by 1
  ), pay as (
    select (i.created_at at time zone 'Asia/Ho_Chi_Minh')::date as day,
           sum(p.amount) filter (where p.method = 'cash') as cash,
           sum(p.amount) filter (where p.method = 'transfer') as transfer,
           sum(p.amount) filter (where p.method = 'card') as card
    from public.invoices i
    join public.payments p on p.invoice_id = i.id
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.created_at >= lower(v_range) and i.created_at < upper(v_range)
    group by 1
  ), ret as (
    select (r.created_at at time zone 'Asia/Ho_Chi_Minh')::date as day, sum(r.refund_amount) as refunds
    from public.sales_returns r
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), seg as (
    select s.biz_date as day,
           sum(s.line_net) filter (where s.segment = 'shop') as shop,
           sum(s.line_net) filter (where s.segment = 'spa') as spa,
           sum(s.line_net) filter (where s.segment = 'boarding') as boarding,
           sum(s.line_net) filter (where s.segment = 'medical') as medical
    from public.report_sales_lines(v_branches, lower(v_range), upper(v_range)) s
    group by 1
  )
  select
    d.bkt,
    coalesce(sum(inv.n), 0)::int,
    coalesce(round(sum(inv.gross)), 0),
    coalesce(round(sum(inv.discount)), 0),
    coalesce(round(sum(inv.net_sales)), 0),
    coalesce(round(sum(ret.refunds)), 0),
    coalesce(round(sum(inv.net_sales)), 0) - coalesce(round(sum(ret.refunds)), 0),
    coalesce(round(sum(seg.shop)), 0),
    coalesce(round(sum(seg.spa)), 0),
    coalesce(round(sum(seg.boarding)), 0),
    coalesce(round(sum(seg.medical)), 0),
    coalesce(round(sum(pay.cash)), 0) - coalesce(round(sum(inv.change)), 0),
    coalesce(round(sum(pay.transfer)), 0),
    coalesce(round(sum(pay.card)), 0)
  from days d
  left join inv on inv.day = d.day
  left join pay on pay.day = d.day
  left join ret on ret.day = d.day
  left join seg on seg.day = d.day
  group by d.bkt
  order by d.bkt;
end;
$$;


ALTER FUNCTION "public"."report_revenue_series"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_bucket" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_sales_lines"("p_branches" "uuid"[], "p_from" timestamp with time zone, "p_to" timestamp with time zone) RETURNS TABLE("invoice_id" "uuid", "branch_id" "uuid", "biz_date" "date", "cashier_id" "uuid", "cashier_name" "text", "line_id" "uuid", "item_type" "text", "product_id" "uuid", "service_id" "uuid", "combo_id" "uuid", "name" "text", "qty" numeric, "amount" numeric, "line_net" numeric, "cost_amount" numeric, "segment" "text", "appointment_item_id" "uuid", "staff_id" "uuid", "pet_id" "uuid")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select
    i.id,
    i.branch_id,
    (i.created_at at time zone 'Asia/Ho_Chi_Minh')::date,
    i.created_by,
    i.cashier_name,
    l.id,
    l.item_type,
    l.product_id,
    l.service_id,
    l.combo_id,
    case when l.item_type = 'boarding' then 'boarding' else l.name end,
    l.base_qty,
    l.amount,
    case when i.subtotal = 0 then 0 else l.amount * i.total / i.subtotal end,
    l.cost_amount,
    case
      when l.item_type = 'boarding' then 'boarding'
      when mi.id is not null then 'medical'
      when l.item_type = 'product' then 'shop'
      else 'spa'
    end,
    ai.id,
    ai.staff_id,
    coalesce(l.pet_id, ai.pet_id)
  from public.invoices i
  join public.invoice_lines l on l.invoice_id = i.id
  left join public.appointment_items ai on ai.invoice_line_id = l.id
  left join public.medical_visit_items mi on mi.invoice_line_id = l.id
  where i.status = 'paid'
    and i.branch_id = any(p_branches)
    and i.created_at >= p_from
    and i.created_at < p_to;
$$;


ALTER FUNCTION "public"."report_sales_lines"("p_branches" "uuid"[], "p_from" timestamp with time zone, "p_to" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_shifts"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text" DEFAULT 'all'::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "code" "text", "branch_code" "text", "status" "text", "opened_by_name" "text", "opened_at" timestamp with time zone, "closed_by_name" "text", "closed_at" timestamp with time zone, "opening_cash" numeric, "invoice_count" bigint, "sales_total" numeric, "cash_in" numeric, "transfer_in" numeric, "card_in" numeric, "refund_cash" numeric, "expected_cash" numeric, "counted_cash" numeric, "difference" numeric, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
  v_term     text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if coalesce(p_status, 'all') not in ('all', 'open', 'closed', 'mismatch') then
    raise exception 'status must be all, open, closed or mismatch' using errcode = '22023';
  end if;

  return query
  with sh as (
    select s.*, b.code as bcode
    from public.cash_shifts s
    join public.branches b on b.id = s.branch_id
    where s.branch_id = any(v_branches)
      and s.opened_at >= lower(v_range) and s.opened_at < upper(v_range)
  ), inv as (
    select i.shift_id,
           count(*) as n,
           sum(i.total) as total,
           sum(i.change_amount) as change
    from public.invoices i
    join sh on sh.id = i.shift_id
    where i.status = 'paid'
    group by 1
  ), pay as (
    select i.shift_id,
           sum(p.amount) filter (where p.method = 'cash') as cash,
           sum(p.amount) filter (where p.method = 'transfer') as transfer,
           sum(p.amount) filter (where p.method = 'card') as card
    from public.invoices i
    join sh on sh.id = i.shift_id
    join public.payments p on p.invoice_id = i.id
    where i.status = 'paid'
    group by 1
  ), ret as (
    select r.shift_id, sum(r.refund_amount) as cash
    from public.sales_returns r
    join sh on sh.id = r.shift_id
    where r.refund_method = 'cash'
    group by 1
  ), calc as (
    select sh.id,
           sh.code,
           sh.bcode,
           sh.status,
           sh.opened_by_name,
           sh.opened_at,
           sh.closed_by_name,
           sh.closed_at,
           sh.opening_cash,
           coalesce(inv.n, 0) as n,
           coalesce(inv.total, 0) as sales,
           coalesce(pay.cash, 0) as cash,
           coalesce(pay.transfer, 0) as transfer,
           coalesce(pay.card, 0) as card,
           coalesce(ret.cash, 0) as refund_cash,
           case when sh.status = 'closed' then sh.expected_cash
                else sh.opening_cash + coalesce(pay.cash, 0) - coalesce(inv.change, 0) - coalesce(ret.cash, 0)
           end as expected,
           sh.counted_cash as counted
    from sh
    left join inv on inv.shift_id = sh.id
    left join pay on pay.shift_id = sh.id
    left join ret on ret.shift_id = sh.id
  )
  select c.id, c.code, c.bcode, c.status, c.opened_by_name, c.opened_at, c.closed_by_name, c.closed_at,
         c.opening_cash, c.n, c.sales, c.cash, c.transfer, c.card, c.refund_cash, c.expected, c.counted,
         case when c.status = 'closed' then c.counted - c.expected end,
         count(*) over ()
  from calc c
  where case coalesce(p_status, 'all')
          when 'open' then c.status = 'open'
          when 'closed' then c.status = 'closed'
          when 'mismatch' then c.status = 'closed' and c.counted is distinct from c.expected
          else true
        end
    and (v_term is null
         or c.code ilike '%' || v_term || '%'
         or c.opened_by_name ilike '%' || v_term || '%')
  order by c.opened_at desc
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."report_shifts"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_staff_revenue"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_role" "text" DEFAULT 'cashier'::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("staff_id" "uuid", "name" "text", "invoice_count" bigint, "ticket_count" bigint, "pet_count" bigint, "net_sales" numeric, "refunds" numeric, "cancelled_count" bigint, "avg_ticket" numeric, "share" numeric, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
  v_term     text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if coalesce(p_role, 'cashier') not in ('cashier', 'spa') then
    raise exception 'role must be cashier or spa' using errcode = '22023';
  end if;

  if coalesce(p_role, 'cashier') = 'spa' then
    return query
    with lines as (
      select * from public.report_sales_lines(v_branches, lower(v_range), upper(v_range))
      where segment = 'spa'
    ), grouped as (
      select l.staff_id as sid,
             count(*) as tickets,
             count(distinct l.pet_id) as pets,
             sum(l.line_net) as net,
             sum(sum(l.line_net)) over () as everyone
      from lines l
      group by 1
    )
    select g.sid,
           public.staff_display_name(g.sid),
           null::bigint,
           g.tickets,
           g.pets,
           round(g.net),
           null::numeric,
           null::bigint,
           null::numeric,
           case when g.everyone = 0 then 0 else round(g.net / g.everyone * 100, 1) end,
           count(*) over ()
    from grouped g
    where v_term is null or public.staff_display_name(g.sid) ilike '%' || v_term || '%'
    order by g.net desc, 2
    limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
    return;
  end if;

  return query
  with sales as (
    select i.created_by as sid, max(i.cashier_name) as cname, count(*) as n, sum(i.total) as net
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'paid'
      and i.created_at >= lower(v_range) and i.created_at < upper(v_range)
    group by 1
  ), ret as (
    select r.created_by as sid, max(r.created_by_name) as cname, sum(r.refund_amount) as amount
    from public.sales_returns r
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), cancelled as (
    select i.created_by as sid, max(i.cashier_name) as cname, count(*) as n
    from public.invoices i
    where i.branch_id = any(v_branches) and i.status = 'cancelled'
      and i.cancelled_at >= lower(v_range) and i.cancelled_at < upper(v_range)
    group by 1
  ), people as (
    select sid from sales union select sid from ret union select sid from cancelled
  ), rows_ as (
    select p.sid,
           coalesce(public.staff_display_name(p.sid), s.cname, r.cname, c.cname) as nm,
           coalesce(s.n, 0) as n,
           coalesce(s.net, 0) as net,
           coalesce(r.amount, 0) as refunds,
           coalesce(c.n, 0) as cancelled
    from people p
    left join sales s on s.sid = p.sid
    left join ret r on r.sid = p.sid
    left join cancelled c on c.sid = p.sid
  )
  select x.sid,
         x.nm,
         x.n,
         null::bigint,
         null::bigint,
         round(x.net),
         round(x.refunds),
         x.cancelled,
         case when x.n = 0 then 0 else round(x.net / x.n) end,
         null::numeric,
         count(*) over ()
  from rows_ x
  where v_term is null or x.nm ilike '%' || v_term || '%'
  order by x.net desc, x.nm
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."report_staff_revenue"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_role" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."report_top_items"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text" DEFAULT 'all'::"text", "p_search" "text" DEFAULT NULL::"text", "p_sort" "text" DEFAULT 'revenue'::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("item_type" "text", "item_id" "uuid", "name" "text", "sku" "text", "unit" "text", "qty_sold" numeric, "qty_returned" numeric, "invoice_count" bigint, "net_revenue" numeric, "refunds" numeric, "cost" numeric, "gross_profit" numeric, "share" numeric, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branches uuid[] := public.report_branch_ids(p_branch);
  v_range    tstzrange := public.report_range(p_from, p_to);
  v_term     text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if coalesce(p_kind, 'all') not in ('all', 'product', 'service') then
    raise exception 'kind must be all, product or service' using errcode = '22023';
  end if;
  if coalesce(p_sort, 'revenue') not in ('revenue', 'qty', 'profit') then
    raise exception 'sort must be revenue, qty or profit' using errcode = '22023';
  end if;

  return query
  with lines as (
    select * from public.report_sales_lines(v_branches, lower(v_range), upper(v_range))
  ), sold as (
    select l.item_type as kind,
           coalesce(l.product_id, l.service_id, l.combo_id) as id,
           sum(l.qty) as qty,
           count(distinct l.invoice_id) as invoices,
           sum(l.line_net) as net,
           sum(l.cost_amount) as cost,
           max(l.name) as line_name
    from lines l
    group by 1, 2
  ), grand as (
    select coalesce(sum(line_net), 0) as total from lines
  ), ret as (
    select rl.product_id as id,
           sum(rl.qty * il.unit_factor) as qty,
           sum(rl.amount) as amount
    from public.sales_returns r
    join public.sales_return_lines rl on rl.return_id = r.id
    join public.invoice_lines il on il.id = rl.invoice_line_id
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), ret_cost as (
    select m.product_id as id, sum(m.qty * m.unit_cost) as cost
    from public.sales_returns r
    join public.stock_movements m on m.return_id = r.id and m.reason = 'return'
    where r.branch_id = any(v_branches)
      and r.created_at >= lower(v_range) and r.created_at < upper(v_range)
    group by 1
  ), merged as (
    select coalesce(s.kind, 'product') as kind,
           coalesce(s.id, r.id) as id,
           coalesce(s.qty, 0) as qty_sold,
           coalesce(r.qty, 0) as qty_returned,
           coalesce(s.invoices, 0) as invoices,
           coalesce(s.net, 0) as net,
           coalesce(r.amount, 0) as refunds,
           s.cost as cost_sold,
           s.line_name,
           coalesce(rc.cost, 0) as cost_returned
    from sold s
    full join ret r on s.kind = 'product' and r.id = s.id
    left join ret_cost rc on rc.id = coalesce(s.id, r.id) and coalesce(s.kind, 'product') = 'product'
  ), named as (
    select m.kind,
           m.id,
           coalesce(p.name, sv.name, cb.name, m.line_name, '') as name,
           p.sku,
           p.barcode,
           coalesce(p.unit, sv.unit) as unit,
           m.qty_sold, m.qty_returned, m.invoices, m.net, m.refunds,
           case when m.kind = 'product' then coalesce(m.cost_sold, 0) - m.cost_returned end as cost,
           case when m.kind = 'product'
                then (m.net - m.refunds) - (coalesce(m.cost_sold, 0) - m.cost_returned)
           end as profit
    from merged m
    left join public.products p on m.kind = 'product' and p.id = m.id
    left join public.pet_services sv on m.kind = 'service' and sv.id = m.id
    left join public.pet_service_combos cb on m.kind = 'combo' and cb.id = m.id
  )
  select n.kind,
         n.id,
         n.name,
         n.sku,
         n.unit,
         n.qty_sold,
         n.qty_returned,
         n.invoices,
         round(n.net),
         round(n.refunds),
         round(n.cost),
         round(n.profit),
         case when g.total = 0 then 0 else round(n.net / g.total * 100, 1) end,
         count(*) over ()
  from named n
  cross join grand g
  where case coalesce(p_kind, 'all')
          when 'product' then n.kind = 'product'
          when 'service' then n.kind in ('service', 'combo')
          else true
        end
    and (v_term is null
         or n.name ilike '%' || v_term || '%'
         or n.sku ilike '%' || v_term || '%'
         or n.barcode = v_term)
  order by
    case coalesce(p_sort, 'revenue') when 'qty' then n.qty_sold when 'profit' then n.profit else n.net end desc nulls last,
    n.name
  limit public.report_limit(p_limit) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."report_top_items"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_sort" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."restore_pet"("p_pet" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."restore_pet"("p_pet" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."return_shop_order"("p_id" "uuid", "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o        public.shop_orders := public.shop_order_for_update(p_id, array['shipping']);
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  if v_reason = '' then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  perform public.shop_order_cancel_invoice(o.invoice_id, v_reason);
  update public.shop_orders set status = 'returned', cancel_reason = v_reason, cancelled_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'returned', v_reason);
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."return_shop_order"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_appointment"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_default_minutes constant int := 30;
  c_late_grace constant interval := interval '15 minutes';
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid        uuid := (select auth.uid());
  v_branch     uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer   uuid := coalesce(nullif(p ->> 'customer_id', '')::uuid, nullif(p #>> '{customer,id}', '')::uuid);
  v_source     text := coalesce(nullif(p ->> 'source', ''), 'counter');
  v_appt       public.appointments;
  v_id         uuid;
  v_code       text;
  v_item       jsonb;
  v_line_no    int := 0;
  v_kind       text;
  v_item_id    uuid;
  v_pet        uuid;
  v_species    uuid;
  v_staff      uuid;
  v_resource   uuid;
  v_start      timestamptz;
  v_end        timestamptz;
  v_local      timestamp;
  v_name       text;
  v_minutes    int;
  v_weight     numeric;
  v_price      numeric;
  v_service    public.pet_services;
  v_combo      public.pet_service_combos;
  v_hours      record;
  v_constraint text;
  v_min_start  timestamptz;
  v_max_end    timestamptz;
  v_cust_name  text;
  v_cust_phone text;
begin
  if p_id is not null then
    select * into v_appt from public.appointments where id = p_id for update;
    if not found then
      raise exception 'appointment % not found', p_id using errcode = 'P0002';
    end if;
    v_branch := v_appt.branch_id;
    if v_appt.status <> 'booked' then
      raise exception 'only a booked appointment can be edited' using errcode = 'P0001', hint = 'not_editable';
    end if;
    if not public.can_schedule('UPDATE', v_branch) then
      raise exception 'not allowed' using errcode = '42501';
    end if;
    -- The customer of an appointment does not change; to change it, cancel and book again.
    v_customer := v_appt.customer_id;
  else
    if v_uid is null or v_branch is null or not public.can_schedule('CREATE', v_branch) then
      raise exception 'not allowed to book at this branch' using errcode = '42501';
    end if;
  end if;

  if v_source not in ('counter', 'phone') then
    v_source := 'counter';
  end if;
  if jsonb_array_length(coalesce(p -> 'items', '[]'::jsonb)) = 0 then
    raise exception 'an appointment needs at least one ticket' using errcode = '22023';
  end if;

  -- The customer: an existing one, or a new walk-in matched by phone (as create_invoice does).
  if v_customer is null and nullif(btrim(p #>> '{customer,phone}'), '') is not null then
    insert into public.customers (full_name, phone, email, created_by)
    values (
      btrim(p #>> '{customer,full_name}'),
      btrim(p #>> '{customer,phone}'),
      nullif(btrim(p #>> '{customer,email}'), ''),
      v_uid
    )
    on conflict on constraint customers_phone_digits_key
      do update set updated_at = now()
    returning id into v_customer;
  end if;
  select full_name, phone into v_cust_name, v_cust_phone from public.customers where id = v_customer;
  if v_customer is null or v_cust_name is null then
    raise exception 'pick a customer' using errcode = 'P0002', hint = 'no_customer';
  end if;

  if p_id is null then
    v_code := public.next_doc_code(v_branch, 'LH');
    insert into public.appointments (
      code, branch_id, customer_id, customer_name, customer_phone,
      start_at, end_at, source, note, created_by
    )
    values (
      v_code, v_branch, v_customer, v_cust_name, v_cust_phone,
      now(), now() + interval '1 minute', v_source, nullif(btrim(p ->> 'note'), ''), v_uid
    )
    returning id into v_id;
  else
    v_id := p_id;
    v_code := v_appt.code;
    -- Free the old slots first so the new tickets do not clash with themselves.
    delete from public.appointment_items where appointment_id = v_id;
  end if;

  for v_item in select * from jsonb_array_elements(p -> 'items') loop
    v_line_no := v_line_no + 1;
    v_kind := v_item ->> 'type';
    v_item_id := nullif(v_item ->> 'id', '')::uuid;
    v_pet := nullif(v_item ->> 'pet_id', '')::uuid;
    v_staff := nullif(v_item ->> 'staff_id', '')::uuid;
    v_resource := nullif(v_item ->> 'resource_id', '')::uuid;
    v_start := nullif(v_item ->> 'start_at', '')::timestamptz;
    v_weight := nullif(v_item ->> 'weight_kg', '')::numeric;
    v_price := null;

    if v_start is null then
      raise exception 'line %: pick a time', v_line_no using errcode = '22023', hint = 'bad_time';
    end if;
    if v_pet is null then
      raise exception 'line %: pick the pet', v_line_no using errcode = '22023', hint = 'no_pet';
    end if;
    if not exists (
      select 1 from public.pet_owners
      where pet_id = v_pet and customer_id = v_customer and to_date is null
    ) then
      raise exception 'line %: the pet does not belong to this customer', v_line_no using errcode = '22023';
    end if;
    if exists (select 1 from public.pets where id = v_pet and status <> 'active') then
      raise exception 'line %: the pet is not active', v_line_no using errcode = '22023',
        hint = case when (select status from public.pets where id = v_pet) = 'deceased' then 'pet_deceased' else 'no_pet' end;
    end if;
    select species_id into v_species from public.pets where id = v_pet;

    if v_kind = 'combo' then
      select * into v_combo from public.pet_service_combos
      where id = v_item_id and status = 1 and is_active;
      if not found then
        raise exception 'line %: combo is not available', v_line_no using errcode = 'P0002';
      end if;
      if exists (select 1 from public.combo_species where combo_id = v_combo.id)
         and not exists (select 1 from public.combo_species where combo_id = v_combo.id and species_id = v_species) then
        raise exception 'line %: the combo is not for this species', v_line_no using errcode = '22023';
      end if;
      v_name := v_combo.name;
      v_minutes := coalesce(nullif(v_combo.duration_minutes, 0), c_default_minutes);
      v_price := v_combo.price;
    elsif v_kind = 'service' then
      select * into v_service from public.pet_services where id = v_item_id and is_active;
      if not found then
        raise exception 'line %: service is not available', v_line_no using errcode = 'P0002';
      end if;
      if exists (select 1 from public.service_species where service_id = v_service.id)
         and not exists (select 1 from public.service_species where service_id = v_service.id and species_id = v_species) then
        raise exception 'line %: the service is not for this species', v_line_no using errcode = '22023';
      end if;
      v_name := v_service.name;
      v_minutes := coalesce(nullif(v_service.duration_minutes, 0), c_default_minutes);
      if v_service.type = 'by_weight' then
        -- Estimated from the weight typed, else the pet's latest weight; the real price is set at check-in.
        v_weight := coalesce(
          v_weight,
          (select weight_kg from public.pet_weight_logs where pet_id = v_pet order by measured_at desc limit 1)
        );
        if v_weight is not null then
          v_price := public.get_service_price(v_species, v_service.id, v_weight, v_branch);
        end if;
      else
        v_price := v_service.general_price;
      end if;
    else
      raise exception 'line %: unknown ticket type', v_line_no using errcode = '22023';
    end if;

    v_end := v_start + make_interval(mins => v_minutes);

    -- Time rules: quarter hours, not in the past, inside opening hours on one day.
    v_local := v_start at time zone c_tz;
    if extract(second from v_local) <> 0 or extract(minute from v_local)::int % 15 <> 0 then
      raise exception 'line %: start on a quarter hour', v_line_no using errcode = 'P0001', hint = 'bad_time';
    end if;
    if v_start < now() - c_late_grace then
      raise exception 'line %: the time is in the past', v_line_no using errcode = 'P0001', hint = 'in_past';
    end if;
    select * into v_hours from public.spa_hours(v_branch, v_local::date);
    if v_hours.is_closed then
      raise exception 'line %: the branch is closed that day', v_line_no using errcode = 'P0001', hint = 'closed';
    end if;
    if v_local::time < v_hours.open_time
       or (v_end at time zone c_tz)::date <> v_local::date
       or (v_end at time zone c_tz)::time > v_hours.close_time then
      raise exception 'line %: outside opening hours', v_line_no using errcode = 'P0001', hint = 'outside_hours';
    end if;

    if v_staff is not null and not exists (
      select 1 from public.staff_branches
      where user_id = v_staff and branch_id = v_branch and does_services
    ) then
      raise exception 'line %: that staff member does not do services at this branch', v_line_no using errcode = '22023';
    end if;
    if v_resource is not null and not exists (
      select 1 from public.spa_resources where id = v_resource and branch_id = v_branch and is_active
    ) then
      raise exception 'line %: that spa table is not available', v_line_no using errcode = '22023';
    end if;

    begin
      insert into public.appointment_items (
        appointment_id, branch_id, line_no, pet_id, item_type, service_id, combo_id, name,
        duration_minutes, staff_id, resource_id, start_at, end_at, est_price, weight_kg
      )
      values (
        v_id, v_branch, v_line_no, v_pet, v_kind,
        case when v_kind = 'service' then v_item_id end,
        case when v_kind = 'combo' then v_item_id end,
        v_name, v_minutes, v_staff, v_resource, v_start, v_end, v_price, v_weight
      );
    exception when exclusion_violation then
      get stacked diagnostics v_constraint = constraint_name;
      raise exception 'line %: already booked at that time', v_line_no
        using errcode = 'P0001',
              hint = case when v_constraint like '%staff%' then 'slot_staff' else 'slot_resource' end,
              detail = v_name;
    end;
  end loop;

  select min(start_at), max(end_at) into v_min_start, v_max_end
  from public.appointment_items where appointment_id = v_id;
  update public.appointments set
    start_at = v_min_start,
    end_at = v_max_end,
    source = v_source,
    note = nullif(btrim(p ->> 'note'), '')
  where id = v_id;

  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;


ALTER FUNCTION "public"."save_appointment"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_boarding_settings"("p_branch" "uuid", "p" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_in time := coalesce(nullif(p ->> 'check_in_from', '')::time, time '08:00');
  v_out time := coalesce(nullif(p ->> 'check_out_by', '')::time, time '12:00');
  v_late time := coalesce(nullif(p ->> 'late_half_until', '')::time, time '18:00');
  v_nights int := coalesce(nullif(p ->> 'max_nights', '')::int, 30);
  v_day numeric := coalesce(nullif(p ->> 'day_stay_nights', '')::numeric, 1);
begin
  if not public.can_boarding('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_out >= v_late or v_nights < 1 or v_nights > 365 or v_day not in (0.5, 1) then
    raise exception 'invalid boarding rules' using errcode = '22023', hint = 'bad_rules';
  end if;
  insert into public.boarding_settings (branch_id, check_in_from, check_out_by, late_half_until, max_nights, day_stay_nights)
  values (p_branch, v_in, v_out, v_late, v_nights, v_day)
  on conflict (branch_id) do update set
    check_in_from = excluded.check_in_from,
    check_out_by = excluded.check_out_by,
    late_half_until = excluded.late_half_until,
    max_nights = excluded.max_nights,
    day_stay_nights = excluded.day_stay_nights;
end;
$$;


ALTER FUNCTION "public"."save_boarding_settings"("p_branch" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_boarding_stay"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select public.boarding_apply_stay(p, p_id, false);
$$;


ALTER FUNCTION "public"."save_boarding_stay"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_branch_hours"("p_branch" "uuid", "p" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_row jsonb;
  v_closed boolean;
  v_open time;
  v_close time;
begin
  if not public.can_schedule('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  for v_row in select * from jsonb_array_elements(coalesce(p, '[]'::jsonb)) loop
    v_closed := coalesce((v_row ->> 'is_closed')::boolean, false);
    v_open := coalesce(nullif(v_row ->> 'open_time', '')::time, time '08:00');
    v_close := coalesce(nullif(v_row ->> 'close_time', '')::time, time '20:00');
    if not v_closed and v_close <= v_open then
      raise exception 'closing time must be after opening time' using errcode = '22023', hint = 'bad_hours';
    end if;
    insert into public.branch_hours (branch_id, weekday, open_time, close_time, is_closed)
    values (p_branch, (v_row ->> 'weekday')::smallint, v_open, v_close, v_closed)
    on conflict (branch_id, weekday) do update
      set open_time = excluded.open_time, close_time = excluded.close_time, is_closed = excluded.is_closed;
  end loop;
end;
$$;


ALTER FUNCTION "public"."save_branch_hours"("p_branch" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_diagnosis_term"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid := p_id;
  v_name text := nullif(btrim(p ->> 'name'), '');
  v_species uuid[];
begin
  if not public.can_medical('SETTING') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and v_name is null then
    raise exception 'name is required' using errcode = '22023', hint = 'bad_input';
  end if;
  if p_id is not null and not exists (select 1 from public.diagnosis_terms where id = p_id) then
    raise exception 'diagnosis % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_name is not null and exists (
    select 1 from public.diagnosis_terms
    where lower(btrim(name)) = lower(v_name) and id is distinct from p_id
  ) then
    raise exception 'a diagnosis with this name exists' using errcode = '23505', hint = 'duplicate_name';
  end if;

  if p ? 'species_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_species
    from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);
  end if;

  if p_id is null then
    insert into public.diagnosis_terms (name, species_ids, is_contagious, is_active, sort_order)
    values (
      v_name,
      coalesce(v_species, '{}'),
      coalesce((p ->> 'is_contagious')::boolean, false),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.diagnosis_terms set
      name = coalesce(v_name, name),
      species_ids = coalesce(v_species, species_ids),
      is_contagious = coalesce((p ->> 'is_contagious')::boolean, is_contagious),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id;
  end if;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_diagnosis_term"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_inpatient_order"("p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  v_uid     uuid := (select auth.uid());
  v_sp      public.boarding_stay_pets;
  v_stay    public.boarding_stays;
  v_kind    text := p ->> 'kind';
  v_name    text := nullif(btrim(p ->> 'name'), '');
  v_product uuid := nullif(p ->> 'product_id', '')::uuid;
  v_service uuid := nullif(p ->> 'service_id', '')::uuid;
  v_start   date := coalesce(nullif(p ->> 'start_on', '')::date, public.business_date());
  v_end     date := coalesce(nullif(p ->> 'end_on', '')::date, coalesce(nullif(p ->> 'start_on', '')::date, public.business_date()));
  v_times   text[];
  v_qty     numeric := coalesce(nullif(p ->> 'qty_per_dose', '')::numeric, 1);
  v_id      uuid;
begin
  select * into v_sp from public.boarding_stay_pets where id = nullif(p ->> 'stay_pet_id', '')::uuid;
  if not found then
    raise exception 'pet of stay not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_stay from public.boarding_stays where id = v_sp.stay_id;
  if v_stay.kind <> 'inpatient' or v_stay.status <> 'checked_in' or v_stay.visit_id is null then
    raise exception 'the pet is not an in-patient' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if not public.can_medical('UPDATE', v_stay.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  select coalesce(array_agg(distinct t order by t), '{}') into v_times
  from jsonb_array_elements_text(coalesce(p -> 'times', '[]'::jsonb)) as x(t);
  if cardinality(v_times) = 0 or exists (select 1 from unnest(v_times) t where t !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') then
    raise exception 'pick the hours' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_end < v_start or v_end > v_start + 30 then
    raise exception 'bad dates' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_kind = 'product' then
    select name into v_name from public.products where id = v_product and is_active;
  elsif v_kind = 'service' then
    select name into v_name from public.pet_services where id = v_service and is_active;
  elsif v_kind <> 'care' then
    raise exception 'unknown kind' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_name is null or v_qty <= 0 then
    raise exception 'name the order' using errcode = '22023', hint = 'bad_input';
  end if;

  insert into public.inpatient_orders (
    stay_pet_id, stay_id, visit_id, branch_id, kind, product_id, service_id, name, dose, qty_per_dose,
    times, start_on, end_on, note, created_by
  ) values (
    v_sp.id, v_stay.id, v_stay.visit_id, v_stay.branch_id, v_kind,
    case when v_kind = 'product' then v_product end, case when v_kind = 'service' then v_service end,
    v_name, nullif(btrim(p ->> 'dose'), ''), v_qty, v_times, v_start, v_end,
    nullif(btrim(p ->> 'note'), ''), v_uid
  ) returning id into v_id;

  insert into public.inpatient_doses (order_id, due_at)
  select v_id, (d::timestamp + t::time) at time zone 'Asia/Ho_Chi_Minh'
  from generate_series(v_start::timestamp, v_end::timestamp, interval '1 day') d
  cross join unnest(v_times) t;

  perform public.inpatient_log_change(v_id, v_stay.visit_id, 'create', null,
    jsonb_build_object('name', v_name, 'dose', nullif(btrim(p ->> 'dose'), ''), 'qty_per_dose', v_qty,
                       'times', to_jsonb(v_times), 'start_on', v_start, 'end_on', v_end,
                       'note', nullif(btrim(p ->> 'note'), '')), null);
  return v_id;
end;
$_$;


ALTER FUNCTION "public"."save_inpatient_order"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_kennel"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_code text := nullif(btrim(p ->> 'code'), '');
  v_type uuid := nullif(p ->> 'kennel_type_id', '')::uuid;
  v_id uuid;
begin
  if p_id is not null then
    select branch_id into v_branch from public.kennels where id = p_id;
    if v_branch is null then
      raise exception 'kennel % not found', p_id using errcode = 'P0002', hint = 'not_found';
    end if;
  end if;
  if v_branch is null or not public.can_boarding('SETTING', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and (v_code is null or v_type is null) then
    raise exception 'code and kennel type are required' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_type is not null and not exists (select 1 from public.kennel_types where id = v_type) then
    raise exception 'kennel type not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_code is not null and exists (
    select 1 from public.kennels
    where branch_id = v_branch and lower(btrim(code)) = lower(v_code) and id is distinct from p_id
  ) then
    raise exception 'a kennel with this code exists at the branch' using errcode = '23505', hint = 'duplicate_code';
  end if;
  if p_id is not null and v_type is not null and exists (
    select 1 from public.kennels where id = p_id and kennel_type_id <> v_type
  ) and exists (
    select 1
    from public.boarding_stay_pets sp
    join public.boarding_stays s on s.id = sp.stay_id
    where sp.kennel_id = p_id and sp.status = 'active' and s.status in ('booked', 'checked_in')
  ) then
    raise exception 'the kennel has stays that are not finished' using errcode = 'P0001', hint = 'kennel_in_use';
  end if;

  if p_id is null then
    insert into public.kennels (branch_id, kennel_type_id, code, name, status, is_active, sort_order)
    values (
      v_branch, v_type, v_code,
      nullif(btrim(p ->> 'name'), ''),
      coalesce(nullif(p ->> 'status', ''), 'ready'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.kennels set
      kennel_type_id = coalesce(v_type, kennel_type_id),
      code = coalesce(v_code, code),
      name = case when p ? 'name' then nullif(btrim(p ->> 'name'), '') else name end,
      status = coalesce(nullif(p ->> 'status', ''), status),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_kennel"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_kennel_type"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid := p_id;
  v_name text := nullif(btrim(p ->> 'name'), '');
  v_species uuid[];
  v_row jsonb;
  v_branch uuid;
  v_kept uuid[] := '{}';
begin
  if not public.can_boarding('SETTING') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and v_name is null then
    raise exception 'name is required' using errcode = '22023', hint = 'bad_input';
  end if;
  if p_id is not null and not exists (select 1 from public.kennel_types where id = p_id) then
    raise exception 'kennel type % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_name is not null and exists (
    select 1 from public.kennel_types
    where lower(btrim(name)) = lower(v_name) and id is distinct from p_id
  ) then
    raise exception 'a kennel type with this name exists' using errcode = '23505', hint = 'duplicate_name';
  end if;

  if p ? 'species_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_species
    from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);
  end if;

  if p_id is null then
    insert into public.kennel_types (
      name, description, photo_url, species_ids, max_weight_kg, max_pets, purpose, is_active, is_public, sort_order
    ) values (
      v_name,
      nullif(btrim(p ->> 'description'), ''),
      nullif(btrim(p ->> 'photo_url'), ''),
      coalesce(v_species, '{}'),
      nullif(p ->> 'max_weight_kg', '')::numeric,
      coalesce(nullif(p ->> 'max_pets', '')::int, 1),
      coalesce(nullif(p ->> 'purpose', ''), 'boarding'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce((p ->> 'is_public')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.kennel_types set
      name = coalesce(v_name, name),
      description = case when p ? 'description' then nullif(btrim(p ->> 'description'), '') else description end,
      photo_url = case when p ? 'photo_url' then nullif(btrim(p ->> 'photo_url'), '') else photo_url end,
      species_ids = coalesce(v_species, species_ids),
      max_weight_kg = case when p ? 'max_weight_kg' then nullif(p ->> 'max_weight_kg', '')::numeric else max_weight_kg end,
      max_pets = coalesce(nullif(p ->> 'max_pets', '')::int, max_pets),
      purpose = coalesce(nullif(p ->> 'purpose', ''), purpose),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      is_public = coalesce((p ->> 'is_public')::boolean, is_public),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id;
  end if;

  -- The shared price is required once; afterwards only changed when sent.
  if p ? 'night_price' then
    if nullif(p ->> 'night_price', '') is null then
      raise exception 'night price is required' using errcode = '22023', hint = 'no_price';
    end if;
    insert into public.kennel_type_prices (kennel_type_id, branch_id, night_price, extra_pet_night_price)
    values (v_id, null, (p ->> 'night_price')::numeric, nullif(p ->> 'extra_pet_night_price', '')::numeric)
    on conflict on constraint kennel_type_prices_key do update
      set night_price = excluded.night_price, extra_pet_night_price = excluded.extra_pet_night_price;
  elsif p_id is null then
    raise exception 'night price is required' using errcode = '22023', hint = 'no_price';
  end if;

  if p ? 'branch_prices' then
    for v_row in select * from jsonb_array_elements(coalesce(p -> 'branch_prices', '[]'::jsonb)) loop
      v_branch := nullif(v_row ->> 'branch_id', '')::uuid;
      if v_branch is null or not public.can_boarding('SETTING', v_branch) then
        raise exception 'not allowed' using errcode = '42501';
      end if;
      if nullif(v_row ->> 'night_price', '') is null then
        raise exception 'night price is required' using errcode = '22023', hint = 'no_price';
      end if;
      insert into public.kennel_type_prices (kennel_type_id, branch_id, night_price, extra_pet_night_price)
      values (v_id, v_branch, (v_row ->> 'night_price')::numeric, nullif(v_row ->> 'extra_pet_night_price', '')::numeric)
      on conflict on constraint kennel_type_prices_key do update
        set night_price = excluded.night_price, extra_pet_night_price = excluded.extra_pet_night_price;
      v_kept := v_kept || v_branch;
    end loop;
    -- A branch left out of the list goes back to the shared price.
    delete from public.kennel_type_prices
    where kennel_type_id = v_id
      and branch_id is not null
      and branch_id <> all (v_kept)
      and public.can_boarding('SETTING', branch_id);
  end if;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_kennel_type"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_medical_record"("p_id" "uuid", "p" "jsonb") RETURNS timestamp with time zone
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid     uuid := (select auth.uid());
  v_visit   public.medical_visits;
  v_weight  numeric;
  v_outcome text;
  v_row     jsonb;
  v_term    public.diagnosis_terms;
  v_name    text;
  v_n       int := 0;
begin
  select * into v_visit from public.medical_visits where id = p_id for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.signed_at is not null then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  if v_visit.status <> 'in_progress' then
    raise exception 'the visit is not in progress' using errcode = 'P0001', hint = 'not_in_progress';
  end if;

  if p ? 'outcome' then
    v_outcome := nullif(p ->> 'outcome', '');
    if v_outcome is not null and v_outcome not in ('home', 'recheck', 'inpatient', 'referred', 'deceased') then
      raise exception 'unknown outcome' using errcode = '22023', hint = 'bad_input';
    end if;
  end if;
  v_weight := case when p ? 'weight_kg' then nullif(p ->> 'weight_kg', '')::numeric else v_visit.weight_kg end;

  update public.medical_visits set
    weight_kg = v_weight,
    temperature_c = case when p ? 'temperature_c' then nullif(p ->> 'temperature_c', '')::numeric else temperature_c end,
    heart_rate = case when p ? 'heart_rate' then nullif(p ->> 'heart_rate', '')::int else heart_rate end,
    resp_rate = case when p ? 'resp_rate' then nullif(p ->> 'resp_rate', '')::int else resp_rate end,
    vitals_note = case when p ? 'vitals_note' then nullif(btrim(p ->> 'vitals_note'), '') else vitals_note end,
    subjective = case when p ? 'subjective' then nullif(btrim(p ->> 'subjective'), '') else subjective end,
    objective = case when p ? 'objective' then nullif(btrim(p ->> 'objective'), '') else objective end,
    assessment = case when p ? 'assessment' then nullif(btrim(p ->> 'assessment'), '') else assessment end,
    plan = case when p ? 'plan' then nullif(btrim(p ->> 'plan'), '') else plan end,
    owner_instructions = case when p ? 'owner_instructions' then nullif(btrim(p ->> 'owner_instructions'), '') else owner_instructions end,
    outcome = case when p ? 'outcome' then v_outcome else outcome end,
    recheck_on = case when p ? 'recheck_on' then nullif(p ->> 'recheck_on', '')::date else recheck_on end
  where id = p_id;

  -- A new weight is also kept on the pet.
  if v_weight is not null and v_weight is distinct from v_visit.weight_kg then
    insert into public.pet_weight_logs (pet_id, weight_kg, note, created_by)
    values (v_visit.pet_id, v_weight, v_visit.code, v_uid);
  end if;

  if p ? 'diagnoses' then
    delete from public.medical_diagnoses where visit_id = p_id;
    for v_row in select * from jsonb_array_elements(coalesce(p -> 'diagnoses', '[]'::jsonb)) loop
      v_term := null;
      if nullif(v_row ->> 'term_id', '') is not null then
        select * into v_term from public.diagnosis_terms where id = (v_row ->> 'term_id')::uuid;
      end if;
      v_name := coalesce(v_term.name, nullif(btrim(v_row ->> 'name'), ''));
      if v_name is null then
        continue;
      end if;
      v_n := v_n + 1;
      insert into public.medical_diagnoses (visit_id, term_id, name, is_contagious, note, sort_order)
      values (
        p_id,
        v_term.id,
        v_name,
        coalesce(v_term.is_contagious, coalesce((v_row ->> 'is_contagious')::boolean, false)),
        nullif(btrim(v_row ->> 'note'), ''),
        v_n
      );
    end loop;
  end if;

  return now();
end;
$$;


ALTER FUNCTION "public"."save_medical_record"("p_id" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_medical_settings"("p_branch" "uuid", "p" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_service uuid := nullif(p ->> 'exam_service_id', '')::uuid;
  v_ahead int := coalesce(nullif(p ->> 'remind_ahead_days', '')::int, 7);
  v_days int := coalesce(nullif(p ->> 'contagious_days', '')::int, 30);
  v_boarding boolean := coalesce((p ->> 'require_vaccine_for_boarding')::boolean, false);
begin
  if not public.can_medical('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_ahead < 0 or v_ahead > 90 or v_days < 1 or v_days > 365 then
    raise exception 'invalid medical rules' using errcode = '22023', hint = 'bad_rules';
  end if;
  -- Only a medical service can be the default exam.
  if v_service is not null and not exists (
    select 1 from public.pet_services where id = v_service and category = 'medical' and is_active
  ) then
    raise exception 'the exam service must be an active medical service' using errcode = '22023', hint = 'bad_rules';
  end if;
  insert into public.medical_settings (branch_id, exam_service_id, remind_ahead_days, contagious_days, require_vaccine_for_boarding)
  values (p_branch, v_service, v_ahead, v_days, v_boarding)
  on conflict (branch_id) do update set
    exam_service_id = excluded.exam_service_id,
    remind_ahead_days = excluded.remind_ahead_days,
    contagious_days = excluded.contagious_days,
    require_vaccine_for_boarding = excluded.require_vaccine_for_boarding;
end;
$$;


ALTER FUNCTION "public"."save_medical_settings"("p_branch" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_my_address"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid     uuid := (select auth.uid());
  v_id      uuid := nullif(p ->> 'id', '')::uuid;
  v_name    text := btrim(coalesce(p ->> 'receiver_name', ''));
  v_phone   text := btrim(coalesce(p ->> 'phone', ''));
  v_street  text := btrim(coalesce(p ->> 'street', ''));
  v_prov    text := btrim(coalesce(p ->> 'province_name', ''));
  v_dist    text := btrim(coalesce(p ->> 'district_name', ''));
  v_ward    text := btrim(coalesce(p ->> 'ward_name', ''));
  v_prov_id int := nullif(p ->> 'ghn_province_id', '')::int;
  v_dist_id int := nullif(p ->> 'ghn_district_id', '')::int;
  v_ward_cd text := btrim(coalesce(p ->> 'ghn_ward_code', ''));
  v_count   int;
  v_default boolean;
  v_row     public.customer_addresses;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  if v_name = '' or v_street = '' then
    raise exception 'receiver and street are required' using errcode = '22023', hint = 'address_required';
  end if;
  if length(regexp_replace(v_phone, '\D', '', 'g')) not between 8 and 15 then
    raise exception 'invalid phone number' using errcode = '22023', hint = 'invalid_phone';
  end if;
  if v_prov = '' or v_dist = '' or v_ward = '' or v_prov_id is null or v_dist_id is null or v_ward_cd = '' then
    raise exception 'choose province, district and ward' using errcode = '22023', hint = 'address_location';
  end if;

  -- One writer at a time per account keeps the 10-address limit and the single default exact.
  perform pg_advisory_xact_lock(hashtextextended('customer_addresses:' || v_uid::text, 0));

  select count(*) into v_count from public.customer_addresses where user_id = v_uid;
  if v_id is null and v_count >= 10 then
    raise exception 'an account keeps 10 addresses at most' using errcode = '22023', hint = 'address_limit';
  end if;

  if v_id is null then
    v_default := coalesce((p ->> 'is_default')::boolean, false) or v_count = 0;
  else
    select is_default into v_default from public.customer_addresses where id = v_id and user_id = v_uid;
    if not found then
      raise exception 'address not found' using errcode = 'P0002', hint = 'address_not_found';
    end if;
    v_default := v_default or coalesce((p ->> 'is_default')::boolean, false);
  end if;

  if v_default then
    update public.customer_addresses set is_default = false
    where user_id = v_uid and is_default and id is distinct from v_id;
  end if;

  if v_id is null then
    insert into public.customer_addresses (
      user_id, receiver_name, phone, street, province_name, district_name, ward_name,
      ghn_province_id, ghn_district_id, ghn_ward_code, is_default
    ) values (
      v_uid, v_name, v_phone, v_street, v_prov, v_dist, v_ward, v_prov_id, v_dist_id, v_ward_cd, v_default
    )
    returning * into v_row;
  else
    update public.customer_addresses
    set receiver_name = v_name, phone = v_phone, street = v_street,
        province_name = v_prov, district_name = v_dist, ward_name = v_ward,
        ghn_province_id = v_prov_id, ghn_district_id = v_dist_id, ghn_ward_code = v_ward_cd,
        is_default = v_default
    where id = v_id and user_id = v_uid
    returning * into v_row;
  end if;

  return public.address_json(v_row);
end;
$$;


ALTER FUNCTION "public"."save_my_address"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_my_profile"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid    uuid := auth.uid();
  v_name   text := btrim(coalesce(p ->> 'full_name', ''));
  v_phone  text := btrim(coalesce(p ->> 'phone', ''));
  v_digits text := regexp_replace(coalesce(p ->> 'phone', ''), '\D', '', 'g');
  v_birth  date;
  v_email  text;
  v_cust   uuid;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if length(v_name) = 0 or length(v_name) > 120 then
    raise exception 'name is required' using errcode = '22023', hint = 'invalid_name';
  end if;
  if length(v_digits) not between 8 and 15 then
    raise exception 'phone must have 8 to 15 digits' using errcode = '22023', hint = 'invalid_phone';
  end if;
  begin
    v_birth := nullif(btrim(coalesce(p ->> 'birth_date', '')), '')::date;
  exception when others then
    raise exception 'birth date is not a date' using errcode = '22023', hint = 'invalid_birth_date';
  end;
  if v_birth is not null and (v_birth > current_date or v_birth < date '1900-01-01') then
    raise exception 'birth date is out of range' using errcode = '22023', hint = 'invalid_birth_date';
  end if;

  select email into v_email from public.users where id = v_uid;
  select id into v_cust from public.customers where user_id = v_uid;

  -- The phone must not belong to another customer record or another account.
  if exists (
    select 1 from public.customers c
    where c.phone_digits = v_digits and c.id is distinct from v_cust
  ) or exists (
    select 1 from public.users u
    where u.phone_number = v_phone and u.id <> v_uid
  ) then
    raise exception 'phone is already used' using errcode = '22023', hint = 'phone_in_use';
  end if;

  begin
    update public.users set full_name = v_name, phone_number = v_phone, updated_at = now() where id = v_uid;
    if v_cust is null then
      insert into public.customers (full_name, phone, email, user_id, birth_date)
      values (v_name, v_phone, v_email, v_uid, v_birth)
      returning id into v_cust;
    else
      update public.customers
         set full_name = v_name, phone = v_phone, birth_date = v_birth, updated_at = now()
       where id = v_cust;
    end if;
  exception when unique_violation then
    raise exception 'phone is already used' using errcode = '22023', hint = 'phone_in_use';
  end;

  return public.my_profile();
end;
$$;


ALTER FUNCTION "public"."save_my_profile"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_pet_combo"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid;
  v_species uuid[];
  v_services uuid[];
  v_missing text;
begin
  select coalesce(array_agg(x::uuid), '{}')
  into v_species
  from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);

  select coalesce(array_agg(x::uuid), '{}')
  into v_services
  from jsonb_array_elements_text(coalesce(p -> 'service_ids', '[]'::jsonb)) as t(x);

  select string_agg(distinct sv.name || ' / ' || sp.name, ', ')
  into v_missing
  from unnest(v_services) as s(service_id)
  cross join unnest(v_species) as k(species_id)
  join public.pet_services sv on sv.id = s.service_id
  join public.species sp on sp.id = k.species_id
  where not exists (
    select 1 from public.service_species ss
    where ss.service_id = s.service_id and ss.species_id = k.species_id
  );

  if v_missing is not null then
    raise exception 'service not offered for species: %', v_missing using errcode = '23514';
  end if;

  if p_id is null then
    insert into public.pet_service_combos
      (name, description, origin_price, price, duration_minutes, mark_as_id,
       mark_start, mark_end, status, is_active)
    values (
      p ->> 'name',
      nullif(p ->> 'description', ''),
      nullif(p ->> 'origin_price', '')::numeric,
      nullif(p ->> 'price', '')::numeric,
      nullif(p ->> 'duration_minutes', '')::int,
      nullif(p ->> 'mark_as_id', ''),
      nullif(p ->> 'mark_start', '')::timestamptz,
      nullif(p ->> 'mark_end', '')::timestamptz,
      coalesce(nullif(p ->> 'status', '')::smallint, 1),
      coalesce((p ->> 'is_active')::boolean, true)
    )
    returning id into v_id;
  else
    update public.pet_service_combos set
      name             = p ->> 'name',
      description      = nullif(p ->> 'description', ''),
      origin_price     = nullif(p ->> 'origin_price', '')::numeric,
      price            = nullif(p ->> 'price', '')::numeric,
      duration_minutes = nullif(p ->> 'duration_minutes', '')::int,
      mark_as_id       = nullif(p ->> 'mark_as_id', ''),
      mark_start       = nullif(p ->> 'mark_start', '')::timestamptz,
      mark_end         = nullif(p ->> 'mark_end', '')::timestamptz,
      status           = coalesce(nullif(p ->> 'status', '')::smallint, 1),
      is_active        = coalesce((p ->> 'is_active')::boolean, true)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'combo % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  delete from public.combo_species where combo_id = v_id;
  insert into public.combo_species (combo_id, species_id)
  select v_id, s from unnest(v_species) as s;

  delete from public.combo_services where combo_id = v_id;
  insert into public.combo_services (combo_id, service_id)
  select v_id, s from unnest(v_services) as s;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_pet_combo"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_pet_service"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid;
  v_species uuid[];
begin
  if p_id is null then
    insert into public.pet_services
      (name, description, type, unit, general_price, duration_minutes, is_show, is_active, category)
    values (
      p ->> 'name',
      nullif(p ->> 'description', ''),
      nullif(p ->> 'type', ''),
      nullif(p ->> 'unit', ''),
      nullif(p ->> 'general_price', '')::numeric,
      nullif(p ->> 'duration_minutes', '')::int,
      coalesce((p ->> 'is_show')::boolean, true),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'category', ''), 'spa')
    )
    returning id into v_id;
  else
    update public.pet_services set
      name             = p ->> 'name',
      description      = nullif(p ->> 'description', ''),
      type             = nullif(p ->> 'type', ''),
      unit             = nullif(p ->> 'unit', ''),
      general_price    = nullif(p ->> 'general_price', '')::numeric,
      duration_minutes = nullif(p ->> 'duration_minutes', '')::int,
      is_show          = coalesce((p ->> 'is_show')::boolean, true),
      is_active        = coalesce((p ->> 'is_active')::boolean, true),
      category         = coalesce(nullif(p ->> 'category', ''), category)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'pet service % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  select coalesce(array_agg(x::uuid), '{}')
  into v_species
  from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);

  delete from public.pet_service_prices
  where service_id = v_id and species_id <> all (v_species);

  delete from public.service_species where service_id = v_id;
  insert into public.service_species (service_id, species_id)
  select v_id, s from unnest(v_species) as s;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_pet_service"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_product_brand"("p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id    uuid := nullif(p ->> 'id', '')::uuid;
  v_name  text := btrim(coalesce(p ->> 'name', ''));
  v_old   public.product_brands;
  v_slug  text;
  v_base  text;
  v_n     int := 1;
begin
  if not public.can_products(case when v_id is null then 'CREATE' else 'UPDATE' end) then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if v_name = '' then
    raise exception 'a brand needs a name' using errcode = '22023', hint = 'name_required';
  end if;
  if exists (
    select 1 from public.product_brands
    where lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_name))
      and id is distinct from v_id
  ) then
    raise exception 'brand % already exists', v_name using errcode = '23505', hint = 'duplicate_name', detail = v_name;
  end if;

  if v_id is not null then
    select * into v_old from public.product_brands where id = v_id;
    if not found then
      raise exception 'brand % not found', v_id using errcode = 'P0002';
    end if;
  end if;

  if v_old.id is null or v_old.name is distinct from v_name then
    v_base := public.slugify(v_name);
    v_slug := v_base;
    while exists (select 1 from public.product_brands where slug = v_slug and id is distinct from v_id) loop
      v_n := v_n + 1;
      v_slug := v_base || '-' || v_n;
    end loop;
  else
    v_slug := v_old.slug;
  end if;

  if v_id is null then
    insert into public.product_brands (name, slug, image_url, is_active)
    values (v_name, v_slug, nullif(btrim(p ->> 'image_url'), ''), coalesce((p ->> 'is_active')::boolean, true))
    returning id into v_id;
  else
    update public.product_brands
    set name = v_name,
        slug = v_slug,
        image_url = nullif(btrim(p ->> 'image_url'), ''),
        is_active = coalesce((p ->> 'is_active')::boolean, is_active)
    where id = v_id;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_product_brand"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_product_category"("p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id      uuid := nullif(p ->> 'id', '')::uuid;
  v_parent  uuid := nullif(p ->> 'parent_id', '')::uuid;
  v_name    text := btrim(coalesce(p ->> 'name', ''));
  v_old     public.product_categories;
  v_slug    text;
  v_base    text;
  v_n       int := 1;
begin
  if not public.can_products(case when v_id is null then 'CREATE' else 'UPDATE' end) then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if v_name = '' then
    raise exception 'a category needs a name' using errcode = '22023', hint = 'name_required';
  end if;
  if v_parent is not null and v_parent = v_id then
    raise exception 'a category cannot be its own parent' using errcode = '22023', hint = 'invalid_parent';
  end if;
  if v_parent is not null and not exists (select 1 from public.product_categories where id = v_parent) then
    raise exception 'parent category not found' using errcode = 'P0002', hint = 'invalid_parent';
  end if;
  if exists (
    select 1 from public.product_categories
    where parent_id is not distinct from v_parent
      and lower(public.immutable_unaccent(btrim(name))) = lower(public.immutable_unaccent(v_name))
      and id is distinct from v_id
  ) then
    raise exception 'category % already exists here', v_name using errcode = '23505', hint = 'duplicate_name', detail = v_name;
  end if;

  if v_id is not null then
    select * into v_old from public.product_categories where id = v_id;
    if not found then
      raise exception 'category % not found', v_id using errcode = 'P0002';
    end if;
  end if;

  -- The slug follows the name; a clash adds -2, -3...
  if v_old.id is null or v_old.name is distinct from v_name then
    v_base := public.slugify(v_name);
    v_slug := v_base;
    while exists (select 1 from public.product_categories where slug = v_slug and id is distinct from v_id) loop
      v_n := v_n + 1;
      v_slug := v_base || '-' || v_n;
    end loop;
  else
    v_slug := v_old.slug;
  end if;

  if v_id is null then
    insert into public.product_categories (parent_id, name, slug, image_url, sort_order, is_active)
    values (
      v_parent, v_name, v_slug, nullif(btrim(p ->> 'image_url'), ''),
      coalesce(
        (p ->> 'sort_order')::int,
        (select coalesce(max(sort_order), 0) + 1 from public.product_categories where parent_id is not distinct from v_parent)
      ),
      coalesce((p ->> 'is_active')::boolean, true)
    )
    returning id into v_id;
  else
    update public.product_categories
    set parent_id = v_parent,
        name = v_name,
        slug = v_slug,
        image_url = nullif(btrim(p ->> 'image_url'), ''),
        sort_order = coalesce((p ->> 'sort_order')::int, sort_order),
        is_active = coalesce((p ->> 'is_active')::boolean, is_active)
    where id = v_id;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_product_category"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_product_group"("p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_group    uuid := nullif(p ->> 'id', '')::uuid;
  v_name     text := btrim(coalesce(p ->> 'name', ''));
  v_active   boolean := coalesce((p ->> 'is_active')::boolean, true);
  v_category uuid := nullif(p ->> 'category_id', '')::uuid;
  v_brand    uuid := nullif(p ->> 'brand_id', '')::uuid;
  -- Gallery: only when "images" is sent; the first one is the cover. A caller that leaves it out
  -- keeps the gallery and sends the cover in p.image_url as before.
  v_has_imgs boolean := jsonb_typeof(p -> 'images') = 'array';
  v_urls     text[] := '{}';
  v_cover    text;
  v_image    text;
  v_attrs    uuid[] := '{}';
  v_attr     uuid;
  v_value    uuid;
  v_text     text;
  v_a        jsonb;
  v_v        jsonb;
  v_idx      int;
  v_keep     uuid[] := '{}';
  v_variant  uuid;
  v_options  jsonb;
  v_values   uuid[];
  v_key      text;
  v_keys     text[] := '{}';
  v_sku      text;
  v_barcode  text;
  v_unit     text;
  v_price    numeric;
  v_weight   int;
  v_policy   text;
  v_sort     int := 0;
  r          record;
begin
  if not public.can_products(case when v_group is null then 'CREATE' else 'UPDATE' end) then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  if v_name = '' then
    raise exception 'a product needs a name' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.product_groups
    where lower(btrim(name)) = lower(v_name) and id is distinct from v_group
  ) then
    raise exception 'product name % is taken', v_name using errcode = '23505', hint = 'duplicate_name';
  end if;
  if jsonb_array_length(coalesce(p -> 'variants', '[]'::jsonb)) = 0 then
    raise exception 'a product needs at least one variant' using errcode = '22023', hint = 'no_variants';
  end if;

  if v_has_imgs then
    select coalesce(array_agg(u order by first_ord), '{}') into v_urls
    from (
      select btrim(x ->> 'url') as u, min(ord) as first_ord
      from jsonb_array_elements(p -> 'images') with ordinality as t(x, ord)
      where nullif(btrim(x ->> 'url'), '') is not null
      group by btrim(x ->> 'url')
    ) d;
    if coalesce(array_length(v_urls, 1), 0) > 8 then
      raise exception 'a product has 8 images at most' using errcode = '22023', hint = 'too_many_images';
    end if;
    v_cover := v_urls[1];
  else
    v_cover := nullif(btrim(p ->> 'image_url'), '');
  end if;

  -- A switched-off category or brand cannot be chosen for a group that does not already use it.
  if v_category is not null and not exists (
    select 1 from public.product_categories c
    where c.id = v_category
      and (c.is_active or exists (select 1 from public.product_groups g where g.id = v_group and g.category_id = c.id))
  ) then
    raise exception 'category is not available' using errcode = '22023', hint = 'invalid_category';
  end if;
  if v_brand is not null and not exists (
    select 1 from public.product_brands b
    where b.id = v_brand
      and (b.is_active or exists (select 1 from public.product_groups g where g.id = v_group and g.brand_id = b.id))
  ) then
    raise exception 'brand is not available' using errcode = '22023', hint = 'invalid_brand';
  end if;

  if v_group is null then
    insert into public.product_groups (name, description, image_url, is_active, category_id, brand_id, created_by)
    values (v_name, nullif(btrim(p ->> 'description'), ''), v_cover,
            v_active, v_category, v_brand, (select auth.uid()))
    returning id into v_group;
  else
    update public.product_groups
    set name = v_name,
        description = nullif(btrim(p ->> 'description'), ''),
        image_url = v_cover,
        is_active = v_active,
        category_id = v_category,
        brand_id = v_brand
    where id = v_group;
    if not found then
      raise exception 'product % not found', v_group using errcode = 'P0002';
    end if;
  end if;

  if v_has_imgs then
    delete from public.product_images where group_id = v_group and not (url = any (v_urls));
    insert into public.product_images (group_id, url, storage_path, sort_order)
    select v_group, u.url, nullif(btrim(i.x ->> 'storage_path'), ''), (u.ord)::int
    from unnest(v_urls) with ordinality as u(url, ord)
    left join lateral (
      select x from jsonb_array_elements(p -> 'images') as t(x) where btrim(x ->> 'url') = u.url limit 1
    ) i on true
    on conflict (group_id, url) do update set sort_order = excluded.sort_order;
  end if;

  -- Attributes, in order; values are created on first use.
  for v_a in select * from jsonb_array_elements(coalesce(p -> 'attributes', '[]'::jsonb)) loop
    v_text := btrim(coalesce(v_a ->> 'name', ''));
    if v_text = '' then
      raise exception 'an attribute needs a name' using errcode = '22023';
    end if;
    select id into v_attr from public.product_attributes where lower(btrim(name)) = lower(v_text);
    if v_attr is null then
      insert into public.product_attributes (name) values (v_text) returning id into v_attr;
    end if;
    if v_attr = any (v_attrs) then
      raise exception 'attribute % is listed twice', v_text using errcode = '22023', hint = 'duplicate_attribute';
    end if;
    v_attrs := v_attrs || v_attr;

    for v_text in select btrim(x) from jsonb_array_elements_text(coalesce(v_a -> 'values', '[]'::jsonb)) as x loop
      continue when v_text = '';
      if not exists (
        select 1 from public.product_attribute_values
        where attribute_id = v_attr and lower(btrim(value)) = lower(v_text)
      ) then
        insert into public.product_attribute_values (attribute_id, value, sort_order)
        select v_attr, v_text, coalesce(max(sort_order), 0) + 1
        from public.product_attribute_values where attribute_id = v_attr;
      end if;
    end loop;
  end loop;

  delete from public.product_group_attributes where group_id = v_group;
  insert into public.product_group_attributes (group_id, attribute_id, sort_order)
  select v_group, a.id, a.ord::int
  from unnest(v_attrs) with ordinality as a(id, ord);

  -- Variants.
  for v_v in select * from jsonb_array_elements(p -> 'variants') loop
    v_sort := v_sort + 1;
    v_variant := nullif(v_v ->> 'id', '')::uuid;
    v_options := coalesce(v_v -> 'options', '[]'::jsonb);
    if jsonb_array_length(v_options) <> coalesce(array_length(v_attrs, 1), 0) then
      raise exception 'variant % needs one value per attribute', v_sort using errcode = '22023', hint = 'variant_options';
    end if;

    v_values := '{}';
    for v_idx in 1 .. coalesce(array_length(v_attrs, 1), 0) loop
      v_text := btrim(coalesce(v_options ->> (v_idx - 1), ''));
      select id into v_value from public.product_attribute_values
      where attribute_id = v_attrs[v_idx] and lower(btrim(value)) = lower(v_text);
      if v_value is null then
        raise exception 'variant %: value "%" is not one of the attribute values', v_sort, v_text
          using errcode = '22023', hint = 'variant_options';
      end if;
      v_values := v_values || v_value;
    end loop;
    v_key := coalesce(array_to_string(v_values, '|'), '');
    if v_key = any (v_keys) then
      raise exception 'two variants have the same values' using errcode = '23505', hint = 'duplicate_variant';
    end if;
    v_keys := v_keys || v_key;

    v_sku := nullif(btrim(v_v ->> 'sku'), '');
    v_barcode := nullif(btrim(v_v ->> 'barcode'), '');
    v_unit := coalesce(nullif(btrim(v_v ->> 'unit'), ''), 'cái');
    v_price := coalesce(nullif(v_v ->> 'price', '')::numeric, 0);
    v_weight := nullif(v_v ->> 'weight_g', '')::int;
    v_policy := coalesce(nullif(btrim(v_v ->> 'ship_policy'), ''), 'shippable');
    if v_weight is not null and v_weight not between 1 and 50000 then
      raise exception 'weight must be 1 to 50000 grams' using errcode = '22023', hint = 'invalid_weight';
    end if;
    if v_policy not in ('shippable', 'in_store_only') then
      raise exception 'invalid shipping policy' using errcode = '22023', hint = 'invalid_ship_policy';
    end if;
    -- A variant shows one of the group's images; anything else falls back to the cover.
    v_image := nullif(btrim(v_v ->> 'image_url'), '');
    if v_has_imgs and v_image is not null and not (v_image = any (v_urls)) then
      v_image := null;
    end if;
    if v_price < 0 then
      raise exception 'price must be zero or more' using errcode = '22023';
    end if;
    if v_sku is not null and exists (
      select 1 from public.products where sku = v_sku and id is distinct from v_variant
    ) then
      raise exception 'SKU % is taken', v_sku using errcode = '23505', hint = 'duplicate_sku', detail = v_sku;
    end if;
    if v_barcode is not null and (
      exists (select 1 from public.products where barcode = v_barcode and id is distinct from v_variant)
      or exists (select 1 from public.product_units where barcode = v_barcode)
    ) then
      raise exception 'barcode % is taken', v_barcode using errcode = '23505', hint = 'duplicate_barcode', detail = v_barcode;
    end if;

    if v_variant is null then
      insert into public.products (
        name, group_id, option_key, sku, barcode, unit, price, track_stock, is_active, image_url, sort_order,
        weight_g, ship_policy
      ) values (
        v_name, v_group, v_key, v_sku, v_barcode, v_unit, v_price,
        coalesce((v_v ->> 'track_stock')::boolean, true),
        v_active and coalesce((v_v ->> 'is_active')::boolean, true),
        v_image, v_sort, v_weight, v_policy
      )
      returning id into v_variant;
    else
      update public.products
      set option_key = v_key,
          sku = v_sku,
          barcode = v_barcode,
          unit = v_unit,
          price = v_price,
          track_stock = coalesce((v_v ->> 'track_stock')::boolean, true),
          is_active = v_active and coalesce((v_v ->> 'is_active')::boolean, true),
          image_url = v_image,
          sort_order = v_sort,
          weight_g = v_weight,
          ship_policy = v_policy,
          updated_at = now()
      where id = v_variant and group_id = v_group;
      if not found then
        raise exception 'variant % does not belong to this product', v_variant using errcode = 'P0002';
      end if;
    end if;

    if jsonb_typeof(v_v -> 'units') = 'array' then
      perform public.save_product_units(v_variant, v_v -> 'units');
    end if;

    delete from public.product_variant_values where product_id = v_variant;
    insert into public.product_variant_values (product_id, attribute_id, value_id)
    select v_variant, a.id, v.id
    from unnest(v_attrs, v_values) as x(attr, val)
    join public.product_attributes a on a.id = x.attr
    join public.product_attribute_values v on v.id = x.val;

    v_keep := v_keep || v_variant;
  end loop;

  -- Variants removed from the list: delete when nothing uses them, else archive.
  for r in select id from public.products where group_id = v_group and not (id = any (v_keep)) loop
    begin
      delete from public.products where id = r.id;
    exception when foreign_key_violation then
      update public.products set is_active = false, updated_at = now() where id = r.id;
    end;
  end loop;

  perform public.refresh_variant_names(v_group);
  return v_group;
end;
$$;


ALTER FUNCTION "public"."save_product_group"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_product_units"("p_product" "uuid", "p_units" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_base    text;
  v_u       jsonb;
  v_id      uuid;
  v_name    text;
  v_factor  numeric;
  v_barcode text;
  v_price   numeric;
  v_sort    int := 0;
  v_keep    uuid[] := '{}';
  v_names   text[] := '{}';
  v_old     public.product_units;
  r         record;
begin
  select unit into v_base from public.products where id = p_product;
  if not found then
    raise exception 'product % not found', p_product using errcode = 'P0002';
  end if;

  for v_u in select * from jsonb_array_elements(coalesce(p_units, '[]'::jsonb)) loop
    v_sort := v_sort + 1;
    v_id := nullif(v_u ->> 'id', '')::uuid;
    v_name := btrim(coalesce(v_u ->> 'name', ''));
    v_factor := nullif(v_u ->> 'factor', '')::numeric;
    v_barcode := nullif(btrim(coalesce(v_u ->> 'barcode', '')), '');
    v_price := nullif(btrim(coalesce(v_u ->> 'price', '')), '')::numeric;

    if v_name = '' then
      raise exception 'a unit needs a name' using errcode = '22023', hint = 'unit_name_required';
    end if;
    if lower(v_name) = lower(btrim(v_base)) or lower(v_name) = any (v_names) then
      raise exception 'unit % is listed twice', v_name using errcode = '23505', hint = 'duplicate_unit', detail = v_name;
    end if;
    v_names := v_names || lower(v_name);
    if v_factor is null or v_factor <= 1 then
      raise exception 'unit % must be worth more than one %', v_name, v_base using errcode = '22023', hint = 'unit_factor', detail = v_name;
    end if;
    if v_price is not null and v_price < 0 then
      raise exception 'price must be zero or more' using errcode = '22023';
    end if;
    if v_barcode is not null and (
      exists (select 1 from public.products where barcode = v_barcode)
      or exists (select 1 from public.product_units where barcode = v_barcode and id is distinct from v_id)
    ) then
      raise exception 'barcode % is taken', v_barcode using errcode = '23505', hint = 'duplicate_barcode', detail = v_barcode;
    end if;

    if v_id is null then
      insert into public.product_units (product_id, name, factor, barcode, price, for_sale, for_purchase, is_active, sort_order)
      values (
        p_product, v_name, v_factor, v_barcode, v_price,
        coalesce((v_u ->> 'for_sale')::boolean, true),
        coalesce((v_u ->> 'for_purchase')::boolean, false),
        coalesce((v_u ->> 'is_active')::boolean, true),
        v_sort
      )
      returning id into v_id;
    else
      select * into v_old from public.product_units where id = v_id and product_id = p_product;
      if not found then
        raise exception 'unit % does not belong to this product', v_id using errcode = 'P0002';
      end if;
      if v_old.factor <> v_factor and (
        exists (select 1 from public.invoice_lines where unit_id = v_id)
        or exists (select 1 from public.stock_document_lines where unit_id = v_id)
      ) then
        raise exception 'unit % is already used, its factor cannot change', v_name
          using errcode = '23503', hint = 'unit_in_use', detail = v_name;
      end if;
      update public.product_units
      set name = v_name,
          factor = v_factor,
          barcode = v_barcode,
          price = v_price,
          for_sale = coalesce((v_u ->> 'for_sale')::boolean, true),
          for_purchase = coalesce((v_u ->> 'for_purchase')::boolean, false),
          is_active = coalesce((v_u ->> 'is_active')::boolean, true),
          sort_order = v_sort
      where id = v_id;
    end if;
    v_keep := v_keep || v_id;
  end loop;

  -- Units left out of the list: deleted when nothing uses them, else switched off.
  for r in select id from public.product_units where product_id = p_product and not (id = any (v_keep)) loop
    begin
      delete from public.product_units where id = r.id;
    exception when foreign_key_violation then
      update public.product_units set is_active = false where id = r.id;
    end;
  end loop;
end;
$$;


ALTER FUNCTION "public"."save_product_units"("p_product" "uuid", "p_units" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_role"("p" "jsonb", "p_id" "text" DEFAULT NULL::"text") RETURNS "text"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_name text;
begin
  if p_id is null then
    insert into public.roles (name, description)
    values (p ->> 'name', nullif(p ->> 'description', ''))
    returning name into v_name;
  else
    if exists (select 1 from public.roles where name = p_id and is_system)
       and p ->> 'name' is distinct from p_id then
      raise exception 'system role % cannot be renamed', p_id using errcode = '42501';
    end if;

    update public.roles
    set name = p ->> 'name', description = nullif(p ->> 'description', '')
    where name = p_id
    returning name into v_name;

    if v_name is null then
      raise exception 'role % not found', p_id using errcode = 'P0002';
    end if;
  end if;

  delete from public.role_permissions where role = v_name;
  insert into public.role_permissions (role, permission, methods)
  select
    v_name,
    e ->> 'id',
    array(select jsonb_array_elements_text(coalesce(e -> 'methods', '[]'::jsonb)))
  from jsonb_array_elements(coalesce(p -> 'permissions', '[]'::jsonb)) as t(e)
  where jsonb_array_length(coalesce(e -> 'methods', '[]'::jsonb)) > 0;

  return v_name;
end;
$$;


ALTER FUNCTION "public"."save_role"("p" "jsonb", "p_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_service_prices"("p_species_id" "uuid", "p_service_id" "uuid", "p_rows" "jsonb", "p_branch_id" "uuid" DEFAULT NULL::"uuid") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_type text;
begin
  select type into v_type from public.pet_services where id = p_service_id;
  if v_type is distinct from 'by_weight' then
    raise exception 'service % is not priced by weight', p_service_id using errcode = '23514';
  end if;

  if not exists (
    select 1 from public.service_species
    where service_id = p_service_id and species_id = p_species_id
  ) then
    raise exception 'service % is not offered for species %', p_service_id, p_species_id
      using errcode = '23514';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_rows) as r(v)
    where nullif(r.v ->> 'price', '') is not null
      and not exists (
        select 1 from public.weight_brackets b
        where b.id = (r.v ->> 'bracket_id')::uuid and b.species_id = p_species_id
      )
  ) then
    raise exception 'bracket does not belong to species %', p_species_id using errcode = '23514';
  end if;

  delete from public.pet_service_prices
  where species_id = p_species_id
    and service_id = p_service_id
    and branch_id is not distinct from p_branch_id
    and bracket_id not in (
      select (r.v ->> 'bracket_id')::uuid
      from jsonb_array_elements(p_rows) as r(v)
      where nullif(r.v ->> 'price', '') is not null
    );

  insert into public.pet_service_prices (species_id, service_id, bracket_id, branch_id, price)
  select p_species_id, p_service_id, (r.v ->> 'bracket_id')::uuid, p_branch_id,
         (r.v ->> 'price')::numeric
  from jsonb_array_elements(p_rows) as r(v)
  where nullif(r.v ->> 'price', '') is not null
  on conflict on constraint pet_service_prices_unique do update set price = excluded.price;
end;
$$;


ALTER FUNCTION "public"."save_service_prices"("p_species_id" "uuid", "p_service_id" "uuid", "p_rows" "jsonb", "p_branch_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_shop_settings"("p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_cur    public.shop_settings;
  v_branch uuid;
  v_cod    numeric;
  v_weight int;
  v_flat   numeric;
  v_free   numeric;
begin
  select * into v_cur from public.shop_settings where id for update;
  if not found then
    raise exception 'shop settings are missing' using errcode = 'P0002';
  end if;
  if not public.can_shop_orders('ALL', v_cur.online_branch_id) then
    raise exception 'not allowed to edit shop settings' using errcode = '42501';
  end if;

  v_branch := coalesce(nullif(p ->> 'online_branch_id', '')::uuid, v_cur.online_branch_id);
  if v_branch is distinct from v_cur.online_branch_id then
    if not exists (select 1 from public.branches where id = v_branch and is_active) then
      raise exception 'branch is not available' using errcode = '22023', hint = 'invalid_branch';
    end if;
    if not public.can_shop_orders('ALL', v_branch) then
      raise exception 'not allowed to sell online from this branch' using errcode = '42501';
    end if;
  end if;

  v_cod    := coalesce(nullif(p ->> 'cod_max', '')::numeric, v_cur.cod_max);
  v_weight := coalesce(nullif(p ->> 'default_weight_g', '')::int, v_cur.default_weight_g);
  v_flat   := coalesce(nullif(p ->> 'flat_shipping_fee', '')::numeric, v_cur.flat_shipping_fee);
  if v_cod <= 0 or v_weight <= 0 or v_flat < 0 then
    raise exception 'invalid shipping or COD limits' using errcode = '22023', hint = 'invalid_limits';
  end if;
  -- An empty or zero threshold switches free shipping off.
  v_free := case
    when p ? 'free_ship_from' then nullif(nullif(p ->> 'free_ship_from', '')::numeric, 0)
    else v_cur.free_ship_from
  end;

  update public.shop_settings s
  set online_branch_id = v_branch,
      allow_cod = coalesce((p ->> 'allow_cod')::boolean, s.allow_cod),
      allow_pickup = coalesce((p ->> 'allow_pickup')::boolean, s.allow_pickup),
      cod_max = v_cod,
      default_weight_g = v_weight,
      flat_shipping_fee = v_flat,
      free_ship_from = v_free,
      ghn_from_province_id = case when p ? 'ghn_from_province_id'
        then nullif(p ->> 'ghn_from_province_id', '')::int else s.ghn_from_province_id end,
      ghn_from_district_id = case when p ? 'ghn_from_district_id'
        then nullif(p ->> 'ghn_from_district_id', '')::int else s.ghn_from_district_id end,
      ghn_from_ward_code = case when p ? 'ghn_from_ward_code'
        then nullif(btrim(p ->> 'ghn_from_ward_code'), '') else s.ghn_from_ward_code end,
      from_address_text = case when p ? 'from_address_text'
        then nullif(btrim(p ->> 'from_address_text'), '') else s.from_address_text end,
      pickup_address = case when p ? 'pickup_address'
        then nullif(btrim(p ->> 'pickup_address'), '') else s.pickup_address end,
      pickup_note = case when p ? 'pickup_note'
        then nullif(btrim(p ->> 'pickup_note'), '') else s.pickup_note end,
      updated_at = now()
  where s.id;

  return public.shop_admin_settings();
end;
$$;


ALTER FUNCTION "public"."save_shop_settings"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_spa_resource"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_id uuid;
begin
  if p_id is not null then
    select branch_id into v_branch from public.spa_resources where id = p_id;
    if v_branch is null then
      raise exception 'spa table % not found', p_id using errcode = 'P0002';
    end if;
  end if;
  if v_branch is null or not public.can_schedule('SETTING', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  if p_id is null then
    insert into public.spa_resources (branch_id, name, is_active, sort_order)
    values (
      v_branch,
      btrim(p ->> 'name'),
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce((p ->> 'sort_order')::int, 0)
    )
    returning id into v_id;
  else
    update public.spa_resources set
      name = coalesce(nullif(btrim(p ->> 'name'), ''), name),
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce((p ->> 'sort_order')::int, sort_order)
    where id = p_id
    returning id into v_id;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_spa_resource"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_species"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid;
begin
  if p_id is null then
    insert into public.species (name, icon, description, is_active)
    values (
      p ->> 'name',
      nullif(p ->> 'icon', ''),
      nullif(p ->> 'description', ''),
      coalesce((p ->> 'is_active')::boolean, true)
    )
    returning id into v_id;
    perform public.seed_default_weight_brackets(v_id);
  else
    update public.species set
      name        = p ->> 'name',
      icon        = nullif(p ->> 'icon', ''),
      description = nullif(p ->> 'description', ''),
      is_active   = coalesce((p ->> 'is_active')::boolean, true)
    where id = p_id
    returning id into v_id;

    if v_id is null then
      raise exception 'species % not found', p_id using errcode = 'P0002';
    end if;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_species"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_staff_branches"("p_user" "uuid", "p" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  delete from public.staff_branches
  where user_id = p_user
    and branch_id not in (
      select (e ->> 'branch_id')::uuid from jsonb_array_elements(coalesce(p, '[]'::jsonb)) as t(e)
    );
  insert into public.staff_branches (user_id, branch_id, role)
  select p_user, (e ->> 'branch_id')::uuid, e ->> 'role'
  from jsonb_array_elements(coalesce(p, '[]'::jsonb)) as t(e)
  on conflict (user_id, branch_id) do update set role = excluded.role;
end;
$$;


ALTER FUNCTION "public"."save_staff_branches"("p_user" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_stock_document"("p" "jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id       uuid := nullif(p ->> 'id', '')::uuid;
  v_doc      public.stock_documents;
  v_branch   uuid;
  v_type     text;
  v_supplier uuid := nullif(p ->> 'supplier_id', '')::uuid;
  v_line     jsonb;
  v_line_no  int := 0;
  v_product  public.products;
  v_lot      public.stock_lots;
  v_qty      numeric;
  v_cost     numeric;
  v_total    numeric := 0;
  v_unit     public.product_units;
  v_factor   numeric;
  v_entered_qty  numeric;
  v_entered_cost numeric;
begin
  if v_id is null then
    v_branch := nullif(p ->> 'branch_id', '')::uuid;
    v_type := p ->> 'doc_type';
    if v_type is null or v_type not in ('receipt', 'writeoff', 'count') then
      raise exception 'unknown document type %', v_type using errcode = '22023';
    end if;
    if (select auth.uid()) is null or v_branch is null or not public.can_inventory('CREATE', v_branch) then
      raise exception 'not allowed to write stock documents at this branch' using errcode = '42501';
    end if;
    insert into public.stock_documents (code, branch_id, doc_type, created_by, created_by_name)
    values (
      public.next_doc_code(v_branch, case v_type when 'receipt' then 'NK' when 'writeoff' then 'XH' else 'KK' end),
      v_branch, v_type, (select auth.uid()), public.staff_display_name((select auth.uid()))
    )
    returning * into v_doc;
  else
    select * into v_doc from public.stock_documents where id = v_id for update;
    if not found then
      raise exception 'document % not found', v_id using errcode = 'P0002';
    end if;
    if not public.can_inventory('CREATE', v_doc.branch_id) then
      raise exception 'not allowed to write stock documents at this branch' using errcode = '42501';
    end if;
    if v_doc.status <> 'draft' then
      raise exception 'only a draft can be edited' using errcode = '22023', hint = 'not_draft';
    end if;
  end if;

  if v_supplier is not null and v_doc.doc_type <> 'receipt' then
    v_supplier := null;
  end if;
  if v_supplier is not null and not exists (select 1 from public.suppliers where id = v_supplier) then
    raise exception 'supplier % not found', v_supplier using errcode = 'P0002';
  end if;

  delete from public.stock_document_lines where document_id = v_doc.id;

  for v_line in select * from jsonb_array_elements(coalesce(p -> 'lines', '[]'::jsonb)) loop
    v_line_no := v_line_no + 1;

    if v_doc.doc_type = 'receipt' then
      select * into v_product from public.products where id = nullif(v_line ->> 'product_id', '')::uuid;
      if not found then
        raise exception 'line %: product not found', v_line_no using errcode = 'P0002';
      end if;
      if not v_product.track_stock then
        raise exception 'line %: % does not track stock', v_line_no, v_product.name
          using errcode = '22023', hint = 'untracked_product', detail = v_product.name;
      end if;
      v_entered_qty := coalesce(nullif(coalesce(v_line ->> 'entered_qty', v_line ->> 'qty'), '')::numeric, 0);
      v_entered_cost := coalesce(nullif(coalesce(v_line ->> 'entered_cost', v_line ->> 'unit_cost'), '')::numeric, 0);
      if v_entered_qty <= 0 or v_entered_cost < 0 then
        raise exception 'line %: quantity must be more than zero and cost zero or more', v_line_no
          using errcode = '22023';
      end if;
      v_unit := null;
      v_factor := 1;
      if nullif(v_line ->> 'unit_id', '') is not null then
        select * into v_unit from public.product_units
        where id = (v_line ->> 'unit_id')::uuid and product_id = v_product.id and is_active;
        if not found then
          raise exception 'line %: the unit is not available', v_line_no using errcode = 'P0002', hint = 'unit_not_available';
        end if;
        v_factor := v_unit.factor;
      end if;
      -- Stock is kept in base units; the line total comes from what was typed so it does not drift.
      v_qty := round(v_entered_qty * v_factor, 2);
      v_cost := round(v_entered_cost / v_factor, 2);
      insert into public.stock_document_lines (
        document_id, line_no, product_id, lot_no, expiry_date, qty, unit_cost, note,
        unit_id, unit_name, unit_factor, entered_qty, entered_cost
      ) values (
        v_doc.id, v_line_no, v_product.id,
        coalesce(btrim(v_line ->> 'lot_no'), ''),
        nullif(v_line ->> 'expiry_date', '')::date,
        v_qty, v_cost, nullif(btrim(v_line ->> 'note'), ''),
        v_unit.id, v_unit.name, v_factor, v_entered_qty, v_entered_cost
      );
      v_total := v_total + round(v_entered_qty * v_entered_cost, 2);
    else
      select * into v_lot from public.stock_lots
      where id = nullif(v_line ->> 'lot_id', '')::uuid and branch_id = v_doc.branch_id;
      if not found then
        raise exception 'line %: lot not found at this branch', v_line_no using errcode = 'P0002';
      end if;
      if exists (
        select 1 from public.stock_document_lines where document_id = v_doc.id and lot_id = v_lot.id
      ) then
        raise exception 'line %: the lot is listed twice', v_line_no using errcode = '22023';
      end if;
      if v_doc.doc_type = 'writeoff' then
        v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
        if v_qty <= 0 then
          raise exception 'line %: quantity must be more than zero', v_line_no using errcode = '22023';
        end if;
        insert into public.stock_document_lines (
          document_id, line_no, product_id, lot_id, lot_no, expiry_date, qty, unit_cost, note
        ) values (
          v_doc.id, v_line_no, v_lot.product_id, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
          v_qty, v_lot.unit_cost, nullif(btrim(v_line ->> 'note'), '')
        );
      else
        v_qty := nullif(v_line ->> 'counted_qty', '')::numeric;
        if v_qty is null or v_qty < 0 then
          raise exception 'line %: counted quantity must be zero or more', v_line_no using errcode = '22023';
        end if;
        insert into public.stock_document_lines (
          document_id, line_no, product_id, lot_id, lot_no, expiry_date, unit_cost, system_qty, counted_qty, note
        ) values (
          v_doc.id, v_line_no, v_lot.product_id, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
          v_lot.unit_cost, v_lot.qty_on_hand, v_qty, nullif(btrim(v_line ->> 'note'), '')
        );
      end if;
    end if;
  end loop;

  update public.stock_documents
  set supplier_id = v_supplier,
      supplier_ref = case when v_doc.doc_type = 'receipt' then nullif(btrim(p ->> 'supplier_ref'), '') end,
      note = nullif(btrim(p ->> 'note'), ''),
      total_cost = v_total
  where id = v_doc.id;

  return v_doc.id;
end;
$$;


ALTER FUNCTION "public"."save_stock_document"("p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_vaccine_type"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_id uuid := p_id;
  v_name text := nullif(btrim(p ->> 'name'), '');
  v_species uuid[];
  v_kind text := nullif(p ->> 'kind', '');
  v_doses int;
  v_gap int;
  v_product uuid;
begin
  if not public.can_medical('SETTING') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_id is null and v_name is null then
    raise exception 'name is required' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_kind is not null and v_kind not in ('vaccine', 'deworm', 'other') then
    raise exception 'unknown kind' using errcode = '22023', hint = 'bad_input';
  end if;
  if p_id is not null and not exists (select 1 from public.vaccine_types where id = p_id) then
    raise exception 'vaccine type % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if v_name is not null and exists (
    select 1 from public.vaccine_types
    where lower(btrim(name)) = lower(v_name) and id is distinct from p_id
  ) then
    raise exception 'a vaccine type with this name exists' using errcode = '23505', hint = 'duplicate_name';
  end if;

  if p ? 'species_ids' then
    select coalesce(array_agg(x::uuid), '{}') into v_species
    from jsonb_array_elements_text(coalesce(p -> 'species_ids', '[]'::jsonb)) as t(x);
  end if;

  if p ? 'product_id' then
    v_product := nullif(p ->> 'product_id', '')::uuid;
    if v_product is not null and not exists (select 1 from public.products where id = v_product) then
      raise exception 'product not found' using errcode = 'P0002', hint = 'bad_input';
    end if;
  end if;

  -- The protocol as it will be stored: the sent value, else the current one.
  v_doses := coalesce(nullif(p ->> 'series_doses', '')::int,
                      (select series_doses from public.vaccine_types where id = p_id), 1);
  v_gap := case when p ? 'series_interval_days' then nullif(p ->> 'series_interval_days', '')::int
                else (select series_interval_days from public.vaccine_types where id = p_id) end;
  if v_doses < 1 or v_doses > 10 or (v_doses > 1 and coalesce(v_gap, 0) < 1) then
    raise exception 'a series of several shots needs the days between them' using errcode = '22023', hint = 'bad_protocol';
  end if;
  if coalesce(nullif(p ->> 'booster_interval_days', '')::int, 1) < 1
     or coalesce(nullif(p ->> 'min_age_weeks', '')::int, 0) < 0 then
    raise exception 'invalid protocol' using errcode = '22023', hint = 'bad_protocol';
  end if;

  if p_id is null then
    insert into public.vaccine_types (
      name, kind, species_ids, product_id, series_doses, series_interval_days,
      booster_interval_days, min_age_weeks, is_active, sort_order
    ) values (
      v_name,
      coalesce(v_kind, 'vaccine'),
      coalesce(v_species, '{}'),
      v_product,
      v_doses,
      v_gap,
      nullif(p ->> 'booster_interval_days', '')::int,
      nullif(p ->> 'min_age_weeks', '')::int,
      coalesce((p ->> 'is_active')::boolean, true),
      coalesce(nullif(p ->> 'sort_order', '')::int, 0)
    ) returning id into v_id;
  else
    update public.vaccine_types set
      name = coalesce(v_name, name),
      kind = coalesce(v_kind, kind),
      species_ids = coalesce(v_species, species_ids),
      product_id = case when p ? 'product_id' then v_product else product_id end,
      series_doses = v_doses,
      series_interval_days = v_gap,
      booster_interval_days = case when p ? 'booster_interval_days'
        then nullif(p ->> 'booster_interval_days', '')::int else booster_interval_days end,
      min_age_weeks = case when p ? 'min_age_weeks'
        then nullif(p ->> 'min_age_weeks', '')::int else min_age_weeks end,
      is_active = coalesce((p ->> 'is_active')::boolean, is_active),
      sort_order = coalesce(nullif(p ->> 'sort_order', '')::int, sort_order)
    where id = p_id;
  end if;

  return v_id;
end;
$$;


ALTER FUNCTION "public"."save_vaccine_type"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."save_weight_brackets"("p_species_id" "uuid", "p_rows" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  delete from public.weight_brackets
  where species_id = p_species_id
    and id not in (
      select (r.v ->> 'id')::uuid
      from jsonb_array_elements(p_rows) as r(v)
      where nullif(r.v ->> 'id', '') is not null
    );

  update public.weight_brackets b set
    label      = r.v ->> 'label',
    min_kg     = (r.v ->> 'min_kg')::numeric,
    max_kg     = nullif(r.v ->> 'max_kg', '')::numeric,
    sort_order = r.ord::int
  from jsonb_array_elements(p_rows) with ordinality as r(v, ord)
  where b.species_id = p_species_id
    and nullif(r.v ->> 'id', '') is not null
    and b.id = (r.v ->> 'id')::uuid;

  insert into public.weight_brackets (species_id, label, min_kg, max_kg, sort_order)
  select p_species_id, r.v ->> 'label', (r.v ->> 'min_kg')::numeric,
         nullif(r.v ->> 'max_kg', '')::numeric, r.ord::int
  from jsonb_array_elements(p_rows) with ordinality as r(v, ord)
  where nullif(r.v ->> 'id', '') is null;
end;
$$;


ALTER FUNCTION "public"."save_weight_brackets"("p_species_id" "uuid", "p_rows" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."schedule_medical_visit"("p" "jsonb", "p_id" "uuid" DEFAULT NULL::"uuid") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid      uuid := (select auth.uid());
  v_visit    public.medical_visits;
  v_branch   uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_customer uuid := nullif(p ->> 'customer_id', '')::uuid;
  v_pet      uuid := nullif(p ->> 'pet_id', '')::uuid;
  v_at       timestamptz := nullif(p ->> 'scheduled_at', '')::timestamptz;
  v_source   text := coalesce(nullif(p ->> 'source', ''), 'phone');
  v_vet      uuid;
  v_names    jsonb;
  v_id       uuid;
begin
  if p_id is not null then
    select * into v_visit from public.medical_visits where id = p_id for update;
    if not found then
      raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
    end if;
    if v_visit.status <> 'scheduled' then
      raise exception 'only a booked visit can be changed' using errcode = 'P0001', hint = 'not_editable';
    end if;
    v_branch := v_visit.branch_id;
    v_customer := v_visit.customer_id;
    v_pet := v_visit.pet_id;
    v_vet := v_visit.vet_id;
  end if;

  if v_branch is null or not public.can_medical('CREATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_customer is null or v_pet is null or v_at is null or v_source not in ('counter', 'phone', 'recheck', 'web') then
    raise exception 'customer, pet and time are required' using errcode = '22023', hint = 'bad_input';
  end if;
  if p ? 'vet_id' then
    v_vet := nullif(p ->> 'vet_id', '')::uuid;
  end if;
  if v_vet is not null and not public.medical_user_can_update(v_vet, v_branch) then
    raise exception 'this person cannot be the vet here' using errcode = '22023', hint = 'bad_vet';
  end if;

  v_names := public.medical_check_pet(v_customer, v_pet);

  if p_id is null then
    insert into public.medical_visits (
      code, branch_id, pet_id, customer_id, pet_name, customer_name, customer_phone, status, scheduled_at,
      reason, vet_id, vet_name, source, created_by
    ) values (
      public.next_doc_code(v_branch, 'KB'), v_branch, v_pet, v_customer, v_names ->> 'pet_name',
      v_names ->> 'customer_name', v_names ->> 'customer_phone', 'scheduled', v_at,
      nullif(btrim(p ->> 'reason'), ''), v_vet,
      case when v_vet is null then null else public.staff_display_name(v_vet) end, v_source, v_uid
    ) returning id into v_id;
  else
    update public.medical_visits set
      scheduled_at = v_at,
      reason = case when p ? 'reason' then nullif(btrim(p ->> 'reason'), '') else reason end,
      vet_id = v_vet,
      vet_name = case when v_vet is null then null else public.staff_display_name(v_vet) end
    where id = p_id;
    v_id := p_id;
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."schedule_medical_visit"("p" "jsonb", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_customers"("p_text" "text", "p_limit" integer DEFAULT 5) RETURNS TABLE("customer_id" "uuid", "user_id" "uuid", "full_name" "text", "phone" "text", "email" "text", "note" "text", "pet_count" bigint)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with q as (
    select
      lower(public.immutable_unaccent(btrim(p_text))) as term,
      regexp_replace(p_text, '\D', '', 'g') as digits
  ),
  pattern as (
    select '%' || replace(replace(replace(term, '\', '\\'), '%', '\%'), '_', '\_') || '%' as like_term,
           term, digits
    from q
  ),
  found as (
    select c.id as customer_id, c.user_id, c.full_name, c.phone, c.email, c.note
    from public.customers c, pattern p
    where c.is_active
      and (
        lower(public.immutable_unaccent(c.full_name || ' ' || coalesce(c.email, ''))) like p.like_term
        or (length(p.digits) >= 3 and c.phone_digits like p.digits || '%')
      )
    union all
    -- Web accounts with a usable phone number that are not customers yet.
    select null::uuid, u.id,
           coalesce(nullif(btrim(u.full_name), ''), u.display_name),
           u.phone_number, u.email, null::text
    from public.users u, pattern p
    where u.phone_number is not null
      and length(regexp_replace(u.phone_number, '\D', '', 'g')) between 8 and 15
      and not exists (select 1 from public.customers c where c.user_id = u.id)
      and not exists (
        select 1 from public.customers c
        where c.phone_digits = regexp_replace(u.phone_number, '\D', '', 'g')
      )
      and (
        lower(public.immutable_unaccent(
          coalesce(u.full_name, '') || ' ' || coalesce(u.display_name, '') || ' ' || coalesce(u.email, '')
        )) like p.like_term
        or (length(p.digits) >= 3 and regexp_replace(u.phone_number, '\D', '', 'g') like p.digits || '%')
      )
  )
  select
    f.customer_id, f.user_id, f.full_name, f.phone, f.email, f.note,
    case when f.customer_id is null then 0::bigint
      else (select count(*) from public.pet_owners po
            where po.customer_id = f.customer_id and po.to_date is null) end
  from found f
  where public.is_staff()
    and (select length(term) from q) >= 2
  order by f.full_name
  limit greatest(1, least(coalesce(p_limit, 5), 20));
$$;


ALTER FUNCTION "public"."search_customers"("p_text" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_unlinked_accounts"("p_text" "text", "p_limit" integer DEFAULT 5) RETURNS TABLE("user_id" "uuid", "full_name" "text", "phone" "text", "email" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with q as (
    select
      lower(public.immutable_unaccent(btrim(coalesce(p_text, '')))) as term,
      regexp_replace(coalesce(p_text, ''), '\D', '', 'g') as digits
  )
  select u.id,
         coalesce(nullif(btrim(u.full_name), ''), u.display_name),
         u.phone_number,
         u.email
  from public.users u, q
  where public.can_link_accounts()
    and length(q.term) >= 2
    and not exists (select 1 from public.customers c where c.user_id = u.id)
    and (
      lower(public.immutable_unaccent(
        coalesce(u.full_name, '') || ' ' || coalesce(u.display_name, '') || ' ' || coalesce(u.email, '')
      )) like '%' || replace(replace(replace(q.term, '\', '\\'), '%', '\%'), '_', '\_') || '%'
      or (length(q.digits) >= 3
          and regexp_replace(coalesce(u.phone_number, ''), '\D', '', 'g') like q.digits || '%')
    )
  order by 2
  limit greatest(1, least(coalesce(p_limit, 5), 20));
$$;


ALTER FUNCTION "public"."search_unlinked_accounts"("p_text" "text", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."seed_default_weight_brackets"("p_species_id" "uuid") RETURNS "void"
    LANGUAGE "sql"
    SET "search_path" TO ''
    AS $$
  insert into public.weight_brackets (species_id, label, min_kg, max_kg, sort_order)
  select p_species_id, v.label, v.min_kg, v.max_kg, v.sort_order
  from (values
    ('Dưới 2 kg', 0, 2, 1), ('2-5 kg', 2, 5, 2), ('5-10 kg', 5, 10, 3),
    ('10-15 kg', 10, 15, 4), ('15-20 kg', 15, 20, 5), ('Trên 20 kg', 20, null::numeric, 6)
  ) as v(label, min_kg, max_kg, sort_order)
  where not exists (select 1 from public.weight_brackets where species_id = p_species_id);
$$;


ALTER FUNCTION "public"."seed_default_weight_brackets"("p_species_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sellable_stock"("p_branch" "uuid", "p_products" "uuid"[]) RETURNS TABLE("product_id" "uuid", "qty" numeric)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not (public.can_pos('CREATE', p_branch) or public.can_inventory('VIEW', p_branch)) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  return query
  select p.id, coalesce(sum(l.qty_on_hand) filter (
           where l.expiry_date is null or l.expiry_date >= public.business_date()), 0)
  from public.products p
  left join public.stock_lots l on l.product_id = p.id and l.branch_id = p_branch and l.qty_on_hand > 0
  where p.id = any(p_products) and p.track_stock
  group by p.id;
end;
$$;


ALTER FUNCTION "public"."sellable_stock"("p_branch" "uuid", "p_products" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_appointment_item_status"("p_item" "uuid", "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
     or v_item.invoice_line_id is not null
     or not ((v_item.status, p_status) in (
       ('waiting', 'in_progress'), ('in_progress', 'done'), ('in_progress', 'waiting'), ('done', 'in_progress')
     )) then
    raise exception 'this ticket cannot change to %', p_status using errcode = 'P0001', hint = 'bad_status';
  end if;

  update public.appointment_items set status = p_status where id = p_item;
  perform public.refresh_appointment_status(v_appt.id);
end;
$$;


ALTER FUNCTION "public"."set_appointment_item_status"("p_item" "uuid", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_default_my_address"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid uuid := (select auth.uid());
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('customer_addresses:' || v_uid::text, 0));
  if not exists (select 1 from public.customer_addresses where id = p_id and user_id = v_uid) then
    raise exception 'address not found' using errcode = 'P0002', hint = 'address_not_found';
  end if;
  update public.customer_addresses set is_default = false where user_id = v_uid and is_default and id <> p_id;
  update public.customer_addresses set is_default = true where id = p_id and user_id = v_uid;
end;
$$;


ALTER FUNCTION "public"."set_default_my_address"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_kennel_status"("p_id" "uuid", "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch uuid;
begin
  if p_status is null or p_status not in ('ready', 'cleaning', 'maintenance') then
    raise exception 'bad status' using errcode = '22023', hint = 'bad_input';
  end if;
  select branch_id into v_branch from public.kennels where id = p_id;
  if v_branch is null then
    raise exception 'kennel % not found', p_id using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_boarding('UPDATE', v_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_status = 'maintenance' and exists (
    select 1
    from public.boarding_stay_pets sp
    join public.boarding_stays s on s.id = sp.stay_id
    where sp.kennel_id = p_id and sp.status = 'active' and s.status = 'checked_in'
  ) then
    raise exception 'a pet is in this kennel' using errcode = 'P0001', hint = 'kennel_occupied';
  end if;
  update public.kennels set status = p_status where id = p_id;
end;
$$;


ALTER FUNCTION "public"."set_kennel_status"("p_id" "uuid", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_min_stock"("p_branch" "uuid", "p_product" "uuid", "p_min" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_inventory('UPDATE', p_branch) then
    raise exception 'not allowed to set minimum stock' using errcode = '42501';
  end if;
  if coalesce(p_min, 0) <= 0 then
    delete from public.stock_thresholds where branch_id = p_branch and product_id = p_product;
  else
    insert into public.stock_thresholds (branch_id, product_id, min_qty)
    values (p_branch, p_product, p_min)
    on conflict (branch_id, product_id) do update set min_qty = excluded.min_qty;
  end if;
end;
$$;


ALTER FUNCTION "public"."set_min_stock"("p_branch" "uuid", "p_product" "uuid", "p_min" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_pet_photo"("p_pet" "uuid", "p_path" "text", "p_url" "text") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_old text;
begin
  if not public.can_edit_pet_photos() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select photo_path into v_old from public.pets where id = p_pet for update;
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if p_path is null then
    if p_url is not null then
      raise exception 'url without a path' using errcode = '22023', hint = 'bad_input';
    end if;
  elsif left(p_path, length(p_pet::text) + 1) <> p_pet::text || '/'
     or p_url is null
     or right(p_url, length('/storage/v1/object/public/pet-photos/' || p_path))
        <> '/storage/v1/object/public/pet-photos/' || p_path then
    raise exception 'the photo does not belong to this pet' using errcode = '22023', hint = 'bad_input';
  end if;
  update public.pets
  set photo_path = p_path, photo_url = p_url, updated_at = now()
  where id = p_pet;
  return v_old;
end;
$$;


ALTER FUNCTION "public"."set_pet_photo"("p_pet" "uuid", "p_path" "text", "p_url" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_product_branch_prices"("p_product" "uuid", "p_prices" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_row     jsonb;
  v_branch  uuid;
  v_price   numeric;
begin
  if jsonb_typeof(coalesce(p_prices, 'null'::jsonb)) <> 'array' then
    raise exception 'prices must be an array' using errcode = '22023';
  end if;
  if not exists (select 1 from public.products where id = p_product) then
    raise exception 'product % not found', p_product using errcode = 'P0002';
  end if;

  for v_row in select * from jsonb_array_elements(p_prices) loop
    v_branch := nullif(v_row ->> 'branch_id', '')::uuid;
    v_price := nullif(btrim(coalesce(v_row ->> 'price', '')), '')::numeric;

    if v_branch is null or not exists (select 1 from public.branches where id = v_branch) then
      raise exception 'branch not found' using errcode = 'P0002';
    end if;
    if not (coalesce((select public.is_admin()), false)
            or coalesce((select public.has_permission('products', 'UPDATE', v_branch)), false)) then
      raise exception 'not allowed to edit prices at this branch' using errcode = '42501';
    end if;
    if v_price is not null and v_price < 0 then
      raise exception 'price cannot be negative' using errcode = '22023', hint = 'price_negative';
    end if;

    if v_price is null then
      delete from public.product_branch_prices where product_id = p_product and branch_id = v_branch;
    else
      insert into public.product_branch_prices (product_id, branch_id, price, updated_by)
      values (p_product, v_branch, v_price, (select auth.uid()))
      on conflict (product_id, branch_id)
      do update set price = excluded.price, updated_by = excluded.updated_by, updated_at = now();
    end if;
  end loop;
end;
$$;


ALTER FUNCTION "public"."set_product_branch_prices"("p_product" "uuid", "p_prices" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_product_group_active"("p_group" "uuid", "p_active" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_products('UPDATE') then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  update public.product_groups set is_active = p_active where id = p_group;
  if not found then
    raise exception 'product % not found', p_group using errcode = 'P0002';
  end if;
  update public.products set is_active = p_active, updated_at = now() where group_id = p_group;
end;
$$;


ALTER FUNCTION "public"."set_product_group_active"("p_group" "uuid", "p_active" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_product_group_clinic_only"("p_group" "uuid", "p_value" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_products('UPDATE') then
    raise exception 'not allowed to edit products' using errcode = '42501';
  end if;
  update public.product_groups set clinic_only = coalesce(p_value, false) where id = p_group;
  if not found then
    raise exception 'product % not found', p_group using errcode = 'P0002';
  end if;
end;
$$;


ALTER FUNCTION "public"."set_product_group_clinic_only"("p_group" "uuid", "p_value" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_staff_does_services"("p_user" "uuid", "p_branch" "uuid", "p_value" boolean) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_schedule('SETTING', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  update public.staff_branches set does_services = p_value
  where user_id = p_user and branch_id = p_branch;
  if not found then
    raise exception 'staff member is not assigned to this branch' using errcode = 'P0002';
  end if;
end;
$$;


ALTER FUNCTION "public"."set_staff_does_services"("p_user" "uuid", "p_branch" "uuid", "p_value" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ship_shop_order"("p_id" "uuid", "p_tracking_code" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o      public.shop_orders := public.shop_order_for_update(p_id, array['packed']);
  v_code text := btrim(coalesce(p_tracking_code, ''));
begin
  if o.delivery_method <> 'delivery' then
    raise exception 'a pickup order is not shipped' using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;
  if v_code = '' or length(v_code) > 40 then
    raise exception 'enter the tracking code' using errcode = '22023', hint = 'tracking_required';
  end if;
  update public.shop_orders
  set status = 'shipping', carrier = 'ghn', tracking_code = v_code, shipped_at = now()
  where id = o.id returning * into o;
  perform public.shop_order_log(o.id, 'shipping', v_code);
  return public.staff_shop_order_json(o);
end;
$$;


ALTER FUNCTION "public"."ship_shop_order"("p_id" "uuid", "p_tracking_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_admin_settings"() RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_row public.shop_settings;
begin
  select * into v_row from public.shop_settings where id;
  if not found then
    return '{}'::jsonb;
  end if;
  if not public.can_shop_orders('VIEW', v_row.online_branch_id) then
    raise exception 'not allowed to see shop settings' using errcode = '42501';
  end if;
  return to_jsonb(v_row);
end;
$$;


ALTER FUNCTION "public"."shop_admin_settings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_available_qty"("p_products" "uuid"[]) RETURNS TABLE("product_id" "uuid", "qty" numeric)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select p.id,
         greatest(0,
           coalesce(sum(l.qty_on_hand) filter (
             where l.expiry_date is null or l.expiry_date >= public.business_date()), 0)
           - coalesce((
               select sum(ol.qty * ol.unit_factor)
               from public.shop_order_lines ol
               join public.shop_orders o on o.id = ol.order_id
               where ol.product_id = p.id
                 and o.branch_id = s.online_branch_id
                 and o.status in ('pending', 'confirmed')
             ), 0))
  from public.products p
  join public.shop_settings s on s.id
  left join public.stock_lots l
    on l.product_id = p.id and l.branch_id = s.online_branch_id and l.qty_on_hand > 0
  where p.id = any(p_products) and p.track_stock
  group by p.id, s.online_branch_id;
$$;


ALTER FUNCTION "public"."shop_available_qty"("p_products" "uuid"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_cart_lines"("p_lines" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_default int;
  v_result  jsonb;
begin
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'lines must be an array' using errcode = '22023', hint = 'invalid_lines';
  end if;
  if jsonb_array_length(p_lines) > 30 then
    raise exception 'a cart has 30 lines at most' using errcode = '22023', hint = 'cart_too_big';
  end if;

  select default_weight_g into v_default from public.shop_settings where id;
  v_default := coalesce(v_default, 500);

  with input as (
    select t.ord,
           nullif(t.x ->> 'product_id', '')::uuid as product_id,
           nullif(t.x ->> 'unit_id', '')::uuid as unit_id,
           least(greatest(coalesce(nullif(t.x ->> 'qty', '')::numeric, 1), 1), 99) as qty
    from jsonb_array_elements(p_lines) with ordinality as t(x, ord)
  ),
  stock as (
    select a.product_id, a.qty
    from public.shop_available_qty(array(select product_id from input where product_id is not null)) a
  ),
  rows as (
    select i.ord, i.product_id, i.unit_id, i.qty,
           p.id as found_id, p.group_id, p.name, p.unit as base_unit, p.is_active as product_active,
           p.track_stock, p.weight_g, p.ship_policy, p.image_url as variant_image,
           (g.is_active and not g.clinic_only) as group_active, g.image_url as group_image,
           u.id as found_unit, u.name as unit_name, u.factor as unit_factor,
           (u.is_active and u.for_sale) as unit_ok,
           (select string_agg(v.value, ' / ' order by ga.sort_order)
            from public.product_group_attributes ga
            join public.product_variant_values pv on pv.attribute_id = ga.attribute_id and pv.product_id = p.id
            join public.product_attribute_values v on v.id = pv.value_id
            where ga.group_id = p.group_id) as variant,
           (select pi.url from public.product_images pi where pi.group_id = p.group_id
            order by pi.sort_order, pi.created_at, pi.id limit 1) as first_image,
           s.qty as stock_qty
    from input i
    left join public.products p on p.id = i.product_id
    left join public.product_groups g on g.id = p.group_id
    left join public.product_units u on u.id = i.unit_id and u.product_id = p.id
    left join stock s on s.product_id = p.id
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'product_id', r.product_id,
      'unit_id', r.unit_id,
      'qty', r.qty,
      'group_id', r.group_id,
      'name', coalesce(r.name, ''),
      'variant', r.variant,
      'image_url', coalesce(r.variant_image, r.first_image, r.group_image),
      'unit_name', case when r.unit_id is null then r.base_unit else r.unit_name end,
      'factor', case when r.unit_id is null then 1 else r.unit_factor end,
      'unit_price', public.product_unit_price(r.product_id, null, r.unit_id),
      'weight_g', coalesce(r.weight_g, v_default) * case when r.unit_id is null then 1 else coalesce(r.unit_factor, 1) end,
      'ship_policy', coalesce(r.ship_policy, 'shippable'),
      'available', case
        when r.found_id is null then 0
        when not r.track_stock then 99
        else least(99, greatest(0, floor(coalesce(r.stock_qty, 0) / case when r.unit_id is null then 1 else coalesce(r.unit_factor, 1) end)))
      end,
      'is_sellable', r.found_id is not null and r.product_active and r.group_active
                     and (r.unit_id is null or coalesce(r.unit_ok, false)),
      'reason', case
        when r.found_id is null then 'not_found'
        when not (r.product_active and r.group_active) then 'inactive'
        when r.unit_id is not null and not coalesce(r.unit_ok, false) then 'unit_inactive'
        else null
      end
    ) order by r.ord
  ), '[]'::jsonb) into v_result
  from rows r;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."shop_cart_lines"("p_lines" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_order_badge"("p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select case
    when public.can_shop_orders('VIEW', b.id) then
      (select count(*)::int from public.shop_orders o where o.branch_id = b.id and o.status = 'pending')
    else 0
  end
  from (select coalesce(p_branch, (select online_branch_id from public.shop_settings where id)) as id) b;
$$;


ALTER FUNCTION "public"."shop_order_badge"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_order_cancel_invoice"("p_invoice" "uuid", "p_reason" "text") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  update public.invoices
  set status = 'cancelled', cancelled_at = now(), cancelled_by = (select auth.uid()), cancel_reason = p_reason
  where id = p_invoice and status <> 'cancelled';
$$;


ALTER FUNCTION "public"."shop_order_cancel_invoice"("p_invoice" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_order_for_update"("p_id" "uuid", "p_from" "text"[]) RETURNS "public"."shop_orders"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  o public.shop_orders;
begin
  select * into o from public.shop_orders where id = p_id for update;
  if not found or not public.can_shop_orders('UPDATE', o.branch_id) then
    raise exception 'order not found' using errcode = 'P0002', hint = 'order_not_found';
  end if;
  if not (o.status = any (p_from)) then
    raise exception 'the order is % now', o.status using errcode = '22023', hint = 'bad_status', detail = o.status;
  end if;
  return o;
end;
$$;


ALTER FUNCTION "public"."shop_order_for_update"("p_id" "uuid", "p_from" "text"[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_order_log"("p_id" "uuid", "p_status" "text", "p_note" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  insert into public.shop_order_events (order_id, status, note, actor_id, actor_name)
  values (p_id, p_status, nullif(btrim(p_note), ''), (select auth.uid()), public.staff_display_name((select auth.uid())));
$$;


ALTER FUNCTION "public"."shop_order_log"("p_id" "uuid", "p_status" "text", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_product_groups"("p_search" "text" DEFAULT NULL::"text", "p_category" "uuid" DEFAULT NULL::"uuid", "p_brand" "uuid" DEFAULT NULL::"uuid", "p_sort" "text" DEFAULT 'newest'::"text", "p_limit" integer DEFAULT 24, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with params as (
    select lower(public.immutable_unaccent(nullif(btrim(coalesce(p_search, '')), ''))) as term,
           nullif(btrim(coalesce(p_search, '')), '') as code
  ), candidates as (
    select g.id, g.name, g.created_at
    from public.product_groups g, params
    where g.is_active and not g.clinic_only
      and (p_brand is null or g.brand_id = p_brand)
      and (
        p_category is null
        or g.category_id = p_category
        or g.category_id in (select id from public.product_categories where parent_id = p_category)
      )
      and (
        params.term is null
        or lower(public.immutable_unaccent(g.name)) like '%' || params.term || '%'
        or exists (
          select 1 from public.products p
          where p.group_id = g.id
            and (p.sku ilike '%' || params.code || '%' or p.barcode ilike '%' || params.code || '%')
        )
      )
  ), variants as (
    select p.id, p.group_id, p.price, p.track_stock
    from public.products p
    where p.is_active and p.group_id in (select id from candidates)
  ), stock as (
    select s.product_id, s.qty
    from public.shop_available_qty(array(select id from variants)) s
  ), matched as (
    select c.id, c.name, c.created_at,
           min(v.price) as price_min,
           bool_or(not v.track_stock or coalesce(s.qty, 0) > 0) as in_stock
    from candidates c
    join variants v on v.group_id = c.id
    left join stock s on s.product_id = v.id
    group by c.id, c.name, c.created_at
  ), ordered as (
    select m.*,
           row_number() over (
             order by
               case when p_sort = 'newest' and not m.in_stock then 1 else 0 end,
               case when p_sort = 'price_asc' then m.price_min end asc,
               case when p_sort = 'price_desc' then m.price_min end desc,
               case when p_sort = 'name' then lower(m.name) end asc,
               m.created_at desc,
               m.id
           ) as rn
    from matched m
  ), page as (
    select * from ordered
    where rn > greatest(p_offset, 0) and rn <= greatest(p_offset, 0) + greatest(p_limit, 1)
  )
  select jsonb_build_object(
    'total', (select count(*) from matched),
    'rows', coalesce((
      select jsonb_agg(
        public.product_group_json(page.id, false) || jsonb_build_object('in_stock', page.in_stock)
        order by page.rn
      )
      from page
    ), '[]'::jsonb)
  );
$$;


ALTER FUNCTION "public"."shop_product_groups"("p_search" "text", "p_category" "uuid", "p_brand" "uuid", "p_sort" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_public_settings"() RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce((
    select jsonb_build_object(
      'online_branch_id', s.online_branch_id,
      'allow_cod', s.allow_cod,
      'allow_pickup', s.allow_pickup,
      'cod_max', s.cod_max,
      'default_weight_g', s.default_weight_g,
      'flat_shipping_fee', s.flat_shipping_fee,
      'free_ship_from', s.free_ship_from,
      'ghn_from_district_id', s.ghn_from_district_id,
      'ghn_from_ward_code', s.ghn_from_ward_code,
      'pickup_address', s.pickup_address,
      'pickup_note', s.pickup_note
    )
    from public.shop_settings s
    where s.id
  ), '{}'::jsonb);
$$;


ALTER FUNCTION "public"."shop_public_settings"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."shop_related_groups"("p_group" "uuid", "p_limit" integer DEFAULT 8) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with source as (
    select category_id from public.product_groups where id = p_group
  ), picked as (
    select g.id, g.created_at
    from public.product_groups g, source
    where g.is_active and not g.clinic_only
      and g.id <> p_group
      and source.category_id is not null
      and g.category_id = source.category_id
      and exists (select 1 from public.products p where p.group_id = g.id and p.is_active)
    order by g.created_at desc, g.id
    limit greatest(least(coalesce(p_limit, 8), 24), 1)
  ), stock as (
    select s.product_id, s.qty
    from public.shop_available_qty(
      array(select p.id from public.products p where p.is_active and p.group_id in (select id from picked))
    ) s
  )
  select coalesce(jsonb_agg(
    public.product_group_json(pk.id, false) || jsonb_build_object('in_stock', coalesce((
      select bool_or(not p.track_stock or coalesce(s.qty, 0) > 0)
      from public.products p
      left join stock s on s.product_id = p.id
      where p.group_id = pk.id and p.is_active
    ), false))
    order by pk.created_at desc, pk.id
  ), '[]'::jsonb)
  from picked pk;
$$;


ALTER FUNCTION "public"."shop_related_groups"("p_group" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sign_medical_visit"("p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid     uuid := (select auth.uid());
  v_visit   public.medical_visits;
  v_child   uuid;
  v_today   date := public.business_date();
begin
  select * into v_visit from public.medical_visits where id = p_id for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.signed_at is not null then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  if v_visit.status <> 'in_progress' then
    raise exception 'the visit is not in progress' using errcode = 'P0001', hint = 'not_in_progress';
  end if;
  if v_visit.outcome is null then
    raise exception 'pick an outcome' using errcode = '22023', hint = 'no_outcome';
  end if;
  if v_visit.assessment is null and not exists (select 1 from public.medical_diagnoses where visit_id = p_id) then
    raise exception 'add a diagnosis or an assessment' using errcode = '22023', hint = 'no_assessment';
  end if;
  if v_visit.outcome = 'recheck' and (v_visit.recheck_on is null or v_visit.recheck_on < v_today) then
    raise exception 'the re-check date must be today or later' using errcode = '22023', hint = 'bad_recheck';
  end if;

  update public.medical_visits set
    status = 'done',
    signed_at = now(),
    signed_by = v_uid,
    signed_by_name = public.staff_display_name(v_uid)
  where id = p_id;

  if v_visit.outcome = 'recheck' then
    insert into public.medical_visits (
      code, branch_id, pet_id, customer_id, pet_name, customer_name, customer_phone, status, scheduled_at,
      reason, vet_id, vet_name, source, follow_up_of, created_by
    ) values (
      public.next_doc_code(v_visit.branch_id, 'KB'), v_visit.branch_id, v_visit.pet_id, v_visit.customer_id,
      v_visit.pet_name, v_visit.customer_name, v_visit.customer_phone, 'scheduled',
      ((v_visit.recheck_on + time '09:00') at time zone 'Asia/Ho_Chi_Minh'),
      'Tái khám: ' || coalesce(v_visit.reason, v_visit.code), v_visit.vet_id, v_visit.vet_name, 'recheck', p_id, v_uid
    ) returning id into v_child;
  end if;

  if v_visit.outcome = 'deceased' then
    update public.pets set status = 'deceased', deceased_on = v_today where id = v_visit.pet_id;
  end if;

  -- A visit with nothing to charge is paid at once.
  perform public.medical_refresh_status(p_id);

  return jsonb_build_object(
    'id', p_id,
    'status', (select status from public.medical_visits where id = p_id),
    'recheck_visit_id', v_child);
end;
$$;


ALTER FUNCTION "public"."sign_medical_visit"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."skip_inpatient_dose"("p_dose" "uuid", "p_reason" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_dose  public.inpatient_doses;
  v_order public.inpatient_orders;
begin
  select * into v_dose from public.inpatient_doses where id = p_dose for update;
  if not found then
    raise exception 'dose not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_order from public.inpatient_orders where id = v_dose.order_id;
  if not public.can_medical('UPDATE', v_order.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_dose.given_at is not null or v_dose.skipped_reason is not null then
    raise exception 'the dose is already recorded' using errcode = 'P0001', hint = 'already_done';
  end if;
  if length(btrim(coalesce(p_reason, ''))) = 0 then
    raise exception 'a reason is required' using errcode = '22023', hint = 'bad_input';
  end if;
  update public.inpatient_doses set skipped_reason = btrim(p_reason) where id = p_dose;
end;
$$;


ALTER FUNCTION "public"."skip_inpatient_dose"("p_dose" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."slugify"("p_text" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select coalesce(
    nullif(trim(both '-' from regexp_replace(lower(public.immutable_unaccent(p_text)), '[^a-z0-9]+', '-', 'g')), ''),
    'item'
  );
$$;


ALTER FUNCTION "public"."slugify"("p_text" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_block_is_free"("p_branch" "uuid", "p_start" timestamp with time zone, "p_minutes" integer) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."spa_block_is_free"("p_branch" "uuid", "p_start" timestamp with time zone, "p_minutes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_day_board"("p_branch" "uuid", "p_date" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_hours record;
  v_from timestamptz := (p_date::timestamp at time zone c_tz);
  v_to   timestamptz := ((p_date + 1)::timestamp at time zone c_tz);
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_hours from public.spa_hours(p_branch, p_date);

  return jsonb_build_object(
    'date', p_date,
    'is_closed', v_hours.is_closed,
    'open_time', to_char(v_hours.open_time, 'HH24:MI'),
    'close_time', to_char(v_hours.close_time, 'HH24:MI'),
    'staff', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', sb.user_id, 'name', public.staff_display_name(sb.user_id)
      ) order by public.staff_display_name(sb.user_id)), '[]'::jsonb)
      from public.staff_branches sb
      where sb.branch_id = p_branch and sb.does_services
    ),
    'resources', (
      select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name) order by r.sort_order, r.name), '[]'::jsonb)
      from public.spa_resources r
      where r.branch_id = p_branch and r.is_active
    ),
    'items', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'id', i.id,
        'appointment_id', a.id,
        'code', a.code,
        'source', a.source,
        'appointment_status', a.status,
        'status', i.status,
        'name', i.name,
        'start_at', i.start_at,
        'end_at', i.end_at,
        'staff_id', i.staff_id,
        'resource_id', i.resource_id,
        'pet_name', pt.name,
        'pet_photo_url', pt.photo_url,
        'customer_name', a.customer_name
      ) order by i.start_at, i.line_no), '[]'::jsonb)
      from public.appointment_items i
      join public.appointments a on a.id = i.appointment_id
      left join public.pets pt on pt.id = i.pet_id
      where i.branch_id = p_branch
        and i.status <> 'cancelled'
        and i.start_at >= v_from and i.start_at < v_to
    )
  );
end;
$$;


ALTER FUNCTION "public"."spa_day_board"("p_branch" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_hours"("p_branch" "uuid", "p_date" "date") RETURNS TABLE("open_time" time without time zone, "close_time" time without time zone, "is_closed" boolean)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce(h.open_time, time '08:00'),
         coalesce(h.close_time, time '20:00'),
         coalesce(h.is_closed, false)
  from (select 1) as one
  left join public.branch_hours h
    on h.branch_id = p_branch and h.weekday = extract(isodow from p_date)::int;
$$;


ALTER FUNCTION "public"."spa_hours"("p_branch" "uuid", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_public_catalog"("p_branch" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with sp as (
    select s.id, s.name
    from public.species s
    where s.is_active
  ),
  svc as (
    select v.*
    from public.pet_services v
    where v.is_active and v.category = 'spa'
  ),
  cmb as (
    select c.*
    from public.pet_service_combos c
    where c.is_active and c.status = 1 and coalesce(c.mark_as_id, '4') <> '3'
  ),
  svc_species as (
    select v.id as service_id,
           coalesce(
             (select jsonb_agg(ss.species_id order by sp.name)
              from public.service_species ss join sp on sp.id = ss.species_id
              where ss.service_id = v.id),
             '[]'::jsonb
           ) as listed,
           (select jsonb_agg(sp.id order by sp.name) from sp) as every
    from svc v
  ),
  cmb_species as (
    select c.id as combo_id,
           coalesce(
             (select jsonb_agg(cs.species_id order by sp.name)
              from public.combo_species cs join sp on sp.id = cs.species_id
              where cs.combo_id = c.id),
             '[]'::jsonb
           ) as listed,
           (select jsonb_agg(sp.id order by sp.name) from sp) as every
    from cmb c
  ),
  prices as (
    select distinct on (pr.species_id, pr.service_id, pr.bracket_id)
           pr.species_id, pr.service_id, pr.bracket_id, pr.price
    from public.pet_service_prices pr
    join svc on svc.id = pr.service_id and svc.type = 'by_weight'
    where pr.branch_id is null or pr.branch_id = p_branch
    order by pr.species_id, pr.service_id, pr.bracket_id, (pr.branch_id is not null) desc
  )
  select jsonb_build_object(
    'species', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', sp.id,
                 'name', sp.name,
                 'brackets', coalesce((
                   select jsonb_agg(
                            jsonb_build_object('id', b.id, 'label', b.label, 'min_kg', b.min_kg, 'max_kg', b.max_kg)
                            order by b.min_kg)
                   from public.weight_brackets b where b.species_id = sp.id
                 ), '[]'::jsonb)
               )
               order by sp.name)
      from sp
    ), '[]'::jsonb),
    'services', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', v.id,
                 'name', v.name,
                 'description', v.description,
                 'type', coalesce(v.type, 'all'),
                 'duration_minutes', v.duration_minutes,
                 'general_price', v.general_price,
                 'species_ids', case when jsonb_array_length(ss.listed) = 0 then coalesce(ss.every, '[]'::jsonb) else ss.listed end,
                 'prices', coalesce((
                   select jsonb_agg(jsonb_build_object(
                            'species_id', p.species_id, 'bracket_id', p.bracket_id, 'price', p.price))
                   from prices p where p.service_id = v.id
                 ), '[]'::jsonb)
               )
               order by v.name)
      from svc v join svc_species ss on ss.service_id = v.id
    ), '[]'::jsonb),
    'combos', coalesce((
      select jsonb_agg(
               jsonb_build_object(
                 'id', c.id,
                 'name', c.name,
                 'description', c.description,
                 'price', c.price,
                 'origin_price', c.origin_price,
                 'duration_minutes', c.duration_minutes,
                 'mark', c.mark_as_id,
                 'species_ids', case when jsonb_array_length(cs.listed) = 0 then coalesce(cs.every, '[]'::jsonb) else cs.listed end,
                 'service_names', coalesce((
                   select jsonb_agg(v.name order by v.name)
                   from public.combo_services x join public.pet_services v on v.id = x.service_id
                   where x.combo_id = c.id
                 ), '[]'::jsonb)
               )
               order by c.name)
      from cmb c join cmb_species cs on cs.combo_id = c.id
    ), '[]'::jsonb)
  );
$$;


ALTER FUNCTION "public"."spa_public_catalog"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_ticket_quote"("p_branch" "uuid", "p_pet" "uuid", "p_type" "text", "p_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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
    select * into v_service from public.pet_services where id = p_id and is_active and category = 'spa';
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


ALTER FUNCTION "public"."spa_ticket_quote"("p_branch" "uuid", "p_pet" "uuid", "p_type" "text", "p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_web_quote"("p_branch" "uuid", "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."spa_web_quote"("p_branch" "uuid", "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_web_rules"() RETURNS "jsonb"
    LANGUAGE "sql" IMMUTABLE
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'min_lead_minutes', 120,
    'max_days', 30,
    'max_open', 3,
    'cancel_before_minutes', 120,
    'step_minutes', 15,
    'max_block_minutes', 600
  );
$$;


ALTER FUNCTION "public"."spa_web_rules"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_web_slots"("p_branch" "uuid", "p_date" "date", "p_minutes" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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


ALTER FUNCTION "public"."spa_web_slots"("p_branch" "uuid", "p_date" "date", "p_minutes" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."spa_week_hours"("p_branch" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  if not public.can_schedule('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return (
    select jsonb_agg(jsonb_build_object(
      'weekday', d.weekday,
      'open_time', to_char(coalesce(h.open_time, time '08:00'), 'HH24:MI'),
      'close_time', to_char(coalesce(h.close_time, time '20:00'), 'HH24:MI'),
      'is_closed', coalesce(h.is_closed, false)
    ) order by d.weekday)
    from generate_series(1, 7) as d(weekday)
    left join public.branch_hours h on h.branch_id = p_branch and h.weekday = d.weekday
  );
end;
$$;


ALTER FUNCTION "public"."spa_week_hours"("p_branch" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_display_name"("p_user" "uuid") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select coalesce(nullif(btrim(full_name), ''), nullif(btrim(display_name), ''), email)
  from public.users
  where id = p_user;
$$;


ALTER FUNCTION "public"."staff_display_name"("p_user" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."staff_shop_order_json"("o" "public"."shop_orders") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  select jsonb_build_object(
    'id', o.id,
    'code', o.code,
    'branch_id', o.branch_id,
    'status', o.status,
    'delivery_method', o.delivery_method,
    'payment_method', o.payment_method,
    'customer_id', o.customer_id,
    'receiver_name', o.receiver_name,
    'receiver_phone', o.receiver_phone,
    'ship_street', o.ship_street,
    'ship_ward_name', o.ship_ward_name,
    'ship_district_name', o.ship_district_name,
    'ship_province_name', o.ship_province_name,
    'ghn_district_id', o.ghn_district_id,
    'ghn_ward_code', o.ghn_ward_code,
    'weight_g', o.weight_g,
    'subtotal', o.subtotal,
    'shipping_fee_quote', o.shipping_fee_quote,
    'shipping_fee', o.shipping_fee,
    'total', o.total,
    'customer_note', o.customer_note,
    'carrier', o.carrier,
    'tracking_code', o.tracking_code,
    'cancel_reason', o.cancel_reason,
    'placed_at', o.placed_at,
    'invoice', (
      select jsonb_build_object('id', i.id, 'code', i.code, 'status', i.status, 'total', i.total)
      from public.invoices i where i.id = o.invoice_id
    ),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'product_id', l.product_id, 'unit_id', l.unit_id, 'name', l.name, 'unit', l.unit,
        'image_url', l.image_url, 'qty', l.qty, 'unit_factor', l.unit_factor,
        'unit_price', l.unit_price, 'amount', l.amount,
        'track_stock', p.track_stock,
        'available', (
          select coalesce(
            (select a.qty from public.shop_available_qty(array[l.product_id]) a limit 1), 0)
            + case when o.status in ('pending', 'confirmed') then (
                select coalesce(sum(x.qty * x.unit_factor), 0)
                from public.shop_order_lines x where x.order_id = o.id and x.product_id = l.product_id)
              else 0 end
        )
      ) order by l.line_no)
      from public.shop_order_lines l
      join public.products p on p.id = l.product_id
      where l.order_id = o.id
    ), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
        'status', e.status, 'note', e.note, 'actor_name', e.actor_name, 'created_at', e.created_at
      ) order by e.created_at, e.id)
      from public.shop_order_events e where e.order_id = o.id
    ), '[]'::jsonb)
  );
$$;


ALTER FUNCTION "public"."staff_shop_order_json"("o" "public"."shop_orders") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."start_medical_visit"("p_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_uid   uuid := (select auth.uid());
  v_visit public.medical_visits;
  v_exam  uuid;
  v_service public.pet_services;
  v_price numeric;
begin
  select * into v_visit from public.medical_visits where id = p_id for update;
  if not found then
    raise exception 'visit not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_visit.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_visit.status = 'in_progress' then
    raise exception 'the visit was taken' using errcode = 'P0001', hint = 'taken', detail = coalesce(v_visit.vet_name, '');
  end if;
  if v_visit.status <> 'waiting' then
    raise exception 'the visit is not waiting' using errcode = 'P0001', hint = 'not_waiting';
  end if;

  update public.medical_visits set
    status = 'in_progress',
    started_at = now(),
    vet_id = coalesce(vet_id, v_uid),
    vet_name = case when vet_id is null then public.staff_display_name(v_uid) else vet_name end
  where id = p_id;

  -- The default exam service of the branch goes on the visit; a service that cannot be priced yet
  -- (a by-weight price and no weight) is left out and can be added by hand.
  select s.exam_service_id into v_exam from public.medical_settings s where s.branch_id = v_visit.branch_id;
  if v_exam is not null and not exists (select 1 from public.medical_visit_items where visit_id = p_id and auto_added) then
    select * into v_service from public.pet_services where id = v_exam and is_active and category = 'medical';
    if found then
      v_price := public.get_service_price(
        (select species_id from public.pets where id = v_visit.pet_id), v_service.id,
        coalesce(v_visit.weight_kg, 0), v_visit.branch_id);
      if v_price is not null then
        insert into public.medical_visit_items (
          visit_id, branch_id, kind, service_id, name, qty, unit_price, amount, auto_added, created_by, created_by_name
        ) values (
          p_id, v_visit.branch_id, 'service', v_service.id, v_service.name, 1, v_price, v_price, true,
          v_uid, public.staff_display_name(v_uid)
        );
      end if;
    end if;
  end if;
end;
$$;


ALTER FUNCTION "public"."start_medical_visit"("p_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stock_alert_counts"("p_branch" "uuid", "p_expiry_days" integer DEFAULT 60) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_result jsonb;
begin
  if not public.can_inventory('VIEW', p_branch) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'low',      count(*) filter (where s.min_qty is not null and s.sellable < s.min_qty),
    'out',      count(*) filter (where s.sellable = 0),
    'expiring', count(*) filter (where s.expiring > 0),
    'expired',  count(*) filter (where s.expired > 0)
  ) into v_result
  from public.stock_rows(p_branch, p_expiry_days) s;
  return v_result;
end;
$$;


ALTER FUNCTION "public"."stock_alert_counts"("p_branch" "uuid", "p_expiry_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stock_rows"("p_branch" "uuid", "p_expiry_days" integer) RETURNS TABLE("product_id" "uuid", "name" "text", "sku" "text", "barcode" "text", "unit" "text", "is_active" boolean, "on_hand" numeric, "sellable" numeric, "expired" numeric, "expiring" numeric, "next_expiry" "date", "stock_value" numeric, "min_qty" numeric)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
  with today as (
    select public.business_date() as d
  ), lots as (
    select
      l.product_id,
      sum(l.qty_on_hand) as on_hand,
      coalesce(sum(l.qty_on_hand) filter (where l.expiry_date is null or l.expiry_date >= t.d), 0) as sellable,
      coalesce(sum(l.qty_on_hand) filter (where l.expiry_date < t.d), 0) as expired,
      coalesce(sum(l.qty_on_hand) filter (
        where l.expiry_date >= t.d and l.expiry_date < t.d + greatest(p_expiry_days, 0)), 0) as expiring,
      min(l.expiry_date) filter (where l.expiry_date >= t.d) as next_expiry,
      sum(l.qty_on_hand * l.unit_cost) as stock_value
    from public.stock_lots l
    cross join today t
    where l.branch_id = p_branch and l.qty_on_hand > 0
    group by l.product_id
  )
  select
    p.id, p.name, p.sku, p.barcode, p.unit, p.is_active,
    coalesce(l.on_hand, 0), coalesce(l.sellable, 0), coalesce(l.expired, 0), coalesce(l.expiring, 0),
    l.next_expiry, coalesce(l.stock_value, 0), th.min_qty
  from public.products p
  left join lots l on l.product_id = p.id
  left join public.stock_thresholds th on th.branch_id = p_branch and th.product_id = p.id
  where p.track_stock and (p.is_active or l.product_id is not null);
$$;


ALTER FUNCTION "public"."stock_rows"("p_branch" "uuid", "p_expiry_days" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stock_summary"("p_branch" "uuid", "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT 'all'::"text", "p_expiry_days" integer DEFAULT 60, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("product_id" "uuid", "name" "text", "sku" "text", "barcode" "text", "unit" "text", "is_active" boolean, "on_hand" numeric, "sellable" numeric, "expired" numeric, "expiring" numeric, "next_expiry" "date", "stock_value" numeric, "min_qty" numeric, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_term text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if not public.can_inventory('VIEW', p_branch) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  return query
  select s.*, count(*) over ()
  from public.stock_rows(p_branch, p_expiry_days) s
  where (v_term is null
         or s.name ilike '%' || v_term || '%'
         or s.sku ilike '%' || v_term || '%'
         or s.barcode = v_term)
    and case coalesce(p_status, 'all')
          when 'low' then s.min_qty is not null and s.sellable < s.min_qty
          when 'out' then s.sellable = 0
          when 'expiring' then s.expiring > 0
          when 'expired' then s.expired > 0
          else true
        end
  order by s.name
  limit greatest(coalesce(p_limit, 20), 1) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."stock_summary"("p_branch" "uuid", "p_search" "text", "p_status" "text", "p_expiry_days" integer, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stop_inpatient_order"("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_order public.inpatient_orders;
begin
  select * into v_order from public.inpatient_orders where id = p_id for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_order.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_order.stopped_at is not null then
    return;
  end if;
  update public.inpatient_orders set stopped_at = now() where id = p_id;
  delete from public.inpatient_doses
  where order_id = p_id and given_at is null and skipped_reason is null and due_at > now();
  perform public.inpatient_log_change(
    p_id, v_order.visit_id, 'stop', public.inpatient_order_snapshot(v_order), null, p_reason
  );
end;
$$;


ALTER FUNCTION "public"."stop_inpatient_order"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_user_email"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
begin
  update public.users set email = new.email where id = new.id;
  return new;
end;
$$;


ALTER FUNCTION "public"."sync_user_email"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."take_stock_fefo"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_invoice" "uuid", "p_invoice_line" "uuid") RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_track boolean;
  v_name  text;
  v_left  numeric := p_qty;
  v_take  numeric;
  v_cost  numeric := 0;
  v_lot   record;
begin
  select track_stock, name into v_track, v_name from public.products where id = p_product;
  if not coalesce(v_track, false) then
    return null;
  end if;

  for v_lot in
    select id, qty_on_hand, unit_cost
    from public.stock_lots
    where branch_id = p_branch
      and product_id = p_product
      and qty_on_hand > 0
      and (expiry_date is null or expiry_date >= public.business_date())
    order by expiry_date asc nulls last, received_at, id
    for update
  loop
    exit when v_left <= 0;
    v_take := least(v_left, v_lot.qty_on_hand);
    perform public.move_stock(v_lot.id, -v_take, 'sale', p_invoice => p_invoice, p_invoice_line => p_invoice_line);
    v_cost := v_cost + v_take * v_lot.unit_cost;
    v_left := v_left - v_take;
  end loop;

  if v_left > 0 then
    raise exception 'not enough stock for %: % short', v_name, v_left
      using errcode = 'P0001', hint = 'out_of_stock', detail = v_name;
  end if;
  return round(v_cost, 2);
end;
$$;


ALTER FUNCTION "public"."take_stock_fefo"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_invoice" "uuid", "p_invoice_line" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."take_stock_lot_first"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_lot" "uuid", "p_invoice" "uuid", "p_invoice_line" "uuid") RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_lot   public.stock_lots;
  v_take  numeric := 0;
  v_cost  numeric := 0;
  v_rest  numeric;
  v_more  numeric;
begin
  if p_lot is null then
    return public.take_stock_fefo(p_branch, p_product, p_qty, p_invoice, p_invoice_line);
  end if;
  if not coalesce((select track_stock from public.products where id = p_product), false) then
    return null;
  end if;

  select * into v_lot from public.stock_lots
  where id = p_lot and branch_id = p_branch and product_id = p_product
  for update;
  if found and v_lot.qty_on_hand > 0 then
    v_take := least(p_qty, v_lot.qty_on_hand);
    perform public.move_stock(v_lot.id, -v_take, 'sale', p_invoice => p_invoice, p_invoice_line => p_invoice_line);
    v_cost := v_take * v_lot.unit_cost;
  end if;

  v_rest := p_qty - v_take;
  if v_rest > 0 then
    v_more := public.take_stock_fefo(p_branch, p_product, v_rest, p_invoice, p_invoice_line);
    v_cost := v_cost + coalesce(v_more, 0);
  end if;
  return round(v_cost, 2);
end;
$$;


ALTER FUNCTION "public"."take_stock_lot_first"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_lot" "uuid", "p_invoice" "uuid", "p_invoice_line" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_inpatient_order"("p_id" "uuid", "p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $_$
declare
  v_order   public.inpatient_orders;
  v_stay    public.boarding_stays;
  v_today   date := public.business_date();
  v_dose    text;
  v_qty     numeric;
  v_times   text[];
  v_start   date;
  v_end     date;
  v_note    text;
  v_after   public.inpatient_orders;
  v_rebuild boolean;
  v_due     timestamptz[];
  v_added   int := 0;
  v_removed int := 0;
begin
  select * into v_order from public.inpatient_orders where id = p_id for update;
  if not found then
    raise exception 'order not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_order.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if exists (select 1 from public.medical_visits where id = v_order.visit_id and signed_at is not null) then
    raise exception 'the visit is signed' using errcode = 'P0001', hint = 'signed';
  end if;
  select * into v_stay from public.boarding_stays where id = v_order.stay_id;
  if v_stay.status <> 'checked_in' then
    raise exception 'the pet is not in the clinic' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_order.stopped_at is not null then
    raise exception 'the order is stopped' using errcode = 'P0001', hint = 'order_stopped';
  end if;

  -- The medicine, service or kind of an order never changes: stop it and write a new one.
  if (p ? 'kind' and p ->> 'kind' is distinct from v_order.kind)
     or (p ? 'product_id' and nullif(p ->> 'product_id', '')::uuid is distinct from v_order.product_id)
     or (p ? 'service_id' and nullif(p ->> 'service_id', '')::uuid is distinct from v_order.service_id)
     or (p ? 'name' and nullif(btrim(p ->> 'name'), '') is distinct from v_order.name) then
    raise exception 'use replace to change the medicine' using errcode = '22023', hint = 'replace_order';
  end if;

  v_dose  := case when p ? 'dose' then nullif(btrim(p ->> 'dose'), '') else v_order.dose end;
  v_qty   := case when p ? 'qty_per_dose' then nullif(p ->> 'qty_per_dose', '')::numeric else v_order.qty_per_dose end;
  v_start := case when p ? 'start_on' then nullif(p ->> 'start_on', '')::date else v_order.start_on end;
  v_end   := case when p ? 'end_on' then nullif(p ->> 'end_on', '')::date else v_order.end_on end;
  v_note  := case when p ? 'note' then nullif(btrim(p ->> 'note'), '') else v_order.note end;
  if p ? 'times' then
    select coalesce(array_agg(distinct t order by t), '{}') into v_times
    from jsonb_array_elements_text(coalesce(p -> 'times', '[]'::jsonb)) as x(t);
    if cardinality(v_times) not between 1 and 8
       or exists (select 1 from unnest(v_times) t where t !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$') then
      raise exception 'pick the hours' using errcode = '22023', hint = 'bad_input';
    end if;
  else
    v_times := v_order.times;
  end if;

  if v_qty is null or v_qty <= 0 or v_start is null or v_end is null or v_end < v_start or v_end > v_start + 30 then
    raise exception 'bad order' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_end < v_today and v_end is distinct from v_order.end_on then
    raise exception 'the end date is in the past' using errcode = '22023', hint = 'bad_input';
  end if;
  if v_start is distinct from v_order.start_on and exists (
    select 1 from public.inpatient_doses
    where order_id = p_id and (given_at is not null or skipped_reason is not null)
  ) then
    raise exception 'doses were already recorded' using errcode = '22023', hint = 'bad_input';
  end if;

  update public.inpatient_orders set
    dose = v_dose, qty_per_dose = v_qty, times = v_times, start_on = v_start, end_on = v_end, note = v_note
  where id = p_id
  returning * into v_after;

  if public.inpatient_order_snapshot(v_after) is not distinct from public.inpatient_order_snapshot(v_order) then
    return jsonb_build_object('id', p_id, 'doses_added', 0, 'doses_removed', 0);
  end if;

  v_rebuild := v_times is distinct from v_order.times or v_start is distinct from v_order.start_on
               or v_end is distinct from v_order.end_on;
  if v_rebuild then
    select coalesce(array_agg(due), '{}') into v_due
    from (
      select (d::timestamp + t::time) at time zone 'Asia/Ho_Chi_Minh' as due
      from generate_series(greatest(v_start, v_today)::timestamp, v_end::timestamp, interval '1 day') d
      cross join unnest(v_times) t
    ) x
    where due > now();

    -- Keep the doses that are still wanted, drop the rest, add the new ones.
    with gone as (
      delete from public.inpatient_doses
      where order_id = p_id and given_at is null and skipped_reason is null and due_at > now()
        and not (due_at = any (v_due))
      returning 1
    )
    select count(*) into v_removed from gone;

    with fresh as (
      insert into public.inpatient_doses (order_id, due_at)
      select p_id, unnest(v_due)
      on conflict (order_id, due_at) do nothing
      returning 1
    )
    select count(*) into v_added from fresh;
  end if;

  perform public.inpatient_log_change(
    p_id, v_order.visit_id, 'update',
    public.inpatient_order_snapshot(v_order), public.inpatient_order_snapshot(v_after), p ->> 'reason'
  );
  return jsonb_build_object('id', p_id, 'doses_added', v_added, 'doses_removed', v_removed);
end;
$_$;


ALTER FUNCTION "public"."update_inpatient_order"("p_id" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_medical_item"("p_id" "uuid", "p" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_item     public.medical_visit_items;
  v_visit    public.medical_visits;
  v_qty      numeric;
  v_unit     public.product_units;
  v_factor   numeric;
  v_unit_name text;
  v_unit_id  uuid;
  v_price    numeric;
  v_days     int;
  v_warnings jsonb := '[]'::jsonb;
begin
  select * into v_item from public.medical_visit_items where id = p_id for update;
  if not found then
    raise exception 'line not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  select * into v_visit from public.medical_visits where id = v_item.visit_id for update;
  if not public.can_medical('UPDATE', v_item.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_item.invoice_line_id is not null or v_visit.status not in ('in_progress', 'done', 'paid') then
    raise exception 'the line can no longer be changed' using errcode = 'P0001', hint = 'not_editable';
  end if;

  v_qty := case when p ? 'qty' then (p ->> 'qty')::numeric else v_item.qty end;
  v_days := case when p ? 'days' then nullif(p ->> 'days', '')::int else v_item.days end;
  if v_qty is null or v_qty <= 0 or v_qty > 999 or (v_days is not null and v_days <= 0) then
    raise exception 'bad line' using errcode = '22023', hint = 'bad_input';
  end if;

  v_price := v_item.unit_price;
  v_factor := v_item.unit_factor;
  v_unit_name := v_item.unit_name;
  v_unit_id := v_item.unit_id;
  if v_item.kind = 'product' and p ? 'unit_id' then
    if nullif(p ->> 'unit_id', '') is null then
      v_unit_id := null;
      v_factor := 1;
      select unit into v_unit_name from public.products where id = v_item.product_id;
    else
      select * into v_unit from public.product_units
      where id = (p ->> 'unit_id')::uuid and product_id = v_item.product_id and is_active and for_sale;
      if not found then
        raise exception 'unit does not belong to the product' using errcode = '22023', hint = 'bad_unit';
      end if;
      v_unit_id := v_unit.id;
      v_factor := v_unit.factor;
      v_unit_name := v_unit.name;
    end if;
    v_price := public.product_unit_price(v_item.product_id, v_item.branch_id, v_unit_id);
  end if;

  update public.medical_visit_items set
    qty = v_qty,
    unit_id = v_unit_id,
    unit_name = v_unit_name,
    unit_factor = v_factor,
    unit_price = v_price,
    amount = case when kind = 'external' then 0 else round(v_price * v_qty, 2) end,
    take_home = case
      when kind = 'external' then true
      when kind = 'service' then false
      when p ? 'take_home' then coalesce((p ->> 'take_home')::boolean, false)
      else take_home end,
    dose = case when p ? 'dose' then nullif(btrim(p ->> 'dose'), '') else dose end,
    frequency = case when p ? 'frequency' then nullif(btrim(p ->> 'frequency'), '') else frequency end,
    days = v_days,
    route = case when p ? 'route' then nullif(btrim(p ->> 'route'), '') else route end,
    instructions = case when p ? 'instructions' then nullif(btrim(p ->> 'instructions'), '') else instructions end
  where id = p_id;

  if v_item.kind = 'product'
     and exists (select 1 from public.products pr where pr.id = v_item.product_id and pr.track_stock)
     and public.medical_stock_qty(v_item.branch_id, v_item.product_id) < v_qty * v_factor then
    v_warnings := v_warnings || to_jsonb('low_stock'::text);
  end if;
  return jsonb_build_object('id', p_id, 'warnings', v_warnings);
end;
$$;


ALTER FUNCTION "public"."update_medical_item"("p_id" "uuid", "p" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."vaccine_lots"("p_branch" "uuid", "p_vaccine_type" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_product uuid;
begin
  if not public.can_medical('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select product_id into v_product from public.vaccine_types where id = p_vaccine_type;
  if v_product is null then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id, 'lot_no', l.lot_no, 'expiry_date', l.expiry_date, 'qty_on_hand', l.qty_on_hand
    ) order by l.expiry_date nulls last, l.received_at)
    from public.stock_lots l
    where l.branch_id = p_branch and l.product_id = v_product and l.qty_on_hand > 0
      and (l.expiry_date is null or l.expiry_date >= public.business_date())
  ), '[]'::jsonb);
end;
$$;


ALTER FUNCTION "public"."vaccine_lots"("p_branch" "uuid", "p_vaccine_type" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."void_vaccination"("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_shot public.vaccinations;
  v_item public.medical_visit_items;
begin
  select * into v_shot from public.vaccinations where id = p_id for update;
  if not found then
    raise exception 'shot not found' using errcode = 'P0002', hint = 'not_found';
  end if;
  if not public.can_medical('UPDATE', v_shot.branch_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if v_shot.voided_at is not null then
    raise exception 'the shot is already voided' using errcode = 'P0001', hint = 'not_editable';
  end if;
  if v_shot.visit_item_id is not null then
    select * into v_item from public.medical_visit_items where id = v_shot.visit_item_id for update;
    if found and v_item.invoice_line_id is not null then
      raise exception 'the shot is already billed' using errcode = 'P0001', hint = 'not_editable';
    end if;
    delete from public.medical_visit_items where id = v_shot.visit_item_id;
  end if;
  update public.vaccinations set voided_at = now(), void_reason = nullif(btrim(p_reason), '') where id = p_id;
  if v_shot.visit_id is not null then
    perform public.medical_refresh_status(v_shot.visit_id);
  end if;
end;
$$;


ALTER FUNCTION "public"."void_vaccination"("p_id" "uuid", "p_reason" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."appointment_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "appointment_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "line_no" integer NOT NULL,
    "pet_id" "uuid",
    "item_type" "text" NOT NULL,
    "service_id" "uuid",
    "combo_id" "uuid",
    "name" "text" NOT NULL,
    "duration_minutes" integer NOT NULL,
    "staff_id" "uuid",
    "resource_id" "uuid",
    "start_at" timestamp with time zone NOT NULL,
    "end_at" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'waiting'::"text" NOT NULL,
    "est_price" numeric(14,2),
    "weight_kg" numeric(6,2),
    "unit_price" numeric(14,2),
    "invoice_line_id" "uuid",
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "appointment_items_check" CHECK (("end_at" > "start_at")),
    CONSTRAINT "appointment_items_check1" CHECK (((("item_type" = 'service'::"text") AND ("service_id" IS NOT NULL) AND ("combo_id" IS NULL)) OR (("item_type" = 'combo'::"text") AND ("combo_id" IS NOT NULL) AND ("service_id" IS NULL)))),
    CONSTRAINT "appointment_items_duration_minutes_check" CHECK (("duration_minutes" > 0)),
    CONSTRAINT "appointment_items_est_price_check" CHECK (("est_price" >= (0)::numeric)),
    CONSTRAINT "appointment_items_item_type_check" CHECK (("item_type" = ANY (ARRAY['service'::"text", 'combo'::"text"]))),
    CONSTRAINT "appointment_items_status_check" CHECK (("status" = ANY (ARRAY['waiting'::"text", 'in_progress'::"text", 'done'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "appointment_items_unit_price_check" CHECK (("unit_price" >= (0)::numeric)),
    CONSTRAINT "appointment_items_weight_kg_check" CHECK (("weight_kg" > (0)::numeric))
);


ALTER TABLE "public"."appointment_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."appointments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "customer_name" "text" NOT NULL,
    "customer_phone" "text" NOT NULL,
    "start_at" timestamp with time zone NOT NULL,
    "end_at" timestamp with time zone NOT NULL,
    "status" "text" DEFAULT 'booked'::"text" NOT NULL,
    "source" "text" DEFAULT 'counter'::"text" NOT NULL,
    "note" "text",
    "checked_in_at" timestamp with time zone,
    "cancelled_at" timestamp with time zone,
    "cancel_reason" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "appointments_check" CHECK (("end_at" > "start_at")),
    CONSTRAINT "appointments_source_check" CHECK (("source" = ANY (ARRAY['counter'::"text", 'phone'::"text", 'legacy'::"text", 'web'::"text"]))),
    CONSTRAINT "appointments_status_check" CHECK (("status" = ANY (ARRAY['booked'::"text", 'checked_in'::"text", 'in_progress'::"text", 'done'::"text", 'paid'::"text", 'cancelled'::"text", 'no_show'::"text"])))
);


ALTER TABLE "public"."appointments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."banners" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "title" "text",
    "image_url" "text",
    "link_url" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."banners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."boarding_care_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "stay_pet_id" "uuid" NOT NULL,
    "stay_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "meal_eaten" "text",
    "content" "text",
    "visible_to_customer" boolean DEFAULT true NOT NULL,
    "logged_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_by" "uuid",
    CONSTRAINT "boarding_care_logs_check" CHECK ((("kind" = 'meal'::"text") OR ("meal_eaten" IS NULL))),
    CONSTRAINT "boarding_care_logs_check1" CHECK ((("kind" = 'meal'::"text") OR (NULLIF("btrim"("content"), ''::"text") IS NOT NULL))),
    CONSTRAINT "boarding_care_logs_kind_check" CHECK (("kind" = ANY (ARRAY['meal'::"text", 'walk'::"text", 'potty'::"text", 'medication'::"text", 'note'::"text", 'vitals'::"text", 'treatment'::"text"]))),
    CONSTRAINT "boarding_care_logs_meal_eaten_check" CHECK (("meal_eaten" = ANY (ARRAY['all'::"text", 'some'::"text", 'none'::"text"])))
);


ALTER TABLE "public"."boarding_care_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."boarding_charges" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "stay_id" "uuid" NOT NULL,
    "stay_pet_id" "uuid",
    "branch_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "service_id" "uuid",
    "name" "text" NOT NULL,
    "qty" numeric(8,2) NOT NULL,
    "unit_price" numeric(14,2) NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "invoice_line_id" "uuid",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "boarding_charges_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "boarding_charges_check" CHECK ((("kind" <> 'extra'::"text") OR ("service_id" IS NOT NULL))),
    CONSTRAINT "boarding_charges_kind_check" CHECK (("kind" = ANY (ARRAY['night'::"text", 'late'::"text", 'extra'::"text"]))),
    CONSTRAINT "boarding_charges_qty_check" CHECK (("qty" > (0)::numeric)),
    CONSTRAINT "boarding_charges_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."boarding_charges" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."boarding_settings" (
    "branch_id" "uuid" NOT NULL,
    "check_in_from" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "check_out_by" time without time zone DEFAULT '12:00:00'::time without time zone NOT NULL,
    "late_half_until" time without time zone DEFAULT '18:00:00'::time without time zone NOT NULL,
    "max_nights" integer DEFAULT 30 NOT NULL,
    "day_stay_nights" numeric(2,1) DEFAULT 1 NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "boarding_settings_check" CHECK (("check_out_by" < "late_half_until")),
    CONSTRAINT "boarding_settings_day_stay_nights_check" CHECK (("day_stay_nights" = ANY (ARRAY[0.5, (1)::numeric]))),
    CONSTRAINT "boarding_settings_max_nights_check" CHECK ((("max_nights" >= 1) AND ("max_nights" <= 365)))
);


ALTER TABLE "public"."boarding_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."boarding_stay_pets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "stay_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "line_no" integer NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "pet_name" "text" NOT NULL,
    "kennel_type_id" "uuid" NOT NULL,
    "kennel_id" "uuid" NOT NULL,
    "nights" "daterange" NOT NULL,
    "charged_nights" numeric(5,1) NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "is_extra_pet" boolean DEFAULT false NOT NULL,
    "est_night_price" numeric(14,2) NOT NULL,
    "night_price" numeric(14,2),
    "weight_kg" numeric(6,2),
    "vaccine_checked" boolean DEFAULT false NOT NULL,
    "vaccine_note" "text",
    "belongings" "text",
    "belongings_returned" boolean DEFAULT false NOT NULL,
    "feeding" "text",
    "medication" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "boarding_stay_pets_charged_nights_check" CHECK (("charged_nights" > (0)::numeric)),
    CONSTRAINT "boarding_stay_pets_est_night_price_check" CHECK (("est_night_price" >= (0)::numeric)),
    CONSTRAINT "boarding_stay_pets_night_price_check" CHECK (("night_price" >= (0)::numeric)),
    CONSTRAINT "boarding_stay_pets_nights_check" CHECK ((NOT "isempty"("nights"))),
    CONSTRAINT "boarding_stay_pets_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "boarding_stay_pets_weight_kg_check" CHECK (("weight_kg" > (0)::numeric))
);


ALTER TABLE "public"."boarding_stay_pets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bookings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "email" "text" NOT NULL,
    "phone_number" "text" NOT NULL,
    "scheduled_at" timestamp with time zone NOT NULL,
    "content" "text",
    "user_id" "uuid" DEFAULT "auth"."uid"(),
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "is_cancel" boolean DEFAULT false NOT NULL,
    "is_moving_time" boolean DEFAULT false NOT NULL,
    "cancel_date" timestamp with time zone,
    "cancel_by" "uuid",
    "cancel_reason" "text",
    "confirm_changed_by" "uuid",
    "confirm_from_time" timestamp with time zone,
    "confirm_to_time" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "bookings_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'PROCESSING'::"text", 'CONFIRMED'::"text", 'CANCEL'::"text"])))
);


ALTER TABLE "public"."bookings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branch_hours" (
    "branch_id" "uuid" NOT NULL,
    "weekday" smallint NOT NULL,
    "open_time" time without time zone DEFAULT '08:00:00'::time without time zone NOT NULL,
    "close_time" time without time zone DEFAULT '20:00:00'::time without time zone NOT NULL,
    "is_closed" boolean DEFAULT false NOT NULL,
    CONSTRAINT "branch_hours_check" CHECK (("is_closed" OR ("close_time" > "open_time"))),
    CONSTRAINT "branch_hours_weekday_check" CHECK ((("weekday" >= 1) AND ("weekday" <= 7)))
);


ALTER TABLE "public"."branch_hours" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "address" "text",
    "phone" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "branches_code_check" CHECK (("code" ~ '^[A-Z0-9]{2,8}$'::"text"))
);


ALTER TABLE "public"."branches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cash_shifts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'open'::"text" NOT NULL,
    "opened_by" "uuid" NOT NULL,
    "opened_by_name" "text",
    "opened_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "opening_cash" numeric(14,2) NOT NULL,
    "open_note" "text",
    "closed_by" "uuid",
    "closed_by_name" "text",
    "closed_at" timestamp with time zone,
    "expected_cash" numeric(14,2),
    "counted_cash" numeric(14,2),
    "close_note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "cash_shifts_check" CHECK ((("status" = 'open'::"text") = ("closed_at" IS NULL))),
    CONSTRAINT "cash_shifts_counted_cash_check" CHECK (("counted_cash" >= (0)::numeric)),
    CONSTRAINT "cash_shifts_opening_cash_check" CHECK (("opening_cash" >= (0)::numeric)),
    CONSTRAINT "cash_shifts_status_check" CHECK (("status" = ANY (ARRAY['open'::"text", 'closed'::"text"])))
);


ALTER TABLE "public"."cash_shifts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."combo_services" (
    "combo_id" "uuid" NOT NULL,
    "service_id" "uuid" NOT NULL
);


ALTER TABLE "public"."combo_services" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."combo_species" (
    "combo_id" "uuid" NOT NULL,
    "species_id" "uuid" NOT NULL
);


ALTER TABLE "public"."combo_species" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "full_name" "text" NOT NULL,
    "phone" "text" NOT NULL,
    "phone_digits" "text" GENERATED ALWAYS AS ("regexp_replace"("phone", '\D'::"text", ''::"text", 'g'::"text")) STORED,
    "email" "text",
    "note" "text",
    "user_id" "uuid",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid" DEFAULT "auth"."uid"(),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "birth_date" "date",
    CONSTRAINT "customers_full_name_check" CHECK (("length"("btrim"("full_name")) > 0)),
    CONSTRAINT "customers_phone_check" CHECK ((("length"("regexp_replace"("phone", '\D'::"text", ''::"text", 'g'::"text")) >= 8) AND ("length"("regexp_replace"("phone", '\D'::"text", ''::"text", 'g'::"text")) <= 15)))
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."diagnosis_terms" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "species_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "is_contagious" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "diagnosis_terms_name_check" CHECK (("length"("btrim"("name")) > 0))
);


ALTER TABLE "public"."diagnosis_terms" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."doc_sequences" (
    "branch_id" "uuid" NOT NULL,
    "doc_type" "text" NOT NULL,
    "last_no" bigint DEFAULT 0 NOT NULL,
    CONSTRAINT "doc_sequences_doc_type_check" CHECK (("doc_type" ~ '^[A-Z]{2,4}$'::"text"))
);


ALTER TABLE "public"."doc_sequences" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inpatient_doses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "due_at" timestamp with time zone NOT NULL,
    "given_at" timestamp with time zone,
    "given_by" "uuid",
    "given_by_name" "text",
    "skipped_reason" "text",
    "qty" numeric(10,2),
    CONSTRAINT "inpatient_doses_check" CHECK ((("given_at" IS NULL) OR ("skipped_reason" IS NULL)))
);


ALTER TABLE "public"."inpatient_doses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inpatient_order_changes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "visit_id" "uuid" NOT NULL,
    "action" "text" NOT NULL,
    "before" "jsonb",
    "after" "jsonb",
    "reason" "text",
    "changed_by" "uuid",
    "changed_by_name" "text",
    "changed_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "inpatient_order_changes_action_check" CHECK (("action" = ANY (ARRAY['create'::"text", 'update'::"text", 'stop'::"text", 'replace'::"text"])))
);


ALTER TABLE "public"."inpatient_order_changes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoice_lines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "invoice_id" "uuid" NOT NULL,
    "line_no" integer NOT NULL,
    "item_type" "text" NOT NULL,
    "product_id" "uuid",
    "service_id" "uuid",
    "combo_id" "uuid",
    "pet_id" "uuid",
    "pet_name" "text",
    "name" "text" NOT NULL,
    "unit" "text",
    "qty" numeric(10,2) NOT NULL,
    "unit_price" numeric(14,2) NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "weight_kg" numeric(6,2),
    "cost_amount" numeric(14,2),
    "unit_id" "uuid",
    "unit_factor" numeric(12,2) DEFAULT 1 NOT NULL,
    "base_qty" numeric GENERATED ALWAYS AS (("qty" * "unit_factor")) STORED,
    "lot_id" "uuid",
    CONSTRAINT "invoice_lines_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "invoice_lines_check" CHECK (((("item_type" = 'product'::"text") AND ("product_id" IS NOT NULL) AND ("service_id" IS NULL) AND ("combo_id" IS NULL)) OR (("item_type" = 'service'::"text") AND ("service_id" IS NOT NULL) AND ("product_id" IS NULL) AND ("combo_id" IS NULL)) OR (("item_type" = 'combo'::"text") AND ("combo_id" IS NOT NULL) AND ("product_id" IS NULL) AND ("service_id" IS NULL)) OR (("item_type" = 'boarding'::"text") AND ("product_id" IS NULL) AND ("service_id" IS NULL) AND ("combo_id" IS NULL)))),
    CONSTRAINT "invoice_lines_item_type_check" CHECK (("item_type" = ANY (ARRAY['product'::"text", 'service'::"text", 'combo'::"text", 'boarding'::"text"]))),
    CONSTRAINT "invoice_lines_qty_check" CHECK (("qty" > (0)::numeric)),
    CONSTRAINT "invoice_lines_unit_factor_check" CHECK (("unit_factor" > (0)::numeric)),
    CONSTRAINT "invoice_lines_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."invoice_lines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "shift_id" "uuid",
    "customer_id" "uuid",
    "customer_name" "text",
    "customer_phone" "text",
    "cashier_name" "text",
    "status" "text" DEFAULT 'paid'::"text" NOT NULL,
    "subtotal" numeric(14,2) NOT NULL,
    "discount_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "total" numeric(14,2) NOT NULL,
    "paid_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "change_amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "note" "text",
    "einvoice_no" "text",
    "created_by" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cancelled_at" timestamp with time zone,
    "cancelled_by" "uuid",
    "cancel_reason" "text",
    "client_ref" "uuid",
    "channel" "text" DEFAULT 'pos'::"text" NOT NULL,
    CONSTRAINT "invoices_change_amount_check" CHECK (("change_amount" >= (0)::numeric)),
    CONSTRAINT "invoices_channel_check" CHECK (("channel" = ANY (ARRAY['pos'::"text", 'online'::"text"]))),
    CONSTRAINT "invoices_check" CHECK (("discount_amount" <= "subtotal")),
    CONSTRAINT "invoices_check1" CHECK (("total" = ("subtotal" - "discount_amount"))),
    CONSTRAINT "invoices_check2" CHECK ((("status" = 'cancelled'::"text") = ("cancelled_at" IS NOT NULL))),
    CONSTRAINT "invoices_discount_amount_check" CHECK (("discount_amount" >= (0)::numeric)),
    CONSTRAINT "invoices_paid_amount_check" CHECK (("paid_amount" >= (0)::numeric)),
    CONSTRAINT "invoices_pos_needs_shift" CHECK ((("channel" = 'online'::"text") OR ("shift_id" IS NOT NULL))),
    CONSTRAINT "invoices_status_check" CHECK (("status" = ANY (ARRAY['paid'::"text", 'unpaid'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "invoices_subtotal_check" CHECK (("subtotal" >= (0)::numeric)),
    CONSTRAINT "invoices_total_check" CHECK (("total" >= (0)::numeric))
);


ALTER TABLE "public"."invoices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kennel_type_prices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "kennel_type_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "night_price" numeric(14,2) NOT NULL,
    "extra_pet_night_price" numeric(14,2),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kennel_type_prices_extra_pet_night_price_check" CHECK (("extra_pet_night_price" >= (0)::numeric)),
    CONSTRAINT "kennel_type_prices_night_price_check" CHECK (("night_price" >= (0)::numeric))
);


ALTER TABLE "public"."kennel_type_prices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kennel_types" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "photo_url" "text",
    "species_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "max_weight_kg" numeric(6,2),
    "max_pets" integer DEFAULT 1 NOT NULL,
    "purpose" "text" DEFAULT 'boarding'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_public" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kennel_types_max_pets_check" CHECK (("max_pets" >= 1)),
    CONSTRAINT "kennel_types_max_weight_kg_check" CHECK (("max_weight_kg" > (0)::numeric)),
    CONSTRAINT "kennel_types_name_check" CHECK (("length"("btrim"("name")) > 0)),
    CONSTRAINT "kennel_types_purpose_check" CHECK (("purpose" = ANY (ARRAY['boarding'::"text", 'medical'::"text", 'isolation'::"text"])))
);


ALTER TABLE "public"."kennel_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."kennels" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "kennel_type_id" "uuid" NOT NULL,
    "code" "text" NOT NULL,
    "name" "text",
    "status" "text" DEFAULT 'ready'::"text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "kennels_code_check" CHECK (("length"("btrim"("code")) > 0)),
    CONSTRAINT "kennels_status_check" CHECK (("status" = ANY (ARRAY['ready'::"text", 'cleaning'::"text", 'maintenance'::"text"])))
);


ALTER TABLE "public"."kennels" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_addenda" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "visit_id" "uuid" NOT NULL,
    "content" "text" NOT NULL,
    "created_by" "uuid",
    "created_by_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "medical_addenda_content_check" CHECK (("length"("btrim"("content")) > 0))
);


ALTER TABLE "public"."medical_addenda" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_attachments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "visit_id" "uuid" NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "title" "text" NOT NULL,
    "file_path" "text" NOT NULL,
    "mime_type" "text" NOT NULL,
    "size_bytes" bigint NOT NULL,
    "created_by" "uuid",
    "created_by_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "medical_attachments_kind_check" CHECK (("kind" = ANY (ARRAY['lab'::"text", 'imaging'::"text", 'photo'::"text", 'consent'::"text", 'other'::"text"]))),
    CONSTRAINT "medical_attachments_size_bytes_check" CHECK ((("size_bytes" > 0) AND ("size_bytes" <= 10485760))),
    CONSTRAINT "medical_attachments_title_check" CHECK (("length"("btrim"("title")) > 0))
);


ALTER TABLE "public"."medical_attachments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_diagnoses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "visit_id" "uuid" NOT NULL,
    "term_id" "uuid",
    "name" "text" NOT NULL,
    "is_contagious" boolean DEFAULT false NOT NULL,
    "note" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "medical_diagnoses_name_check" CHECK (("length"("btrim"("name")) > 0))
);


ALTER TABLE "public"."medical_diagnoses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_settings" (
    "branch_id" "uuid" NOT NULL,
    "exam_service_id" "uuid",
    "remind_ahead_days" integer DEFAULT 7 NOT NULL,
    "contagious_days" integer DEFAULT 30 NOT NULL,
    "require_vaccine_for_boarding" boolean DEFAULT false NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "medical_settings_contagious_days_check" CHECK ((("contagious_days" >= 1) AND ("contagious_days" <= 365))),
    CONSTRAINT "medical_settings_remind_ahead_days_check" CHECK ((("remind_ahead_days" >= 0) AND ("remind_ahead_days" <= 90)))
);


ALTER TABLE "public"."medical_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."medical_visit_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "visit_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "kind" "text" NOT NULL,
    "service_id" "uuid",
    "product_id" "uuid",
    "unit_id" "uuid",
    "unit_name" "text",
    "unit_factor" numeric(12,2) DEFAULT 1 NOT NULL,
    "name" "text" NOT NULL,
    "qty" numeric(10,2) DEFAULT 1 NOT NULL,
    "unit_price" numeric(14,2) DEFAULT 0 NOT NULL,
    "amount" numeric(14,2) DEFAULT 0 NOT NULL,
    "take_home" boolean DEFAULT false NOT NULL,
    "dose" "text",
    "frequency" "text",
    "days" integer,
    "route" "text",
    "instructions" "text",
    "auto_added" boolean DEFAULT false NOT NULL,
    "lot_id" "uuid",
    "vaccination_id" "uuid",
    "invoice_line_id" "uuid",
    "created_by" "uuid",
    "created_by_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "medical_visit_items_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "medical_visit_items_days_check" CHECK (("days" > 0)),
    CONSTRAINT "medical_visit_items_external_free" CHECK ((("kind" <> 'external'::"text") OR (("unit_price" = (0)::numeric) AND ("amount" = (0)::numeric)))),
    CONSTRAINT "medical_visit_items_kind_check" CHECK (("kind" = ANY (ARRAY['service'::"text", 'product'::"text", 'external'::"text"]))),
    CONSTRAINT "medical_visit_items_kind_ref" CHECK (((("kind" = 'service'::"text") AND ("service_id" IS NOT NULL) AND ("product_id" IS NULL)) OR (("kind" = 'product'::"text") AND ("product_id" IS NOT NULL) AND ("service_id" IS NULL)) OR (("kind" = 'external'::"text") AND ("service_id" IS NULL) AND ("product_id" IS NULL)))),
    CONSTRAINT "medical_visit_items_name_check" CHECK (("length"("btrim"("name")) > 0)),
    CONSTRAINT "medical_visit_items_qty_check" CHECK (("qty" > (0)::numeric)),
    CONSTRAINT "medical_visit_items_unit_factor_check" CHECK (("unit_factor" >= (1)::numeric)),
    CONSTRAINT "medical_visit_items_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."medical_visit_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."order_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "service_id" "uuid",
    "combo_id" "uuid",
    "name" "text" NOT NULL,
    "price" numeric(14,2) NOT NULL,
    "duration_minutes" integer,
    "status" "text" DEFAULT 'PENDING'::"text" NOT NULL,
    "is_cancel" boolean DEFAULT false NOT NULL,
    "is_moving_time" boolean DEFAULT false NOT NULL,
    "cancel_date" timestamp with time zone,
    "cancel_by" "uuid",
    "cancel_reason" "text",
    "changes_by" "uuid",
    "changes_from_time" timestamp with time zone,
    "changes_to_time" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "order_items_duration_minutes_check" CHECK ((("duration_minutes" >= 0) AND ("duration_minutes" <= 1439))),
    CONSTRAINT "order_items_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "order_items_service_xor_combo" CHECK (("num_nonnulls"("service_id", "combo_id") = 1)),
    CONSTRAINT "order_items_status_check" CHECK (("status" = ANY (ARRAY['PENDING'::"text", 'PROCESSING'::"text", 'CONFIRMED'::"text", 'CANCEL'::"text"])))
);


ALTER TABLE "public"."order_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."orders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "phone_number" "text" NOT NULL,
    "pet_num" integer,
    "scheduled_at" timestamp with time zone,
    "user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "orders_pet_num_check" CHECK (("pet_num" >= 0))
);


ALTER TABLE "public"."orders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "invoice_id" "uuid" NOT NULL,
    "method" "text" NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    "bank_ref" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "payments_amount_check" CHECK (("amount" > (0)::numeric)),
    CONSTRAINT "payments_method_check" CHECK (("method" = ANY (ARRAY['cash'::"text", 'transfer'::"text", 'card'::"text", 'cod'::"text"])))
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."permissions" (
    "name" "text" NOT NULL,
    "methods" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "module" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "permissions_methods_valid" CHECK (("methods" <@ ARRAY['CREATE'::"text", 'VIEW'::"text", 'DELETE'::"text", 'UPDATE'::"text", 'IMPORT'::"text", 'EXPORT'::"text", 'SETTING'::"text", 'ALL'::"text"]))
);


ALTER TABLE "public"."permissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_owners" (
    "pet_id" "uuid" NOT NULL,
    "customer_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'primary'::"text" NOT NULL,
    "from_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "to_date" "date",
    CONSTRAINT "pet_owners_check" CHECK ((("to_date" IS NULL) OR ("to_date" >= "from_date"))),
    CONSTRAINT "pet_owners_role_check" CHECK (("role" = ANY (ARRAY['primary'::"text", 'co_owner'::"text"])))
);


ALTER TABLE "public"."pet_owners" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_weight_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "weight_kg" numeric(6,2) NOT NULL,
    "measured_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "note" "text",
    "created_by" "uuid" DEFAULT "auth"."uid"(),
    CONSTRAINT "pet_weight_logs_weight_kg_check" CHECK (("weight_kg" > (0)::numeric))
);


ALTER TABLE "public"."pet_weight_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "species_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "breed" "text",
    "sex" "text" DEFAULT 'unknown'::"text" NOT NULL,
    "neutered" boolean DEFAULT false NOT NULL,
    "birth_date" "date",
    "microchip" "text",
    "photo_url" "text",
    "allergies" "text",
    "behavior_notes" "text",
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "created_by" "uuid" DEFAULT "auth"."uid"(),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "deceased_on" "date",
    "photo_path" "text",
    "deceased_note" "text",
    CONSTRAINT "pets_name_check" CHECK (("length"("btrim"("name")) > 0)),
    CONSTRAINT "pets_sex_check" CHECK (("sex" = ANY (ARRAY['male'::"text", 'female'::"text", 'unknown'::"text"]))),
    CONSTRAINT "pets_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'deceased'::"text", 'archived'::"text"])))
);


ALTER TABLE "public"."pets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."species" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "icon" "text",
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."species" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."weight_brackets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "species_id" "uuid" NOT NULL,
    "label" "text" NOT NULL,
    "min_kg" numeric(6,2) NOT NULL,
    "max_kg" numeric(6,2),
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "weight_brackets_label_check" CHECK (("length"("btrim"("label")) > 0)),
    CONSTRAINT "weight_brackets_min_kg_check" CHECK (("min_kg" >= (0)::numeric)),
    CONSTRAINT "weight_brackets_range_check" CHECK ((("max_kg" IS NULL) OR ("max_kg" > "min_kg")))
);


ALTER TABLE "public"."weight_brackets" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."pet_overview" WITH ("security_invoker"='true') AS
 SELECT "p"."id",
    "p"."name",
    "p"."species_id",
    "s"."name" AS "species_name",
    "s"."icon" AS "species_icon",
    "p"."breed",
    "p"."sex",
    "p"."neutered",
    "p"."birth_date",
    "p"."photo_url",
    "p"."allergies",
    "p"."behavior_notes",
    "p"."status",
    "p"."created_at",
    "w"."weight_kg",
    "w"."measured_at" AS "weight_measured_at",
    "b"."id" AS "bracket_id",
    "b"."label" AS "bracket_label",
    "o"."customer_id" AS "owner_id",
    "c"."full_name" AS "owner_name",
    "c"."phone" AS "owner_phone",
    ( SELECT "count"(*) AS "count"
           FROM "public"."pet_owners" "po"
          WHERE (("po"."pet_id" = "p"."id") AND ("po"."to_date" IS NULL))) AS "owner_count"
   FROM ((((("public"."pets" "p"
     JOIN "public"."species" "s" ON (("s"."id" = "p"."species_id")))
     LEFT JOIN LATERAL ( SELECT "l"."weight_kg",
            "l"."measured_at"
           FROM "public"."pet_weight_logs" "l"
          WHERE ("l"."pet_id" = "p"."id")
          ORDER BY "l"."measured_at" DESC
         LIMIT 1) "w" ON (true))
     LEFT JOIN "public"."weight_brackets" "b" ON ((("b"."species_id" = "p"."species_id") AND ("w"."weight_kg" >= "b"."min_kg") AND (("b"."max_kg" IS NULL) OR ("w"."weight_kg" < "b"."max_kg")))))
     LEFT JOIN LATERAL ( SELECT "po"."customer_id"
           FROM "public"."pet_owners" "po"
          WHERE (("po"."pet_id" = "p"."id") AND ("po"."to_date" IS NULL))
          ORDER BY ("po"."role" = 'primary'::"text") DESC, "po"."from_date"
         LIMIT 1) "o" ON (true))
     LEFT JOIN "public"."customers" "c" ON (("c"."id" = "o"."customer_id")));


ALTER VIEW "public"."pet_overview" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_service_combos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "origin_price" numeric(14,2),
    "price" numeric(14,2),
    "duration_minutes" integer,
    "mark_as_id" "text",
    "mark_start" timestamp with time zone,
    "mark_end" timestamp with time zone,
    "status" smallint DEFAULT 1 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    CONSTRAINT "pet_service_combos_duration_minutes_check" CHECK ((("duration_minutes" >= 0) AND ("duration_minutes" <= 1439))),
    CONSTRAINT "pet_service_combos_mark_as_id_check" CHECK (("mark_as_id" = ANY (ARRAY['1'::"text", '2'::"text", '3'::"text", '4'::"text"]))),
    CONSTRAINT "pet_service_combos_origin_price_check" CHECK (("origin_price" >= (0)::numeric)),
    CONSTRAINT "pet_service_combos_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "pet_service_combos_status_check" CHECK (("status" = ANY (ARRAY[1, 2])))
);


ALTER TABLE "public"."pet_service_combos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_service_prices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "species_id" "uuid" NOT NULL,
    "service_id" "uuid" NOT NULL,
    "price" numeric(14,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "bracket_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    CONSTRAINT "pet_service_prices_price_check" CHECK (("price" >= (0)::numeric))
);


ALTER TABLE "public"."pet_service_prices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pet_services" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "type" "text",
    "unit" "text",
    "general_price" numeric(14,2),
    "duration_minutes" integer,
    "is_show" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "category" "text" DEFAULT 'spa'::"text" NOT NULL,
    CONSTRAINT "pet_services_category_check" CHECK (("category" = ANY (ARRAY['spa'::"text", 'medical'::"text", 'other'::"text"]))),
    CONSTRAINT "pet_services_duration_minutes_check" CHECK ((("duration_minutes" >= 0) AND ("duration_minutes" <= 1439))),
    CONSTRAINT "pet_services_general_price_check" CHECK (("general_price" >= (0)::numeric)),
    CONSTRAINT "pet_services_type_check" CHECK (("type" = ANY (ARRAY['all'::"text", 'by_weight'::"text"]))),
    CONSTRAINT "pet_services_unit_check" CHECK (("unit" = ANY (ARRAY['unit1'::"text", 'unit2'::"text"])))
);


ALTER TABLE "public"."pet_services" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_attribute_values" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "attribute_id" "uuid" NOT NULL,
    "value" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_attribute_values_value_check" CHECK (("length"("btrim"("value")) > 0))
);


ALTER TABLE "public"."product_attribute_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_attributes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_attributes_name_check" CHECK (("length"("btrim"("name")) > 0))
);


ALTER TABLE "public"."product_attributes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_branch_prices" (
    "product_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "price" numeric(14,2) NOT NULL,
    "updated_by" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_branch_prices_price_check" CHECK (("price" >= (0)::numeric))
);


ALTER TABLE "public"."product_branch_prices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_brands" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "image_url" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_brands_name_check" CHECK (("length"("btrim"("name")) > 0))
);


ALTER TABLE "public"."product_brands" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "parent_id" "uuid",
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "image_url" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_categories_name_check" CHECK (("length"("btrim"("name")) > 0)),
    CONSTRAINT "product_categories_not_own_parent" CHECK (("parent_id" IS DISTINCT FROM "id"))
);


ALTER TABLE "public"."product_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_group_attributes" (
    "group_id" "uuid" NOT NULL,
    "attribute_id" "uuid" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."product_group_attributes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "image_url" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "category_id" "uuid",
    "brand_id" "uuid",
    "clinic_only" boolean DEFAULT false NOT NULL,
    CONSTRAINT "product_groups_name_check" CHECK (("length"("btrim"("name")) > 0))
);


ALTER TABLE "public"."product_groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_images" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "url" "text" NOT NULL,
    "storage_path" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_images_url_check" CHECK (("length"("btrim"("url")) > 0))
);


ALTER TABLE "public"."product_images" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_imports" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "file_name" "text",
    "row_count" integer DEFAULT 0 NOT NULL,
    "created_count" integer DEFAULT 0 NOT NULL,
    "updated_count" integer DEFAULT 0 NOT NULL,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."product_imports" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_units" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "factor" numeric(12,2) NOT NULL,
    "barcode" "text",
    "price" numeric(14,2),
    "for_sale" boolean DEFAULT true NOT NULL,
    "for_purchase" boolean DEFAULT false NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "product_units_factor_check" CHECK (("factor" > (1)::numeric)),
    CONSTRAINT "product_units_name_check" CHECK (("length"("btrim"("name")) > 0)),
    CONSTRAINT "product_units_price_check" CHECK (("price" >= (0)::numeric))
);


ALTER TABLE "public"."product_units" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_variant_values" (
    "product_id" "uuid" NOT NULL,
    "attribute_id" "uuid" NOT NULL,
    "value_id" "uuid" NOT NULL
);


ALTER TABLE "public"."product_variant_values" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "sku" "text",
    "barcode" "text",
    "unit" "text" DEFAULT 'cái'::"text" NOT NULL,
    "price" numeric(14,2) DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "track_stock" boolean DEFAULT true NOT NULL,
    "group_id" "uuid" NOT NULL,
    "image_url" "text",
    "sort_order" integer DEFAULT 0 NOT NULL,
    "option_key" "text" DEFAULT ''::"text" NOT NULL,
    "weight_g" integer,
    "ship_policy" "text" DEFAULT 'shippable'::"text" NOT NULL,
    CONSTRAINT "products_price_check" CHECK (("price" >= (0)::numeric)),
    CONSTRAINT "products_ship_policy_check" CHECK (("ship_policy" = ANY (ARRAY['shippable'::"text", 'in_store_only'::"text"]))),
    CONSTRAINT "products_weight_g_check" CHECK ((("weight_g" IS NULL) OR (("weight_g" >= 1) AND ("weight_g" <= 50000))))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."role_permissions" (
    "role" "text" NOT NULL,
    "permission" "text" NOT NULL,
    "methods" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    CONSTRAINT "role_permissions_methods_valid" CHECK (("methods" <@ ARRAY['CREATE'::"text", 'VIEW'::"text", 'DELETE'::"text", 'UPDATE'::"text", 'IMPORT'::"text", 'EXPORT'::"text", 'SETTING'::"text", 'ALL'::"text"]))
);


ALTER TABLE "public"."role_permissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "name" "text" NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_system" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales_return_lines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "return_id" "uuid" NOT NULL,
    "invoice_line_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "qty" numeric(10,2) NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    CONSTRAINT "sales_return_lines_amount_check" CHECK (("amount" >= (0)::numeric)),
    CONSTRAINT "sales_return_lines_qty_check" CHECK (("qty" > (0)::numeric))
);


ALTER TABLE "public"."sales_return_lines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales_returns" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "invoice_id" "uuid" NOT NULL,
    "shift_id" "uuid" NOT NULL,
    "refund_method" "text" NOT NULL,
    "refund_amount" numeric(14,2) NOT NULL,
    "reason" "text" NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_by_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sales_returns_refund_amount_check" CHECK (("refund_amount" >= (0)::numeric)),
    CONSTRAINT "sales_returns_refund_method_check" CHECK (("refund_method" = ANY (ARRAY['cash'::"text", 'transfer'::"text"])))
);


ALTER TABLE "public"."sales_returns" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."service_providers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "phone" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."service_providers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."service_species" (
    "service_id" "uuid" NOT NULL,
    "species_id" "uuid" NOT NULL
);


ALTER TABLE "public"."service_species" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_order_events" (
    "id" bigint NOT NULL,
    "order_id" "uuid" NOT NULL,
    "status" "text" NOT NULL,
    "note" "text",
    "actor_id" "uuid",
    "actor_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shop_order_events" OWNER TO "postgres";


ALTER TABLE "public"."shop_order_events" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."shop_order_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."shop_order_lines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "order_id" "uuid" NOT NULL,
    "line_no" integer NOT NULL,
    "product_id" "uuid" NOT NULL,
    "unit_id" "uuid",
    "unit_factor" numeric(12,2) DEFAULT 1 NOT NULL,
    "name" "text" NOT NULL,
    "unit" "text",
    "image_url" "text",
    "qty" numeric(10,2) NOT NULL,
    "unit_price" numeric(14,2) NOT NULL,
    "amount" numeric(14,2) NOT NULL,
    CONSTRAINT "shop_order_lines_qty_check" CHECK ((("qty" > (0)::numeric) AND ("qty" <= (99)::numeric))),
    CONSTRAINT "shop_order_lines_unit_factor_check" CHECK (("unit_factor" >= (1)::numeric)),
    CONSTRAINT "shop_order_lines_unit_price_check" CHECK (("unit_price" >= (0)::numeric))
);


ALTER TABLE "public"."shop_order_lines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_settings" (
    "id" boolean DEFAULT true NOT NULL,
    "online_branch_id" "uuid" NOT NULL,
    "allow_cod" boolean DEFAULT true NOT NULL,
    "allow_pickup" boolean DEFAULT true NOT NULL,
    "cod_max" numeric(14,0) DEFAULT 10000000 NOT NULL,
    "default_weight_g" integer DEFAULT 500 NOT NULL,
    "flat_shipping_fee" numeric(14,0) DEFAULT 30000 NOT NULL,
    "free_ship_from" numeric(14,0),
    "ghn_from_province_id" integer,
    "ghn_from_district_id" integer,
    "ghn_from_ward_code" "text",
    "from_address_text" "text",
    "pickup_address" "text",
    "pickup_note" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "shop_settings_cod_max_check" CHECK (("cod_max" > (0)::numeric)),
    CONSTRAINT "shop_settings_default_weight_g_check" CHECK (("default_weight_g" > 0)),
    CONSTRAINT "shop_settings_flat_shipping_fee_check" CHECK (("flat_shipping_fee" >= (0)::numeric)),
    CONSTRAINT "shop_settings_free_ship_from_check" CHECK (("free_ship_from" > (0)::numeric)),
    CONSTRAINT "shop_settings_id_check" CHECK ("id")
);


ALTER TABLE "public"."shop_settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."spa_resources" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "spa_resources_name_check" CHECK (("length"("btrim"("name")) > 0))
);


ALTER TABLE "public"."spa_resources" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_branches" (
    "user_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "role" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "does_services" boolean DEFAULT false NOT NULL,
    CONSTRAINT "staff_branches_role_check" CHECK (("role" <> 'customer'::"text"))
);


ALTER TABLE "public"."staff_branches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_document_lines" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "document_id" "uuid" NOT NULL,
    "line_no" integer NOT NULL,
    "product_id" "uuid" NOT NULL,
    "lot_id" "uuid",
    "lot_no" "text" DEFAULT ''::"text" NOT NULL,
    "expiry_date" "date",
    "qty" numeric(12,2) DEFAULT 0 NOT NULL,
    "unit_cost" numeric(14,2) DEFAULT 0 NOT NULL,
    "system_qty" numeric(12,2),
    "counted_qty" numeric(12,2),
    "note" "text",
    "unit_id" "uuid",
    "unit_name" "text",
    "unit_factor" numeric(12,2) DEFAULT 1 NOT NULL,
    "entered_qty" numeric(12,2),
    "entered_cost" numeric(14,2),
    CONSTRAINT "stock_document_lines_counted_qty_check" CHECK (("counted_qty" >= (0)::numeric)),
    CONSTRAINT "stock_document_lines_unit_cost_check" CHECK (("unit_cost" >= (0)::numeric)),
    CONSTRAINT "stock_document_lines_unit_factor_check" CHECK (("unit_factor" > (0)::numeric))
);


ALTER TABLE "public"."stock_document_lines" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_documents" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "doc_type" "text" NOT NULL,
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "supplier_id" "uuid",
    "supplier_ref" "text",
    "note" "text",
    "total_cost" numeric(16,2) DEFAULT 0 NOT NULL,
    "created_by" "uuid" NOT NULL,
    "created_by_name" "text",
    "posted_by" "uuid",
    "posted_by_name" "text",
    "posted_at" timestamp with time zone,
    "cancelled_by" "uuid",
    "cancelled_by_name" "text",
    "cancelled_at" timestamp with time zone,
    "cancel_reason" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "stock_documents_check" CHECK ((("status" <> 'posted'::"text") OR ("posted_at" IS NOT NULL))),
    CONSTRAINT "stock_documents_check1" CHECK ((("status" = 'cancelled'::"text") = ("cancelled_at" IS NOT NULL))),
    CONSTRAINT "stock_documents_check2" CHECK ((("supplier_id" IS NULL) OR ("doc_type" = 'receipt'::"text"))),
    CONSTRAINT "stock_documents_doc_type_check" CHECK (("doc_type" = ANY (ARRAY['receipt'::"text", 'writeoff'::"text", 'count'::"text"]))),
    CONSTRAINT "stock_documents_status_check" CHECK (("status" = ANY (ARRAY['draft'::"text", 'posted'::"text", 'cancelled'::"text"])))
);


ALTER TABLE "public"."stock_documents" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_lots" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "lot_no" "text" DEFAULT ''::"text" NOT NULL,
    "expiry_date" "date",
    "unit_cost" numeric(14,2) DEFAULT 0 NOT NULL,
    "qty_on_hand" numeric(12,2) DEFAULT 0 NOT NULL,
    "received_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "stock_lots_qty_on_hand_check" CHECK (("qty_on_hand" >= (0)::numeric)),
    CONSTRAINT "stock_lots_unit_cost_check" CHECK (("unit_cost" >= (0)::numeric))
);


ALTER TABLE "public"."stock_lots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_movements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "lot_id" "uuid" NOT NULL,
    "qty" numeric(12,2) NOT NULL,
    "unit_cost" numeric(14,2) NOT NULL,
    "reason" "text" NOT NULL,
    "balance_after" numeric(12,2) NOT NULL,
    "document_id" "uuid",
    "document_line_id" "uuid",
    "invoice_id" "uuid",
    "invoice_line_id" "uuid",
    "return_id" "uuid",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "stock_movements_qty_check" CHECK (("qty" <> (0)::numeric)),
    CONSTRAINT "stock_movements_reason_check" CHECK (("reason" = ANY (ARRAY['receipt'::"text", 'receipt_cancel'::"text", 'sale'::"text", 'sale_cancel'::"text", 'return'::"text", 'writeoff'::"text", 'count'::"text"])))
);


ALTER TABLE "public"."stock_movements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_thresholds" (
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "min_qty" numeric(12,2) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "stock_thresholds_min_qty_check" CHECK (("min_qty" > (0)::numeric))
);


ALTER TABLE "public"."stock_thresholds" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."suppliers" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "address" "text",
    "tax_code" "text",
    "note" "text",
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "suppliers_name_check" CHECK (("length"("btrim"("name")) > 0))
);


ALTER TABLE "public"."suppliers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" NOT NULL,
    "email" "text",
    "display_name" "text",
    "full_name" "text",
    "phone_number" "text",
    "photo_url" "text",
    "gender" "text",
    "address" "jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "role" "text" DEFAULT 'customer'::"text" NOT NULL,
    CONSTRAINT "users_gender_check" CHECK (("gender" = ANY (ARRAY['MALE'::"text", 'FEMALE'::"text", 'OTHER'::"text"])))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vaccinations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pet_id" "uuid" NOT NULL,
    "vaccine_type_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "dose_no" integer DEFAULT 1 NOT NULL,
    "given_on" "date" NOT NULL,
    "visit_id" "uuid",
    "visit_item_id" "uuid",
    "lot_id" "uuid",
    "lot_no" "text",
    "expiry_date" "date",
    "is_external" boolean DEFAULT false NOT NULL,
    "external_place" "text",
    "vet_name" "text",
    "next_due_on" "date",
    "reminded_at" timestamp with time zone,
    "reminded_by" "uuid",
    "remind_note" "text",
    "voided_at" timestamp with time zone,
    "void_reason" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "vaccinations_dose_no_check" CHECK (("dose_no" > 0)),
    CONSTRAINT "vaccinations_origin" CHECK ((("is_external" AND ("branch_id" IS NULL) AND ("visit_id" IS NULL)) OR ((NOT "is_external") AND ("branch_id" IS NOT NULL))))
);


ALTER TABLE "public"."vaccinations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vaccine_types" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "kind" "text" DEFAULT 'vaccine'::"text" NOT NULL,
    "species_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    "product_id" "uuid",
    "series_doses" integer DEFAULT 1 NOT NULL,
    "series_interval_days" integer,
    "booster_interval_days" integer,
    "min_age_weeks" integer,
    "is_active" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "vaccine_types_booster_interval_days_check" CHECK (("booster_interval_days" > 0)),
    CONSTRAINT "vaccine_types_kind_check" CHECK (("kind" = ANY (ARRAY['vaccine'::"text", 'deworm'::"text", 'other'::"text"]))),
    CONSTRAINT "vaccine_types_min_age_weeks_check" CHECK (("min_age_weeks" >= 0)),
    CONSTRAINT "vaccine_types_name_check" CHECK (("length"("btrim"("name")) > 0)),
    CONSTRAINT "vaccine_types_series_doses_check" CHECK ((("series_doses" >= 1) AND ("series_doses" <= 10))),
    CONSTRAINT "vaccine_types_series_gap" CHECK ((("series_doses" = 1) OR ("series_interval_days" IS NOT NULL))),
    CONSTRAINT "vaccine_types_series_interval_days_check" CHECK (("series_interval_days" > 0))
);


ALTER TABLE "public"."vaccine_types" OWNER TO "postgres";


ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_appointment_id_line_no_key" UNIQUE ("appointment_id", "line_no");



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_resource_no_overlap" EXCLUDE USING "gist" ("resource_id" WITH =, "tstzrange"("start_at", "end_at", '[)'::"text") WITH &&) WHERE ((("resource_id" IS NOT NULL) AND ("status" <> 'cancelled'::"text")));



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_staff_no_overlap" EXCLUDE USING "gist" ("staff_id" WITH =, "tstzrange"("start_at", "end_at", '[)'::"text") WITH &&) WHERE ((("staff_id" IS NOT NULL) AND ("status" <> 'cancelled'::"text")));



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."banners"
    ADD CONSTRAINT "banners_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."boarding_care_logs"
    ADD CONSTRAINT "boarding_care_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."boarding_charges"
    ADD CONSTRAINT "boarding_charges_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."boarding_settings"
    ADD CONSTRAINT "boarding_settings_pkey" PRIMARY KEY ("branch_id");



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_kennel_no_overlap" EXCLUDE USING "gist" ("kennel_id" WITH =, "stay_id" WITH <>, "nights" WITH &&) WHERE (("status" = 'active'::"text"));



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_pet_no_overlap" EXCLUDE USING "gist" ("pet_id" WITH =, "nights" WITH &&) WHERE (("status" = 'active'::"text"));



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_stay_id_line_no_key" UNIQUE ("stay_id", "line_no");



ALTER TABLE ONLY "public"."boarding_stays"
    ADD CONSTRAINT "boarding_stays_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."boarding_stays"
    ADD CONSTRAINT "boarding_stays_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."branch_hours"
    ADD CONSTRAINT "branch_hours_pkey" PRIMARY KEY ("branch_id", "weekday");



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."combo_services"
    ADD CONSTRAINT "combo_services_pkey" PRIMARY KEY ("combo_id", "service_id");



ALTER TABLE ONLY "public"."combo_species"
    ADD CONSTRAINT "combo_species_pkey" PRIMARY KEY ("combo_id", "species_id");



ALTER TABLE ONLY "public"."customer_addresses"
    ADD CONSTRAINT "customer_addresses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_phone_digits_key" UNIQUE ("phone_digits");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_user_id_key" UNIQUE ("user_id");



ALTER TABLE ONLY "public"."diagnosis_terms"
    ADD CONSTRAINT "diagnosis_terms_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."doc_sequences"
    ADD CONSTRAINT "doc_sequences_pkey" PRIMARY KEY ("branch_id", "doc_type");



ALTER TABLE ONLY "public"."inpatient_doses"
    ADD CONSTRAINT "inpatient_doses_order_id_due_at_key" UNIQUE ("order_id", "due_at");



ALTER TABLE ONLY "public"."inpatient_doses"
    ADD CONSTRAINT "inpatient_doses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inpatient_order_changes"
    ADD CONSTRAINT "inpatient_order_changes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_invoice_id_line_no_key" UNIQUE ("invoice_id", "line_no");



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kennel_type_prices"
    ADD CONSTRAINT "kennel_type_prices_key" UNIQUE NULLS NOT DISTINCT ("kennel_type_id", "branch_id");



ALTER TABLE ONLY "public"."kennel_type_prices"
    ADD CONSTRAINT "kennel_type_prices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kennel_types"
    ADD CONSTRAINT "kennel_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."kennels"
    ADD CONSTRAINT "kennels_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_addenda"
    ADD CONSTRAINT "medical_addenda_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_attachments"
    ADD CONSTRAINT "medical_attachments_file_path_key" UNIQUE ("file_path");



ALTER TABLE ONLY "public"."medical_attachments"
    ADD CONSTRAINT "medical_attachments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_diagnoses"
    ADD CONSTRAINT "medical_diagnoses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_settings"
    ADD CONSTRAINT "medical_settings_pkey" PRIMARY KEY ("branch_id");



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."permissions"
    ADD CONSTRAINT "permissions_pkey" PRIMARY KEY ("name");



ALTER TABLE ONLY "public"."pet_owners"
    ADD CONSTRAINT "pet_owners_pkey" PRIMARY KEY ("pet_id", "customer_id");



ALTER TABLE ONLY "public"."pet_service_combos"
    ADD CONSTRAINT "pet_service_combos_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."pet_service_combos"
    ADD CONSTRAINT "pet_service_combos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pet_service_prices"
    ADD CONSTRAINT "pet_service_prices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pet_service_prices"
    ADD CONSTRAINT "pet_service_prices_unique" UNIQUE NULLS NOT DISTINCT ("species_id", "service_id", "bracket_id", "branch_id");



ALTER TABLE ONLY "public"."pet_services"
    ADD CONSTRAINT "pet_services_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."pet_services"
    ADD CONSTRAINT "pet_services_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pet_weight_logs"
    ADD CONSTRAINT "pet_weight_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_microchip_key" UNIQUE ("microchip");



ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_attribute_values"
    ADD CONSTRAINT "product_attribute_values_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_attributes"
    ADD CONSTRAINT "product_attributes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_branch_prices"
    ADD CONSTRAINT "product_branch_prices_pkey" PRIMARY KEY ("product_id", "branch_id");



ALTER TABLE ONLY "public"."product_brands"
    ADD CONSTRAINT "product_brands_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_categories"
    ADD CONSTRAINT "product_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_group_attributes"
    ADD CONSTRAINT "product_group_attributes_pkey" PRIMARY KEY ("group_id", "attribute_id");



ALTER TABLE ONLY "public"."product_groups"
    ADD CONSTRAINT "product_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_imports"
    ADD CONSTRAINT "product_imports_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_units"
    ADD CONSTRAINT "product_units_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_variant_values"
    ADD CONSTRAINT "product_variant_values_pkey" PRIMARY KEY ("product_id", "attribute_id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_barcode_key" UNIQUE ("barcode");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_group_option_key" UNIQUE ("group_id", "option_key") DEFERRABLE INITIALLY DEFERRED;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_sku_key" UNIQUE ("sku");



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_pkey" PRIMARY KEY ("role", "permission");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("name");



ALTER TABLE ONLY "public"."sales_return_lines"
    ADD CONSTRAINT "sales_return_lines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."service_providers"
    ADD CONSTRAINT "service_providers_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."service_providers"
    ADD CONSTRAINT "service_providers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."service_species"
    ADD CONSTRAINT "service_species_pkey" PRIMARY KEY ("service_id", "species_id");



ALTER TABLE ONLY "public"."shop_order_events"
    ADD CONSTRAINT "shop_order_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shop_order_lines"
    ADD CONSTRAINT "shop_order_lines_order_id_line_no_key" UNIQUE ("order_id", "line_no");



ALTER TABLE ONLY "public"."shop_order_lines"
    ADD CONSTRAINT "shop_order_lines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_client_ref_key" UNIQUE ("client_ref");



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_invoice_id_key" UNIQUE ("invoice_id");



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."shop_settings"
    ADD CONSTRAINT "shop_settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."spa_resources"
    ADD CONSTRAINT "spa_resources_branch_id_name_key" UNIQUE ("branch_id", "name");



ALTER TABLE ONLY "public"."spa_resources"
    ADD CONSTRAINT "spa_resources_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."species"
    ADD CONSTRAINT "species_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."species"
    ADD CONSTRAINT "species_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_branches"
    ADD CONSTRAINT "staff_branches_pkey" PRIMARY KEY ("user_id", "branch_id");



ALTER TABLE ONLY "public"."stock_document_lines"
    ADD CONSTRAINT "stock_document_lines_document_id_line_no_key" UNIQUE ("document_id", "line_no");



ALTER TABLE ONLY "public"."stock_document_lines"
    ADD CONSTRAINT "stock_document_lines_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_documents"
    ADD CONSTRAINT "stock_documents_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."stock_documents"
    ADD CONSTRAINT "stock_documents_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_lots"
    ADD CONSTRAINT "stock_lots_identity_key" UNIQUE NULLS NOT DISTINCT ("branch_id", "product_id", "lot_no", "expiry_date");



ALTER TABLE ONLY "public"."stock_lots"
    ADD CONSTRAINT "stock_lots_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_thresholds"
    ADD CONSTRAINT "stock_thresholds_pkey" PRIMARY KEY ("branch_id", "product_id");



ALTER TABLE ONLY "public"."suppliers"
    ADD CONSTRAINT "suppliers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_display_name_key" UNIQUE ("display_name");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_phone_number_key" UNIQUE ("phone_number");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vaccine_types"
    ADD CONSTRAINT "vaccine_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."weight_brackets"
    ADD CONSTRAINT "weight_brackets_no_overlap" EXCLUDE USING "gist" ("species_id" WITH =, "numrange"("min_kg", "max_kg", '[)'::"text") WITH &&) DEFERRABLE INITIALLY DEFERRED;



ALTER TABLE ONLY "public"."weight_brackets"
    ADD CONSTRAINT "weight_brackets_pkey" PRIMARY KEY ("id");



CREATE INDEX "appointment_items_appointment_idx" ON "public"."appointment_items" USING "btree" ("appointment_id");



CREATE INDEX "appointment_items_branch_start_idx" ON "public"."appointment_items" USING "btree" ("branch_id", "start_at");



CREATE INDEX "appointment_items_invoice_line_idx" ON "public"."appointment_items" USING "btree" ("invoice_line_id") WHERE ("invoice_line_id" IS NOT NULL);



CREATE INDEX "appointment_items_pet_idx" ON "public"."appointment_items" USING "btree" ("pet_id") WHERE ("pet_id" IS NOT NULL);



CREATE INDEX "appointment_items_staff_idx" ON "public"."appointment_items" USING "btree" ("staff_id") WHERE ("staff_id" IS NOT NULL);



CREATE INDEX "appointments_branch_start_idx" ON "public"."appointments" USING "btree" ("branch_id", "start_at" DESC);



CREATE INDEX "appointments_customer_idx" ON "public"."appointments" USING "btree" ("customer_id");



CREATE INDEX "boarding_care_logs_pet_idx" ON "public"."boarding_care_logs" USING "btree" ("stay_pet_id", "logged_at" DESC);



CREATE INDEX "boarding_care_logs_stay_idx" ON "public"."boarding_care_logs" USING "btree" ("stay_id", "logged_at" DESC);



CREATE INDEX "boarding_charges_open_idx" ON "public"."boarding_charges" USING "btree" ("branch_id") WHERE ("invoice_line_id" IS NULL);



CREATE INDEX "boarding_charges_stay_idx" ON "public"."boarding_charges" USING "btree" ("stay_id");



CREATE INDEX "boarding_stay_pets_branch_nights_idx" ON "public"."boarding_stay_pets" USING "gist" ("branch_id", "nights");



CREATE INDEX "boarding_stay_pets_kennel_idx" ON "public"."boarding_stay_pets" USING "btree" ("kennel_id");



CREATE INDEX "boarding_stay_pets_pet_idx" ON "public"."boarding_stay_pets" USING "btree" ("pet_id");



CREATE INDEX "boarding_stay_pets_stay_idx" ON "public"."boarding_stay_pets" USING "btree" ("stay_id");



CREATE INDEX "boarding_stays_branch_in_idx" ON "public"."boarding_stays" USING "btree" ("branch_id", "planned_in_at" DESC);



CREATE INDEX "boarding_stays_customer_idx" ON "public"."boarding_stays" USING "btree" ("customer_id");



CREATE UNIQUE INDEX "boarding_stays_visit_key" ON "public"."boarding_stays" USING "btree" ("visit_id") WHERE (("kind" = 'inpatient'::"text") AND ("status" = ANY (ARRAY['booked'::"text", 'checked_in'::"text"])));



CREATE INDEX "bookings_created_idx" ON "public"."bookings" USING "btree" ("created_at" DESC);



CREATE INDEX "bookings_status_scheduled_idx" ON "public"."bookings" USING "btree" ("status", "scheduled_at" DESC);



CREATE INDEX "bookings_user_idx" ON "public"."bookings" USING "btree" ("user_id");



CREATE INDEX "cash_shifts_branch_opened_idx" ON "public"."cash_shifts" USING "btree" ("branch_id", "opened_at" DESC);



CREATE UNIQUE INDEX "cash_shifts_one_open_idx" ON "public"."cash_shifts" USING "btree" ("branch_id", "opened_by") WHERE ("status" = 'open'::"text");



CREATE INDEX "combo_services_service_idx" ON "public"."combo_services" USING "btree" ("service_id");



CREATE INDEX "combo_species_species_idx" ON "public"."combo_species" USING "btree" ("species_id");



CREATE UNIQUE INDEX "customer_addresses_one_default" ON "public"."customer_addresses" USING "btree" ("user_id") WHERE "is_default";



CREATE INDEX "customer_addresses_user_idx" ON "public"."customer_addresses" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "customers_search_idx" ON "public"."customers" USING "gin" ("lower"("public"."immutable_unaccent"((("full_name" || ' '::"text") || COALESCE("email", ''::"text")))) "extensions"."gin_trgm_ops");



CREATE UNIQUE INDEX "diagnosis_terms_name_key" ON "public"."diagnosis_terms" USING "btree" ("lower"("btrim"("name")));



CREATE INDEX "inpatient_doses_due_idx" ON "public"."inpatient_doses" USING "btree" ("due_at");



CREATE INDEX "inpatient_order_changes_order_idx" ON "public"."inpatient_order_changes" USING "btree" ("order_id", "changed_at" DESC);



CREATE INDEX "inpatient_orders_stay_idx" ON "public"."inpatient_orders" USING "btree" ("stay_id");



CREATE INDEX "inpatient_orders_visit_idx" ON "public"."inpatient_orders" USING "btree" ("visit_id");



CREATE INDEX "invoice_lines_combo_idx" ON "public"."invoice_lines" USING "btree" ("combo_id") WHERE ("combo_id" IS NOT NULL);



CREATE INDEX "invoice_lines_pet_idx" ON "public"."invoice_lines" USING "btree" ("pet_id") WHERE ("pet_id" IS NOT NULL);



CREATE INDEX "invoice_lines_product_idx" ON "public"."invoice_lines" USING "btree" ("product_id") WHERE ("product_id" IS NOT NULL);



CREATE INDEX "invoice_lines_service_idx" ON "public"."invoice_lines" USING "btree" ("service_id") WHERE ("service_id" IS NOT NULL);



CREATE INDEX "invoice_lines_unit_idx" ON "public"."invoice_lines" USING "btree" ("unit_id") WHERE ("unit_id" IS NOT NULL);



CREATE INDEX "invoices_branch_cancelled_idx" ON "public"."invoices" USING "btree" ("branch_id", "cancelled_at") WHERE ("cancelled_at" IS NOT NULL);



CREATE INDEX "invoices_branch_created_idx" ON "public"."invoices" USING "btree" ("branch_id", "created_at" DESC);



CREATE UNIQUE INDEX "invoices_client_ref_key" ON "public"."invoices" USING "btree" ("client_ref") WHERE ("client_ref" IS NOT NULL);



CREATE INDEX "invoices_customer_idx" ON "public"."invoices" USING "btree" ("customer_id") WHERE ("customer_id" IS NOT NULL);



CREATE INDEX "invoices_shift_idx" ON "public"."invoices" USING "btree" ("shift_id");



CREATE UNIQUE INDEX "kennel_types_name_key" ON "public"."kennel_types" USING "btree" ("lower"("btrim"("name")));



CREATE UNIQUE INDEX "kennels_branch_code_key" ON "public"."kennels" USING "btree" ("branch_id", "lower"("btrim"("code")));



CREATE INDEX "kennels_type_idx" ON "public"."kennels" USING "btree" ("kennel_type_id");



CREATE INDEX "medical_addenda_visit_idx" ON "public"."medical_addenda" USING "btree" ("visit_id", "created_at");



CREATE INDEX "medical_attachments_pet_idx" ON "public"."medical_attachments" USING "btree" ("pet_id", "created_at" DESC);



CREATE INDEX "medical_attachments_visit_idx" ON "public"."medical_attachments" USING "btree" ("visit_id", "created_at");



CREATE INDEX "medical_diagnoses_contagious_idx" ON "public"."medical_diagnoses" USING "btree" ("visit_id") WHERE "is_contagious";



CREATE INDEX "medical_diagnoses_visit_idx" ON "public"."medical_diagnoses" USING "btree" ("visit_id", "sort_order");



CREATE INDEX "medical_visit_items_invoice_idx" ON "public"."medical_visit_items" USING "btree" ("invoice_line_id") WHERE ("invoice_line_id" IS NOT NULL);



CREATE INDEX "medical_visit_items_product_idx" ON "public"."medical_visit_items" USING "btree" ("product_id") WHERE ("product_id" IS NOT NULL);



CREATE INDEX "medical_visit_items_visit_idx" ON "public"."medical_visit_items" USING "btree" ("visit_id", "created_at");



CREATE INDEX "medical_visits_branch_queue_idx" ON "public"."medical_visits" USING "btree" ("branch_id", "queue_date" DESC);



CREATE INDEX "medical_visits_customer_idx" ON "public"."medical_visits" USING "btree" ("customer_id");



CREATE INDEX "medical_visits_pet_idx" ON "public"."medical_visits" USING "btree" ("pet_id", "created_at" DESC);



CREATE UNIQUE INDEX "medical_visits_pet_open_key" ON "public"."medical_visits" USING "btree" ("pet_id") WHERE ("status" = ANY (ARRAY['waiting'::"text", 'in_progress'::"text"]));



CREATE UNIQUE INDEX "medical_visits_queue_key" ON "public"."medical_visits" USING "btree" ("branch_id", "queue_date", "queue_no");



CREATE INDEX "medical_visits_scheduled_idx" ON "public"."medical_visits" USING "btree" ("branch_id", "scheduled_at") WHERE ("status" = 'scheduled'::"text");



CREATE INDEX "medical_visits_status_idx" ON "public"."medical_visits" USING "btree" ("branch_id", "status");



CREATE INDEX "order_items_combo_idx" ON "public"."order_items" USING "btree" ("combo_id") WHERE ("combo_id" IS NOT NULL);



CREATE INDEX "order_items_order_idx" ON "public"."order_items" USING "btree" ("order_id");



CREATE INDEX "order_items_service_idx" ON "public"."order_items" USING "btree" ("service_id") WHERE ("service_id" IS NOT NULL);



CREATE INDEX "orders_created_idx" ON "public"."orders" USING "btree" ("created_at" DESC);



CREATE INDEX "orders_user_idx" ON "public"."orders" USING "btree" ("user_id");



CREATE INDEX "payments_invoice_idx" ON "public"."payments" USING "btree" ("invoice_id");



CREATE INDEX "pet_owners_customer_idx" ON "public"."pet_owners" USING "btree" ("customer_id");



CREATE UNIQUE INDEX "pet_owners_one_primary_idx" ON "public"."pet_owners" USING "btree" ("pet_id") WHERE (("role" = 'primary'::"text") AND ("to_date" IS NULL));



CREATE INDEX "pet_service_prices_bracket_idx" ON "public"."pet_service_prices" USING "btree" ("bracket_id");



CREATE INDEX "pet_service_prices_service_idx" ON "public"."pet_service_prices" USING "btree" ("service_id");



CREATE INDEX "pet_services_category_idx" ON "public"."pet_services" USING "btree" ("category");



CREATE INDEX "pet_weight_logs_pet_idx" ON "public"."pet_weight_logs" USING "btree" ("pet_id", "measured_at" DESC);



CREATE INDEX "pets_name_idx" ON "public"."pets" USING "btree" ("lower"("name"));



CREATE INDEX "pets_species_idx" ON "public"."pets" USING "btree" ("species_id");



CREATE UNIQUE INDEX "product_attribute_values_key" ON "public"."product_attribute_values" USING "btree" ("attribute_id", "lower"("btrim"("value")));



CREATE UNIQUE INDEX "product_attributes_name_key" ON "public"."product_attributes" USING "btree" ("lower"("btrim"("name")));



CREATE INDEX "product_branch_prices_branch_idx" ON "public"."product_branch_prices" USING "btree" ("branch_id");



CREATE UNIQUE INDEX "product_brands_name_key" ON "public"."product_brands" USING "btree" ("lower"("public"."immutable_unaccent"("btrim"("name"))));



CREATE UNIQUE INDEX "product_brands_slug_key" ON "public"."product_brands" USING "btree" ("slug");



CREATE UNIQUE INDEX "product_categories_name_key" ON "public"."product_categories" USING "btree" (COALESCE("parent_id", '00000000-0000-0000-0000-000000000000'::"uuid"), "lower"("public"."immutable_unaccent"("btrim"("name"))));



CREATE INDEX "product_categories_parent_idx" ON "public"."product_categories" USING "btree" ("parent_id") WHERE ("parent_id" IS NOT NULL);



CREATE UNIQUE INDEX "product_categories_slug_key" ON "public"."product_categories" USING "btree" ("slug");



CREATE INDEX "product_group_attributes_attribute_idx" ON "public"."product_group_attributes" USING "btree" ("attribute_id");



CREATE INDEX "product_groups_brand_idx" ON "public"."product_groups" USING "btree" ("brand_id") WHERE ("brand_id" IS NOT NULL);



CREATE INDEX "product_groups_category_idx" ON "public"."product_groups" USING "btree" ("category_id") WHERE ("category_id" IS NOT NULL);



CREATE UNIQUE INDEX "product_groups_name_key" ON "public"."product_groups" USING "btree" ("lower"("btrim"("name")));



CREATE INDEX "product_images_group_idx" ON "public"."product_images" USING "btree" ("group_id", "sort_order");



CREATE UNIQUE INDEX "product_images_group_url_key" ON "public"."product_images" USING "btree" ("group_id", "url");



CREATE UNIQUE INDEX "product_units_barcode_key" ON "public"."product_units" USING "btree" ("barcode") WHERE ("barcode" IS NOT NULL);



CREATE UNIQUE INDEX "product_units_name_key" ON "public"."product_units" USING "btree" ("product_id", "lower"("btrim"("name")));



CREATE INDEX "product_variant_values_value_idx" ON "public"."product_variant_values" USING "btree" ("value_id");



CREATE INDEX "products_group_idx" ON "public"."products" USING "btree" ("group_id", "sort_order");



CREATE INDEX "role_permissions_permission_idx" ON "public"."role_permissions" USING "btree" ("permission");



CREATE INDEX "sales_return_lines_invoice_line_idx" ON "public"."sales_return_lines" USING "btree" ("invoice_line_id");



CREATE INDEX "sales_return_lines_return_idx" ON "public"."sales_return_lines" USING "btree" ("return_id");



CREATE INDEX "sales_returns_branch_created_idx" ON "public"."sales_returns" USING "btree" ("branch_id", "created_at");



CREATE INDEX "sales_returns_invoice_idx" ON "public"."sales_returns" USING "btree" ("invoice_id");



CREATE INDEX "sales_returns_shift_idx" ON "public"."sales_returns" USING "btree" ("shift_id");



CREATE INDEX "service_species_species_idx" ON "public"."service_species" USING "btree" ("species_id");



CREATE INDEX "shop_order_events_order_idx" ON "public"."shop_order_events" USING "btree" ("order_id", "created_at");



CREATE INDEX "shop_order_lines_product_idx" ON "public"."shop_order_lines" USING "btree" ("product_id");



CREATE INDEX "shop_orders_branch_status_idx" ON "public"."shop_orders" USING "btree" ("branch_id", "status", "placed_at" DESC);



CREATE INDEX "shop_orders_user_idx" ON "public"."shop_orders" USING "btree" ("user_id", "placed_at" DESC);



CREATE INDEX "staff_branches_branch_idx" ON "public"."staff_branches" USING "btree" ("branch_id");



CREATE INDEX "staff_branches_role_idx" ON "public"."staff_branches" USING "btree" ("role");



CREATE INDEX "stock_document_lines_lot_idx" ON "public"."stock_document_lines" USING "btree" ("lot_id") WHERE ("lot_id" IS NOT NULL);



CREATE INDEX "stock_document_lines_product_idx" ON "public"."stock_document_lines" USING "btree" ("product_id");



CREATE INDEX "stock_document_lines_unit_idx" ON "public"."stock_document_lines" USING "btree" ("unit_id") WHERE ("unit_id" IS NOT NULL);



CREATE INDEX "stock_documents_branch_created_idx" ON "public"."stock_documents" USING "btree" ("branch_id", "created_at" DESC);



CREATE INDEX "stock_lots_fefo_idx" ON "public"."stock_lots" USING "btree" ("branch_id", "product_id", "expiry_date", "received_at") WHERE ("qty_on_hand" > (0)::numeric);



CREATE INDEX "stock_lots_product_idx" ON "public"."stock_lots" USING "btree" ("product_id");



CREATE INDEX "stock_movements_document_idx" ON "public"."stock_movements" USING "btree" ("document_id") WHERE ("document_id" IS NOT NULL);



CREATE INDEX "stock_movements_invoice_idx" ON "public"."stock_movements" USING "btree" ("invoice_id") WHERE ("invoice_id" IS NOT NULL);



CREATE INDEX "stock_movements_invoice_line_idx" ON "public"."stock_movements" USING "btree" ("invoice_line_id") WHERE ("invoice_line_id" IS NOT NULL);



CREATE INDEX "stock_movements_lot_idx" ON "public"."stock_movements" USING "btree" ("lot_id", "created_at");



CREATE INDEX "stock_movements_product_idx" ON "public"."stock_movements" USING "btree" ("branch_id", "product_id", "created_at" DESC);



CREATE INDEX "stock_movements_return_idx" ON "public"."stock_movements" USING "btree" ("return_id") WHERE ("return_id" IS NOT NULL);



CREATE INDEX "stock_movements_return_reason_idx" ON "public"."stock_movements" USING "btree" ("return_id") WHERE ("reason" = 'return'::"text");



CREATE INDEX "users_role_idx" ON "public"."users" USING "btree" ("role");



CREATE INDEX "vaccinations_due_idx" ON "public"."vaccinations" USING "btree" ("next_due_on") WHERE (("voided_at" IS NULL) AND ("next_due_on" IS NOT NULL));



CREATE INDEX "vaccinations_item_idx" ON "public"."vaccinations" USING "btree" ("visit_item_id") WHERE ("visit_item_id" IS NOT NULL);



CREATE INDEX "vaccinations_lot_idx" ON "public"."vaccinations" USING "btree" ("lot_id") WHERE ("lot_id" IS NOT NULL);



CREATE INDEX "vaccinations_pet_idx" ON "public"."vaccinations" USING "btree" ("pet_id", "given_on" DESC);



CREATE UNIQUE INDEX "vaccine_types_name_key" ON "public"."vaccine_types" USING "btree" ("lower"("btrim"("name")));



CREATE INDEX "vaccine_types_product_idx" ON "public"."vaccine_types" USING "btree" ("product_id");



CREATE INDEX "weight_brackets_species_idx" ON "public"."weight_brackets" USING "btree" ("species_id", "min_kg");



CREATE OR REPLACE TRIGGER "check_depth" BEFORE INSERT OR UPDATE OF "parent_id" ON "public"."product_categories" FOR EACH ROW EXECUTE FUNCTION "public"."product_categories_check_depth"();



CREATE OR REPLACE TRIGGER "customer_addresses_set_updated_at" BEFORE UPDATE ON "public"."customer_addresses" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "guard_user_columns" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."guard_user_columns"();



CREATE OR REPLACE TRIGGER "inpatient_doses_signed_lock" BEFORE INSERT OR DELETE OR UPDATE ON "public"."inpatient_doses" FOR EACH ROW EXECUTE FUNCTION "public"."inpatient_signed_lock"();



CREATE OR REPLACE TRIGGER "inpatient_orders_signed_lock" BEFORE INSERT OR DELETE OR UPDATE ON "public"."inpatient_orders" FOR EACH ROW EXECUTE FUNCTION "public"."inpatient_signed_lock"();



CREATE OR REPLACE TRIGGER "medical_addenda_frozen" BEFORE DELETE OR UPDATE ON "public"."medical_addenda" FOR EACH ROW EXECUTE FUNCTION "public"."medical_addenda_frozen"();



CREATE OR REPLACE TRIGGER "medical_diagnoses_lock" BEFORE INSERT OR DELETE OR UPDATE ON "public"."medical_diagnoses" FOR EACH ROW EXECUTE FUNCTION "public"."medical_diagnoses_lock"();



CREATE OR REPLACE TRIGGER "medical_visits_inpatient_guard" BEFORE UPDATE ON "public"."medical_visits" FOR EACH ROW EXECUTE FUNCTION "public"."medical_visits_inpatient_guard"();



CREATE OR REPLACE TRIGGER "medical_visits_lock" BEFORE UPDATE ON "public"."medical_visits" FOR EACH ROW EXECUTE FUNCTION "public"."medical_visits_lock"();



CREATE OR REPLACE TRIGGER "pets_deceased_after" AFTER UPDATE OF "status" ON "public"."pets" FOR EACH ROW WHEN ((("new"."status" = 'deceased'::"text") AND ("old"."status" IS DISTINCT FROM 'deceased'::"text"))) EXECUTE FUNCTION "public"."pets_deceased_after"();



CREATE OR REPLACE TRIGGER "pets_deceased_before" BEFORE UPDATE OF "status" ON "public"."pets" FOR EACH ROW EXECUTE FUNCTION "public"."pets_deceased_before"();



CREATE OR REPLACE TRIGGER "restock_on_cancel" AFTER UPDATE OF "status" ON "public"."invoices" FOR EACH ROW WHEN ((("old"."status" = ANY (ARRAY['paid'::"text", 'unpaid'::"text"])) AND ("new"."status" = 'cancelled'::"text"))) EXECUTE FUNCTION "public"."invoice_cancel_restock"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."appointment_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."appointments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."banners" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."boarding_settings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."boarding_stay_pets" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."boarding_stays" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."bookings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."branches" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."cash_shifts" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."customers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."diagnosis_terms" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."invoices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."kennel_type_prices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."kennel_types" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."kennels" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."medical_settings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."medical_visits" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."order_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."permissions" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."pet_service_combos" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."pet_service_prices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."pet_services" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."pets" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."product_brands" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."product_categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."product_groups" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."products" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."roles" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."service_providers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."spa_resources" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."species" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."staff_branches" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."stock_documents" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."stock_lots" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."stock_thresholds" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."suppliers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."vaccine_types" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "set_updated_at" BEFORE UPDATE ON "public"."weight_brackets" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "shop_orders_set_updated_at" BEFORE UPDATE ON "public"."shop_orders" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();



CREATE OR REPLACE TRIGGER "take_stock" AFTER INSERT ON "public"."invoice_lines" FOR EACH ROW WHEN (("new"."item_type" = 'product'::"text")) EXECUTE FUNCTION "public"."invoice_line_take_stock"();



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "public"."appointments"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_combo_id_fkey" FOREIGN KEY ("combo_id") REFERENCES "public"."pet_service_combos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_invoice_line_id_fkey" FOREIGN KEY ("invoice_line_id") REFERENCES "public"."invoice_lines"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_resource_id_fkey" FOREIGN KEY ("resource_id") REFERENCES "public"."spa_resources"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointment_items"
    ADD CONSTRAINT "appointment_items_staff_id_fkey" FOREIGN KEY ("staff_id") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."appointments"
    ADD CONSTRAINT "appointments_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_care_logs"
    ADD CONSTRAINT "boarding_care_logs_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_care_logs"
    ADD CONSTRAINT "boarding_care_logs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."boarding_care_logs"
    ADD CONSTRAINT "boarding_care_logs_stay_id_fkey" FOREIGN KEY ("stay_id") REFERENCES "public"."boarding_stays"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boarding_care_logs"
    ADD CONSTRAINT "boarding_care_logs_stay_pet_id_fkey" FOREIGN KEY ("stay_pet_id") REFERENCES "public"."boarding_stay_pets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boarding_charges"
    ADD CONSTRAINT "boarding_charges_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_charges"
    ADD CONSTRAINT "boarding_charges_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."boarding_charges"
    ADD CONSTRAINT "boarding_charges_invoice_line_id_fkey" FOREIGN KEY ("invoice_line_id") REFERENCES "public"."invoice_lines"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."boarding_charges"
    ADD CONSTRAINT "boarding_charges_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_charges"
    ADD CONSTRAINT "boarding_charges_stay_id_fkey" FOREIGN KEY ("stay_id") REFERENCES "public"."boarding_stays"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boarding_charges"
    ADD CONSTRAINT "boarding_charges_stay_pet_id_fkey" FOREIGN KEY ("stay_pet_id") REFERENCES "public"."boarding_stay_pets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boarding_settings"
    ADD CONSTRAINT "boarding_settings_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_kennel_id_fkey" FOREIGN KEY ("kennel_id") REFERENCES "public"."kennels"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_kennel_type_id_fkey" FOREIGN KEY ("kennel_type_id") REFERENCES "public"."kennel_types"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_stay_pets"
    ADD CONSTRAINT "boarding_stay_pets_stay_id_fkey" FOREIGN KEY ("stay_id") REFERENCES "public"."boarding_stays"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."boarding_stays"
    ADD CONSTRAINT "boarding_stays_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_stays"
    ADD CONSTRAINT "boarding_stays_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."boarding_stays"
    ADD CONSTRAINT "boarding_stays_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."boarding_stays"
    ADD CONSTRAINT "boarding_stays_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_cancel_by_fkey" FOREIGN KEY ("cancel_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_confirm_changed_by_fkey" FOREIGN KEY ("confirm_changed_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bookings"
    ADD CONSTRAINT "bookings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."branch_hours"
    ADD CONSTRAINT "branch_hours_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_closed_by_fkey" FOREIGN KEY ("closed_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."cash_shifts"
    ADD CONSTRAINT "cash_shifts_opened_by_fkey" FOREIGN KEY ("opened_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."combo_services"
    ADD CONSTRAINT "combo_services_combo_id_fkey" FOREIGN KEY ("combo_id") REFERENCES "public"."pet_service_combos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."combo_services"
    ADD CONSTRAINT "combo_services_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."combo_species"
    ADD CONSTRAINT "combo_species_combo_id_fkey" FOREIGN KEY ("combo_id") REFERENCES "public"."pet_service_combos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."combo_species"
    ADD CONSTRAINT "combo_species_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."customer_addresses"
    ADD CONSTRAINT "customer_addresses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."doc_sequences"
    ADD CONSTRAINT "doc_sequences_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inpatient_doses"
    ADD CONSTRAINT "inpatient_doses_given_by_fkey" FOREIGN KEY ("given_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inpatient_doses"
    ADD CONSTRAINT "inpatient_doses_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."inpatient_orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inpatient_order_changes"
    ADD CONSTRAINT "inpatient_order_changes_changed_by_fkey" FOREIGN KEY ("changed_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inpatient_order_changes"
    ADD CONSTRAINT "inpatient_order_changes_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."inpatient_orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inpatient_order_changes"
    ADD CONSTRAINT "inpatient_order_changes_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "public"."medical_visit_items"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_stay_id_fkey" FOREIGN KEY ("stay_id") REFERENCES "public"."boarding_stays"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_stay_pet_id_fkey" FOREIGN KEY ("stay_pet_id") REFERENCES "public"."boarding_stay_pets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inpatient_orders"
    ADD CONSTRAINT "inpatient_orders_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_combo_id_fkey" FOREIGN KEY ("combo_id") REFERENCES "public"."pet_service_combos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_lot_id_fkey" FOREIGN KEY ("lot_id") REFERENCES "public"."stock_lots"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoice_lines"
    ADD CONSTRAINT "invoice_lines_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."product_units"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_cancelled_by_fkey" FOREIGN KEY ("cancelled_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."invoices"
    ADD CONSTRAINT "invoices_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."kennel_type_prices"
    ADD CONSTRAINT "kennel_type_prices_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kennel_type_prices"
    ADD CONSTRAINT "kennel_type_prices_kennel_type_id_fkey" FOREIGN KEY ("kennel_type_id") REFERENCES "public"."kennel_types"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."kennels"
    ADD CONSTRAINT "kennels_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."kennels"
    ADD CONSTRAINT "kennels_kennel_type_id_fkey" FOREIGN KEY ("kennel_type_id") REFERENCES "public"."kennel_types"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_addenda"
    ADD CONSTRAINT "medical_addenda_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_addenda"
    ADD CONSTRAINT "medical_addenda_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medical_attachments"
    ADD CONSTRAINT "medical_attachments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_attachments"
    ADD CONSTRAINT "medical_attachments_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_attachments"
    ADD CONSTRAINT "medical_attachments_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medical_diagnoses"
    ADD CONSTRAINT "medical_diagnoses_term_id_fkey" FOREIGN KEY ("term_id") REFERENCES "public"."diagnosis_terms"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_diagnoses"
    ADD CONSTRAINT "medical_diagnoses_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medical_settings"
    ADD CONSTRAINT "medical_settings_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medical_settings"
    ADD CONSTRAINT "medical_settings_exam_service_id_fkey" FOREIGN KEY ("exam_service_id") REFERENCES "public"."pet_services"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_invoice_line_id_fkey" FOREIGN KEY ("invoice_line_id") REFERENCES "public"."invoice_lines"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_lot_id_fkey" FOREIGN KEY ("lot_id") REFERENCES "public"."stock_lots"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."product_units"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_vaccination_fk" FOREIGN KEY ("vaccination_id") REFERENCES "public"."vaccinations"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visit_items"
    ADD CONSTRAINT "medical_visit_items_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_follow_up_of_fkey" FOREIGN KEY ("follow_up_of") REFERENCES "public"."medical_visits"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_signed_by_fkey" FOREIGN KEY ("signed_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."medical_visits"
    ADD CONSTRAINT "medical_visits_vet_id_fkey" FOREIGN KEY ("vet_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_cancel_by_fkey" FOREIGN KEY ("cancel_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_changes_by_fkey" FOREIGN KEY ("changes_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_combo_id_fkey" FOREIGN KEY ("combo_id") REFERENCES "public"."pet_service_combos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."order_items"
    ADD CONSTRAINT "order_items_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."orders"
    ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pet_owners"
    ADD CONSTRAINT "pet_owners_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."pet_owners"
    ADD CONSTRAINT "pet_owners_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pet_service_prices"
    ADD CONSTRAINT "pet_service_prices_bracket_id_fkey" FOREIGN KEY ("bracket_id") REFERENCES "public"."weight_brackets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pet_service_prices"
    ADD CONSTRAINT "pet_service_prices_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pet_service_prices"
    ADD CONSTRAINT "pet_service_prices_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pet_service_prices"
    ADD CONSTRAINT "pet_service_prices_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."pet_weight_logs"
    ADD CONSTRAINT "pet_weight_logs_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pet_weight_logs"
    ADD CONSTRAINT "pet_weight_logs_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pets"
    ADD CONSTRAINT "pets_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."product_attribute_values"
    ADD CONSTRAINT "product_attribute_values_attribute_id_fkey" FOREIGN KEY ("attribute_id") REFERENCES "public"."product_attributes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_branch_prices"
    ADD CONSTRAINT "product_branch_prices_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_branch_prices"
    ADD CONSTRAINT "product_branch_prices_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_branch_prices"
    ADD CONSTRAINT "product_branch_prices_updated_by_fkey" FOREIGN KEY ("updated_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_categories"
    ADD CONSTRAINT "product_categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."product_categories"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."product_group_attributes"
    ADD CONSTRAINT "product_group_attributes_attribute_id_fkey" FOREIGN KEY ("attribute_id") REFERENCES "public"."product_attributes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."product_group_attributes"
    ADD CONSTRAINT "product_group_attributes_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."product_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_groups"
    ADD CONSTRAINT "product_groups_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "public"."product_brands"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."product_groups"
    ADD CONSTRAINT "product_groups_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."product_categories"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."product_groups"
    ADD CONSTRAINT "product_groups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_images"
    ADD CONSTRAINT "product_images_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."product_groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_imports"
    ADD CONSTRAINT "product_imports_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."product_units"
    ADD CONSTRAINT "product_units_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_variant_values"
    ADD CONSTRAINT "product_variant_values_attribute_id_fkey" FOREIGN KEY ("attribute_id") REFERENCES "public"."product_attributes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."product_variant_values"
    ADD CONSTRAINT "product_variant_values_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_variant_values"
    ADD CONSTRAINT "product_variant_values_value_id_fkey" FOREIGN KEY ("value_id") REFERENCES "public"."product_attribute_values"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."product_groups"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_permission_fkey" FOREIGN KEY ("permission") REFERENCES "public"."permissions"("name") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."role_permissions"
    ADD CONSTRAINT "role_permissions_role_fkey" FOREIGN KEY ("role") REFERENCES "public"."roles"("name") ON UPDATE CASCADE ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales_return_lines"
    ADD CONSTRAINT "sales_return_lines_invoice_line_id_fkey" FOREIGN KEY ("invoice_line_id") REFERENCES "public"."invoice_lines"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."sales_return_lines"
    ADD CONSTRAINT "sales_return_lines_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."sales_return_lines"
    ADD CONSTRAINT "sales_return_lines_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "public"."sales_returns"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."sales_returns"
    ADD CONSTRAINT "sales_returns_shift_id_fkey" FOREIGN KEY ("shift_id") REFERENCES "public"."cash_shifts"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."service_species"
    ADD CONSTRAINT "service_species_service_id_fkey" FOREIGN KEY ("service_id") REFERENCES "public"."pet_services"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."service_species"
    ADD CONSTRAINT "service_species_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shop_order_events"
    ADD CONSTRAINT "shop_order_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."shop_order_events"
    ADD CONSTRAINT "shop_order_events_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."shop_orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shop_order_lines"
    ADD CONSTRAINT "shop_order_lines_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "public"."shop_orders"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."shop_order_lines"
    ADD CONSTRAINT "shop_order_lines_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shop_order_lines"
    ADD CONSTRAINT "shop_order_lines_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."product_units"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shop_orders"
    ADD CONSTRAINT "shop_orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."shop_settings"
    ADD CONSTRAINT "shop_settings_online_branch_id_fkey" FOREIGN KEY ("online_branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."spa_resources"
    ADD CONSTRAINT "spa_resources_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff_branches"
    ADD CONSTRAINT "staff_branches_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff_branches"
    ADD CONSTRAINT "staff_branches_role_fkey" FOREIGN KEY ("role") REFERENCES "public"."roles"("name") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."staff_branches"
    ADD CONSTRAINT "staff_branches_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_document_lines"
    ADD CONSTRAINT "stock_document_lines_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."stock_documents"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_document_lines"
    ADD CONSTRAINT "stock_document_lines_lot_id_fkey" FOREIGN KEY ("lot_id") REFERENCES "public"."stock_lots"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_document_lines"
    ADD CONSTRAINT "stock_document_lines_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_document_lines"
    ADD CONSTRAINT "stock_document_lines_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."product_units"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_documents"
    ADD CONSTRAINT "stock_documents_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_documents"
    ADD CONSTRAINT "stock_documents_cancelled_by_fkey" FOREIGN KEY ("cancelled_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_documents"
    ADD CONSTRAINT "stock_documents_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_documents"
    ADD CONSTRAINT "stock_documents_posted_by_fkey" FOREIGN KEY ("posted_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_documents"
    ADD CONSTRAINT "stock_documents_supplier_id_fkey" FOREIGN KEY ("supplier_id") REFERENCES "public"."suppliers"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_lots"
    ADD CONSTRAINT "stock_lots_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_lots"
    ADD CONSTRAINT "stock_lots_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_document_id_fkey" FOREIGN KEY ("document_id") REFERENCES "public"."stock_documents"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_document_line_id_fkey" FOREIGN KEY ("document_line_id") REFERENCES "public"."stock_document_lines"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_invoice_id_fkey" FOREIGN KEY ("invoice_id") REFERENCES "public"."invoices"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_invoice_line_id_fkey" FOREIGN KEY ("invoice_line_id") REFERENCES "public"."invoice_lines"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_lot_id_fkey" FOREIGN KEY ("lot_id") REFERENCES "public"."stock_lots"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_movements"
    ADD CONSTRAINT "stock_movements_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "public"."sales_returns"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."stock_thresholds"
    ADD CONSTRAINT "stock_thresholds_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_thresholds"
    ADD CONSTRAINT "stock_thresholds_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_role_fkey" FOREIGN KEY ("role") REFERENCES "public"."roles"("name") ON UPDATE CASCADE ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_lot_id_fkey" FOREIGN KEY ("lot_id") REFERENCES "public"."stock_lots"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_pet_id_fkey" FOREIGN KEY ("pet_id") REFERENCES "public"."pets"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_reminded_by_fkey" FOREIGN KEY ("reminded_by") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_vaccine_type_id_fkey" FOREIGN KEY ("vaccine_type_id") REFERENCES "public"."vaccine_types"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_visit_id_fkey" FOREIGN KEY ("visit_id") REFERENCES "public"."medical_visits"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vaccinations"
    ADD CONSTRAINT "vaccinations_visit_item_id_fkey" FOREIGN KEY ("visit_item_id") REFERENCES "public"."medical_visit_items"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."vaccine_types"
    ADD CONSTRAINT "vaccine_types_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."weight_brackets"
    ADD CONSTRAINT "weight_brackets_species_id_fkey" FOREIGN KEY ("species_id") REFERENCES "public"."species"("id") ON DELETE RESTRICT;



CREATE POLICY "admin delete" ON "public"."banners" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."bookings" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."branches" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."combo_services" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."combo_species" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."customers" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."order_items" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."orders" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."pet_owners" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."pet_service_combos" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."pet_service_prices" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."pet_services" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."pet_weight_logs" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."pets" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."products" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."service_providers" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."service_species" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."species" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin delete" ON "public"."weight_brackets" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."banners" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."branches" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."combo_services" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."combo_species" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."customers" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."pet_owners" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."pet_service_combos" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."pet_service_prices" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."pet_services" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."pet_weight_logs" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."pets" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."service_providers" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."service_species" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."species" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin insert" ON "public"."weight_brackets" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin read" ON "public"."customers" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin read" ON "public"."pet_owners" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin read" ON "public"."pet_weight_logs" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin read" ON "public"."pets" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."banners" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."bookings" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."branches" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."combo_services" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."combo_species" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."customers" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."order_items" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."orders" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."pet_owners" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."pet_service_combos" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."pet_service_prices" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."pet_services" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."pet_weight_logs" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."pets" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."products" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."service_providers" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."service_species" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."species" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



CREATE POLICY "admin update" ON "public"."weight_brackets" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_admin"() AS "is_admin")) WITH CHECK (( SELECT "public"."is_admin"() AS "is_admin"));



ALTER TABLE "public"."appointment_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."appointments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "auth hook read" ON "public"."staff_branches" FOR SELECT TO "supabase_auth_admin" USING (true);



CREATE POLICY "auth hook read" ON "public"."users" FOR SELECT TO "supabase_auth_admin" USING (true);



CREATE POLICY "authenticated read" ON "public"."permissions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated read" ON "public"."role_permissions" FOR SELECT TO "authenticated" USING (true);



CREATE POLICY "authenticated read" ON "public"."roles" FOR SELECT TO "authenticated" USING (true);



ALTER TABLE "public"."banners" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "boarding read" ON "public"."boarding_care_logs" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_boarding"('VIEW'::"text", "boarding_care_logs"."branch_id") AS "can_boarding"));



CREATE POLICY "boarding read" ON "public"."boarding_charges" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_boarding"('VIEW'::"text", "boarding_charges"."branch_id") AS "can_boarding"));



CREATE POLICY "boarding read" ON "public"."boarding_settings" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_boarding"('VIEW'::"text", "boarding_settings"."branch_id") AS "can_boarding"));



CREATE POLICY "boarding read" ON "public"."boarding_stay_pets" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_boarding"('VIEW'::"text", "boarding_stay_pets"."branch_id") AS "can_boarding"));



CREATE POLICY "boarding read" ON "public"."boarding_stays" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_boarding"('VIEW'::"text", "boarding_stays"."branch_id") AS "can_boarding"));



CREATE POLICY "boarding read" ON "public"."kennels" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_boarding"('VIEW'::"text", "kennels"."branch_id") AS "can_boarding"));



ALTER TABLE "public"."boarding_care_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."boarding_charges" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."boarding_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."boarding_stay_pets" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."boarding_stays" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."bookings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."branch_hours" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."branches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."cash_shifts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."combo_services" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."combo_species" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customer_addresses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."diagnosis_terms" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."doc_sequences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inpatient_doses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inpatient_order_changes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inpatient_orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "inventory insert" ON "public"."suppliers" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."can_inventory"('CREATE'::"text") AS "can_inventory"));



CREATE POLICY "inventory read" ON "public"."stock_document_lines" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."stock_documents" "d"
  WHERE ("d"."id" = "stock_document_lines"."document_id"))));



CREATE POLICY "inventory read" ON "public"."stock_documents" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_inventory"('VIEW'::"text", "stock_documents"."branch_id") AS "can_inventory"));



CREATE POLICY "inventory read" ON "public"."stock_lots" FOR SELECT TO "authenticated" USING ((( SELECT "public"."can_inventory"('VIEW'::"text", "stock_lots"."branch_id") AS "can_inventory") OR ( SELECT "public"."can_pos"('CREATE'::"text", "stock_lots"."branch_id") AS "can_pos")));



CREATE POLICY "inventory read" ON "public"."stock_movements" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_inventory"('VIEW'::"text", "stock_movements"."branch_id") AS "can_inventory"));



CREATE POLICY "inventory read" ON "public"."stock_thresholds" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_inventory"('VIEW'::"text", "stock_thresholds"."branch_id") AS "can_inventory"));



CREATE POLICY "inventory read" ON "public"."suppliers" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_inventory"('VIEW'::"text") AS "can_inventory"));



CREATE POLICY "inventory update" ON "public"."suppliers" FOR UPDATE TO "authenticated" USING (( SELECT "public"."can_inventory"('UPDATE'::"text") AS "can_inventory")) WITH CHECK (( SELECT "public"."can_inventory"('UPDATE'::"text") AS "can_inventory"));



ALTER TABLE "public"."invoice_lines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."invoices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kennel_type_prices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kennel_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."kennels" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "medical read" ON "public"."inpatient_doses" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."inpatient_order_changes" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."inpatient_orders" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."medical_addenda" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."medical_attachments" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."medical_diagnoses" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."medical_settings" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text", "medical_settings"."branch_id") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."medical_visit_items" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."medical_visits" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



CREATE POLICY "medical read" ON "public"."vaccinations" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_medical"('VIEW'::"text") AS "can_medical"));



ALTER TABLE "public"."medical_addenda" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medical_attachments" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medical_diagnoses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medical_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medical_visit_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."medical_visits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."order_items" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."orders" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "own addresses read" ON "public"."customer_addresses" FOR SELECT TO "authenticated" USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "own or admin read" ON "public"."staff_branches" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



CREATE POLICY "own or admin read" ON "public"."users" FOR SELECT TO "authenticated" USING ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



CREATE POLICY "own or admin update" ON "public"."users" FOR UPDATE TO "authenticated" USING ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin"))) WITH CHECK ((("id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



CREATE POLICY "owner create" ON "public"."order_items" FOR INSERT TO "authenticated" WITH CHECK ((("status" = 'PENDING'::"text") AND (NOT "is_cancel") AND (NOT "is_moving_time") AND (EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "owner create" ON "public"."orders" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "owner or admin read" ON "public"."bookings" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



CREATE POLICY "owner or admin read" ON "public"."order_items" FOR SELECT TO "authenticated" USING ((( SELECT "public"."is_admin"() AS "is_admin") OR (EXISTS ( SELECT 1
   FROM "public"."orders" "o"
  WHERE (("o"."id" = "order_items"."order_id") AND ("o"."user_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "owner or admin read" ON "public"."orders" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."is_admin"() AS "is_admin")));



ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "permission delete" ON "public"."bookings" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."combo_services" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."combo_species" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."customers" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."order_items" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."orders" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."pet_owners" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."pet_service_combos" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."pet_service_prices" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."pet_services" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."pet_weight_logs" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."pets" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."products" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('products'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."service_species" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."species" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission delete" ON "public"."weight_brackets" FOR DELETE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'DELETE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."bookings" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('schedule'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."combo_services" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."combo_species" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."customers" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."order_items" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('schedule'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."orders" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('schedule'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."pet_owners" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."pet_service_combos" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."pet_service_prices" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."pet_services" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."pet_weight_logs" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."pets" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('products'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."service_species" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."species" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission insert" ON "public"."weight_brackets" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'CREATE'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."bookings" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."combo_services" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."combo_species" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."customers" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."order_items" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."orders" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."pet_owners" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."pet_service_combos" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."pet_service_prices" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."pet_services" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."pet_weight_logs" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."pets" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."service_species" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."species" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."users" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('users'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission read" ON "public"."weight_brackets" FOR SELECT TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'VIEW'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."bookings" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('schedule'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."combo_services" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."combo_species" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."customers" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."order_items" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('schedule'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."orders" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('schedule'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('schedule'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."pet_owners" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."pet_service_combos" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."pet_service_prices" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."pet_services" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."pet_weight_logs" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."pets" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('pets'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."products" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('products'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('products'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."service_species" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."species" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."users" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('users'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('users'::"text", 'UPDATE'::"text") AS "has_permission"));



CREATE POLICY "permission update" ON "public"."weight_brackets" FOR UPDATE TO "authenticated" USING (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission")) WITH CHECK (( SELECT "public"."has_permission"('petServices'::"text", 'UPDATE'::"text") AS "has_permission"));



ALTER TABLE "public"."permissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_owners" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_service_combos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_service_prices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_services" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pet_weight_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pos read" ON "public"."cash_shifts" FOR SELECT TO "authenticated" USING ((("opened_by" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."can_pos"('VIEW'::"text", "cash_shifts"."branch_id") AS "can_pos")));



CREATE POLICY "pos read" ON "public"."invoice_lines" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."invoices" "i"
  WHERE ("i"."id" = "invoice_lines"."invoice_id"))));



CREATE POLICY "pos read" ON "public"."invoices" FOR SELECT TO "authenticated" USING ((("created_by" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."can_pos"('VIEW'::"text", "invoices"."branch_id") AS "can_pos")));



CREATE POLICY "pos read" ON "public"."payments" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."invoices" "i"
  WHERE ("i"."id" = "payments"."invoice_id"))));



CREATE POLICY "pos read" ON "public"."sales_return_lines" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."sales_returns" "r"
  WHERE ("r"."id" = "sales_return_lines"."return_id"))));



CREATE POLICY "pos read" ON "public"."sales_returns" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."invoices" "i"
  WHERE ("i"."id" = "sales_returns"."invoice_id"))));



ALTER TABLE "public"."product_attribute_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_attributes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_branch_prices" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_brands" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_categories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_group_attributes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_images" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_imports" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_units" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_variant_values" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products viewers read" ON "public"."product_imports" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_products"('VIEW'::"text") AS "can_products"));



CREATE POLICY "public create" ON "public"."bookings" FOR INSERT TO "authenticated", "anon" WITH CHECK (((("user_id" IS NULL) OR ("user_id" = ( SELECT "auth"."uid"() AS "uid"))) AND ("status" = 'PENDING'::"text") AND (NOT "is_cancel") AND (NOT "is_moving_time") AND ("cancel_date" IS NULL) AND ("cancel_by" IS NULL) AND ("cancel_reason" IS NULL) AND ("confirm_changed_by" IS NULL) AND ("confirm_from_time" IS NULL) AND ("confirm_to_time" IS NULL) AND (("char_length"("name") >= 1) AND ("char_length"("name") <= 200)) AND (("char_length"("email") >= 3) AND ("char_length"("email") <= 320)) AND (("char_length"("phone_number") >= 6) AND ("char_length"("phone_number") <= 20)) AND (("content" IS NULL) OR ("char_length"("content") <= 2000))));



CREATE POLICY "public read" ON "public"."banners" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."branches" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."combo_services" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."combo_species" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."pet_service_combos" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."pet_service_prices" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."pet_services" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_attribute_values" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_attributes" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_branch_prices" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_brands" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_categories" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_group_attributes" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_groups" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_images" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_units" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."product_variant_values" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."products" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."service_providers" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."service_species" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."species" FOR SELECT TO "authenticated", "anon" USING (true);



CREATE POLICY "public read" ON "public"."weight_brackets" FOR SELECT TO "authenticated", "anon" USING (true);



ALTER TABLE "public"."role_permissions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_return_lines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."sales_returns" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "schedule read" ON "public"."appointment_items" FOR SELECT TO "authenticated" USING ((("staff_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."can_schedule"('VIEW'::"text", "appointment_items"."branch_id") AS "can_schedule")));



CREATE POLICY "schedule read" ON "public"."appointments" FOR SELECT TO "authenticated" USING ((( SELECT "public"."can_schedule"('VIEW'::"text", "appointments"."branch_id") AS "can_schedule") OR (EXISTS ( SELECT 1
   FROM "public"."appointment_items" "i"
  WHERE (("i"."appointment_id" = "appointments"."id") AND ("i"."staff_id" = ( SELECT "auth"."uid"() AS "uid")))))));



CREATE POLICY "schedule read" ON "public"."branch_hours" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_schedule"('VIEW'::"text", "branch_hours"."branch_id") AS "can_schedule"));



CREATE POLICY "schedule read" ON "public"."spa_resources" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_schedule"('VIEW'::"text", "spa_resources"."branch_id") AS "can_schedule"));



ALTER TABLE "public"."service_providers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."service_species" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "shop order events read" ON "public"."shop_order_events" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."shop_orders" "o"
  WHERE (("o"."id" = "shop_order_events"."order_id") AND ( SELECT "public"."can_shop_orders"('VIEW'::"text", "o"."branch_id") AS "can_shop_orders")))));



CREATE POLICY "shop order lines read" ON "public"."shop_order_lines" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."shop_orders" "o"
  WHERE (("o"."id" = "shop_order_lines"."order_id") AND (("o"."user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."can_shop_orders"('VIEW'::"text", "o"."branch_id") AS "can_shop_orders"))))));



CREATE POLICY "shop orders read" ON "public"."shop_orders" FOR SELECT TO "authenticated" USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ( SELECT "public"."can_shop_orders"('VIEW'::"text", "shop_orders"."branch_id") AS "can_shop_orders")));



CREATE POLICY "shop settings read" ON "public"."shop_settings" FOR SELECT TO "authenticated" USING (( SELECT "public"."can_shop_orders"('VIEW'::"text", "shop_settings"."online_branch_id") AS "can_shop_orders"));



ALTER TABLE "public"."shop_order_events" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shop_order_lines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shop_orders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."shop_settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."spa_resources" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."species" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff read" ON "public"."diagnosis_terms" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_staff"() AS "is_staff"));



CREATE POLICY "staff read" ON "public"."kennel_type_prices" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_staff"() AS "is_staff"));



CREATE POLICY "staff read" ON "public"."kennel_types" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_staff"() AS "is_staff"));



CREATE POLICY "staff read" ON "public"."vaccine_types" FOR SELECT TO "authenticated" USING (( SELECT "public"."is_staff"() AS "is_staff"));



ALTER TABLE "public"."staff_branches" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stock_document_lines" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stock_documents" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stock_lots" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stock_movements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stock_thresholds" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "super admin delete" ON "public"."permissions" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin delete" ON "public"."role_permissions" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin delete" ON "public"."roles" FOR DELETE TO "authenticated" USING ((( SELECT "public"."is_super_admin"() AS "is_super_admin") AND (NOT "is_system")));



CREATE POLICY "super admin delete" ON "public"."staff_branches" FOR DELETE TO "authenticated" USING (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin insert" ON "public"."permissions" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin insert" ON "public"."role_permissions" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin insert" ON "public"."roles" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin insert" ON "public"."staff_branches" FOR INSERT TO "authenticated" WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin update" ON "public"."permissions" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_super_admin"() AS "is_super_admin")) WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin update" ON "public"."role_permissions" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_super_admin"() AS "is_super_admin")) WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin update" ON "public"."roles" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_super_admin"() AS "is_super_admin")) WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



CREATE POLICY "super admin update" ON "public"."staff_branches" FOR UPDATE TO "authenticated" USING (( SELECT "public"."is_super_admin"() AS "is_super_admin")) WITH CHECK (( SELECT "public"."is_super_admin"() AS "is_super_admin"));



ALTER TABLE "public"."suppliers" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vaccinations" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."vaccine_types" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."weight_brackets" ENABLE ROW LEVEL SECURITY;


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";
GRANT USAGE ON SCHEMA "public" TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."add_boarding_extra"("p_stay_pet" "uuid", "p_service" "uuid", "p_qty" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_boarding_extra"("p_stay_pet" "uuid", "p_service" "uuid", "p_qty" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_boarding_extra"("p_stay_pet" "uuid", "p_service" "uuid", "p_qty" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."add_care_log"("p_stay_pet" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_care_log"("p_stay_pet" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_care_log"("p_stay_pet" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."add_external_vaccination"("p_pet" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_external_vaccination"("p_pet" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_external_vaccination"("p_pet" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."add_inpatient_log"("p_stay_pet" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_inpatient_log"("p_stay_pet" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_inpatient_log"("p_stay_pet" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."add_medical_addendum"("p_id" "uuid", "p_content" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_medical_addendum"("p_id" "uuid", "p_content" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_medical_addendum"("p_id" "uuid", "p_content" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."add_medical_attachment"("p_visit" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_medical_attachment"("p_visit" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_medical_attachment"("p_visit" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."add_medical_item"("p_visit" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."add_medical_item"("p_visit" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_medical_item"("p_visit" "uuid", "p" "jsonb") TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."customer_addresses" TO "authenticated";
GRANT ALL ON TABLE "public"."customer_addresses" TO "service_role";



REVOKE ALL ON FUNCTION "public"."address_json"("a" "public"."customer_addresses") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."address_json"("a" "public"."customer_addresses") TO "service_role";



REVOKE ALL ON FUNCTION "public"."admit_inpatient"("p_visit" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."admit_inpatient"("p_visit" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."admit_inpatient"("p_visit" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."assign_medical_vet"("p_id" "uuid", "p_vet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."assign_medical_vet"("p_id" "uuid", "p_vet" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."assign_medical_vet"("p_id" "uuid", "p_vet" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."auto_cancel_stale_shop_orders"("p_hours" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."auto_cancel_stale_shop_orders"("p_hours" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."billable_appointment_items"("p_branch" "uuid", "p_customer" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."billable_appointment_items"("p_branch" "uuid", "p_customer" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."billable_appointment_items"("p_branch" "uuid", "p_customer" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."billable_boarding_charges"("p_branch" "uuid", "p_customer" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."billable_boarding_charges"("p_branch" "uuid", "p_customer" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."billable_boarding_charges"("p_branch" "uuid", "p_customer" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."billable_medical_items"("p_branch" "uuid", "p_customer" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."billable_medical_items"("p_branch" "uuid", "p_customer" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."billable_medical_items"("p_branch" "uuid", "p_customer" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_apply_stay"("p" "jsonb", "p_id" "uuid", "p_dry" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_apply_stay"("p" "jsonb", "p_id" "uuid", "p_dry" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_availability"("p_branch" "uuid", "p_from" "date", "p_to" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_availability"("p_branch" "uuid", "p_from" "date", "p_to" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."boarding_availability"("p_branch" "uuid", "p_from" "date", "p_to" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_board"("p_branch" "uuid", "p_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_board"("p_branch" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."boarding_board"("p_branch" "uuid", "p_date" "date") TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boarding_stays" TO "authenticated";
GRANT ALL ON TABLE "public"."boarding_stays" TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_checkout_calc"("p_stay" "public"."boarding_stays", "p_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_checkout_calc"("p_stay" "public"."boarding_stays", "p_at" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_checkout_preview"("p_id" "uuid", "p_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_checkout_preview"("p_id" "uuid", "p_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."boarding_checkout_preview"("p_id" "uuid", "p_at" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_local_date"("p_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_local_date"("p_at" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_pick_kennel"("p_branch" "uuid", "p_type" "uuid", "p_nights" "daterange", "p_exclude" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_pick_kennel"("p_branch" "uuid", "p_type" "uuid", "p_nights" "daterange", "p_exclude" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_public_catalog"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_public_catalog"("p_branch" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."boarding_public_catalog"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."boarding_public_catalog"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_quote"("p_branch" "uuid", "p" "jsonb", "p_stay" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_quote"("p_branch" "uuid", "p" "jsonb", "p_stay" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."boarding_quote"("p_branch" "uuid", "p" "jsonb", "p_stay" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_rules"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_rules"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_settings_get"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_settings_get"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."boarding_settings_get"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_stay_json"("p_stay" "public"."boarding_stays") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_stay_json"("p_stay" "public"."boarding_stays") TO "service_role";



REVOKE ALL ON FUNCTION "public"."boarding_timeline"("p_branch" "uuid", "p_from" "date", "p_days" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."boarding_timeline"("p_branch" "uuid", "p_from" "date", "p_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."boarding_timeline"("p_branch" "uuid", "p_from" "date", "p_days" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."book_my_appointment"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."book_my_appointment"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."book_my_appointment"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."branch_prices"("p_branch" "uuid", "p_products" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."branch_prices"("p_branch" "uuid", "p_products" "uuid"[]) TO "anon";
GRANT ALL ON FUNCTION "public"."branch_prices"("p_branch" "uuid", "p_products" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."branch_prices"("p_branch" "uuid", "p_products" "uuid"[]) TO "service_role";



GRANT ALL ON FUNCTION "public"."business_date"() TO "anon";
GRANT ALL ON FUNCTION "public"."business_date"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."business_date"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_boarding"("p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_boarding"("p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_boarding"("p_method" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_edit_pet_photos"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_edit_pet_photos"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_edit_pet_photos"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_inventory"("p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_inventory"("p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_inventory"("p_method" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_link_accounts"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_link_accounts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_link_accounts"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_medical"("p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_medical"("p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_medical"("p_method" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_pos"("p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_pos"("p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_pos"("p_method" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_products"("p_method" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_products"("p_method" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_products"("p_method" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_report"("p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_report"("p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_report"("p_method" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_schedule"("p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_schedule"("p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_schedule"("p_method" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."can_shop_orders"("p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."can_shop_orders"("p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."can_shop_orders"("p_method" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_appointment"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_appointment"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_appointment"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_boarding_stay"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_boarding_stay"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_boarding_stay"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_invoice"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_invoice"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_invoice"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_medical_visit"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_medical_visit"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_medical_visit"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_my_appointment"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_my_appointment"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_my_appointment"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_my_shop_order"("p_code" "text", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_my_shop_order"("p_code" "text", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_my_shop_order"("p_code" "text", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_shop_order"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_shop_order"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_shop_order"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cancel_stock_document"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cancel_stock_document"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cancel_stock_document"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."cash_shift_summary"("p_shift" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."cash_shift_summary"("p_shift" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cash_shift_summary"("p_shift" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_in_appointment"("p_id" "uuid", "p_weights" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_in_appointment"("p_id" "uuid", "p_weights" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_in_appointment"("p_id" "uuid", "p_weights" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_in_boarding"("p_id" "uuid", "p_pets" "jsonb", "p_emergency_phone" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_in_boarding"("p_id" "uuid", "p_pets" "jsonb", "p_emergency_phone" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_in_boarding"("p_id" "uuid", "p_pets" "jsonb", "p_emergency_phone" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_in_medical_visit"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_in_medical_visit"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_in_medical_visit"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."check_out_boarding"("p_id" "uuid", "p_returned" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."check_out_boarding"("p_id" "uuid", "p_returned" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."check_out_boarding"("p_id" "uuid", "p_returned" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."close_cash_shift"("p_shift" "uuid", "p_counted_cash" numeric, "p_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."close_cash_shift"("p_shift" "uuid", "p_counted_cash" numeric, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."close_cash_shift"("p_shift" "uuid", "p_counted_cash" numeric, "p_note" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."confirm_shop_order"("p_id" "uuid", "p_shipping_fee" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."confirm_shop_order"("p_id" "uuid", "p_shipping_fee" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."confirm_shop_order"("p_id" "uuid", "p_shipping_fee" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_invoice"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_invoice"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_invoice"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_order"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_order"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_order"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."create_sales_return"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."create_sales_return"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_sales_return"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "service_role";
GRANT ALL ON FUNCTION "public"."custom_access_token_hook"("event" "jsonb") TO "supabase_auth_admin";



REVOKE ALL ON FUNCTION "public"."delete_care_log"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_care_log"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_care_log"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_my_address"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_my_address"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_my_address"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_product_brand"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_product_brand"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_product_brand"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."delete_product_category"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."delete_product_category"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_product_category"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."deliver_shop_order"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."deliver_shop_order"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."deliver_shop_order"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."discharge_inpatient"("p_stay" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."discharge_inpatient"("p_stay" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."discharge_inpatient"("p_stay" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."export_products"("p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."export_products"("p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."export_products"("p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."extend_boarding_stay"("p_id" "uuid", "p_planned_out_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."extend_boarding_stay"("p_id" "uuid", "p_planned_out_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."extend_boarding_stay"("p_id" "uuid", "p_planned_out_at" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."find_by_barcode"("p_code" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."find_by_barcode"("p_code" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_by_barcode"("p_code" "text", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."find_products_by_sku"("p_skus" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."find_products_by_sku"("p_skus" "text"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."find_products_by_sku"("p_skus" "text"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_appointment"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_appointment"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_appointment"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_boarding_stay"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_boarding_stay"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_boarding_stay"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_medical_visit"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_medical_visit"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_medical_visit"("p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_service_price"("p_species_id" "uuid", "p_service_id" "uuid", "p_weight_kg" numeric, "p_branch_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_service_price"("p_species_id" "uuid", "p_service_id" "uuid", "p_weight_kg" numeric, "p_branch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_service_price"("p_species_id" "uuid", "p_service_id" "uuid", "p_weight_kg" numeric, "p_branch_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."get_shop_order"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."get_shop_order"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_shop_order"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."give_inpatient_dose"("p_dose" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."give_inpatient_dose"("p_dose" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."give_inpatient_dose"("p_dose" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."give_vaccination"("p_visit" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."give_vaccination"("p_visit" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."give_vaccination"("p_visit" "uuid", "p" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."guard_user_columns"() TO "anon";
GRANT ALL ON FUNCTION "public"."guard_user_columns"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."guard_user_columns"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."has_permission"("p_permission" "text", "p_method" "text", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."has_permission"("p_permission" "text", "p_method" "text", "p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."has_permission"("p_permission" "text", "p_method" "text", "p_branch" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."immutable_unaccent"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."immutable_unaccent"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."immutable_unaccent"("text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_add_error"("p_errors" "jsonb", "p_row" "text", "p_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_add_error"("p_errors" "jsonb", "p_row" "text", "p_note" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_error_text"("p_hint" "text", "p_message" "text", "p_detail" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_error_text"("p_hint" "text", "p_message" "text", "p_detail" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_one_group"("p_rows" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_one_group"("p_rows" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_pets"("p_rows" "jsonb", "p_dry_run" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_pets"("p_rows" "jsonb", "p_dry_run" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."import_pets"("p_rows" "jsonb", "p_dry_run" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_pets_row"("p_row" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_pets_row"("p_row" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_pets_run"("p_rows" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_pets_run"("p_rows" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_products"("p_rows" "jsonb", "p_dry_run" boolean, "p_file_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_products"("p_rows" "jsonb", "p_dry_run" boolean, "p_file_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."import_products"("p_rows" "jsonb", "p_dry_run" boolean, "p_file_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_products_run"("p_rows" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_products_run"("p_rows" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_resolve_brand"("p_name" "text", OUT "o_id" "uuid", OUT "o_created" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_resolve_brand"("p_name" "text", OUT "o_id" "uuid", OUT "o_created" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_resolve_category"("p_path" "text", OUT "o_id" "uuid", OUT "o_created" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_resolve_category"("p_path" "text", OUT "o_id" "uuid", OUT "o_created" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_suppliers"("p_rows" "jsonb", "p_dry_run" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_suppliers"("p_rows" "jsonb", "p_dry_run" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."import_suppliers"("p_rows" "jsonb", "p_dry_run" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_suppliers_row"("p_row" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_suppliers_row"("p_row" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."import_suppliers_run"("p_rows" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."import_suppliers_run"("p_rows" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."inpatient_kennels"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."inpatient_kennels"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inpatient_kennels"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."inpatient_log_change"("p_order" "uuid", "p_visit" "uuid", "p_action" "text", "p_before" "jsonb", "p_after" "jsonb", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."inpatient_log_change"("p_order" "uuid", "p_visit" "uuid", "p_action" "text", "p_before" "jsonb", "p_after" "jsonb", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."inpatient_order_history"("p_order" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."inpatient_order_history"("p_order" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inpatient_order_history"("p_order" "uuid") TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."inpatient_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."inpatient_orders" TO "service_role";



REVOKE ALL ON FUNCTION "public"."inpatient_order_snapshot"("p_order" "public"."inpatient_orders") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."inpatient_order_snapshot"("p_order" "public"."inpatient_orders") TO "service_role";



GRANT ALL ON FUNCTION "public"."inpatient_signed_lock"() TO "anon";
GRANT ALL ON FUNCTION "public"."inpatient_signed_lock"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."inpatient_signed_lock"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."inpatient_ward"("p_branch" "uuid", "p_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."inpatient_ward"("p_branch" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."inpatient_ward"("p_branch" "uuid", "p_date" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."invoice_cancel_restock"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."invoice_cancel_restock"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."invoice_line_take_stock"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."invoice_line_take_stock"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_admin"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_display_name_available"("p_display_name" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_display_name_available"("p_display_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."is_display_name_available"("p_display_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_display_name_available"("p_display_name" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."is_staff"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."is_staff"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_staff"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_super_admin"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."issue_shop_order_invoice"("p_order" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."issue_shop_order_invoice"("p_order" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."kennel_extra_pet_price"("p_type" "uuid", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kennel_extra_pet_price"("p_type" "uuid", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."kennel_night_price"("p_type" "uuid", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."kennel_night_price"("p_type" "uuid", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."link_customer_account"("p_customer" "uuid", "p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."link_customer_account"("p_customer" "uuid", "p_user" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."link_customer_account"("p_customer" "uuid", "p_user" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_appointments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_appointments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_appointments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_boarding_stays"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_boarding_stays"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_boarding_stays"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_branch_staff"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_branch_staff"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_branch_staff"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_diagnosis_terms"("p_search" "text", "p_species" "uuid", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_diagnosis_terms"("p_search" "text", "p_species" "uuid", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_diagnosis_terms"("p_search" "text", "p_species" "uuid", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_kennel_types"("p_branch" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_kennel_types"("p_branch" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_kennel_types"("p_branch" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer, "p_active_only" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_kennels"("p_branch" "uuid", "p_search" "text", "p_type" "uuid", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_kennels"("p_branch" "uuid", "p_search" "text", "p_type" "uuid", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_kennels"("p_branch" "uuid", "p_search" "text", "p_type" "uuid", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_medical_attachments"("p_visit" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_medical_attachments"("p_visit" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_medical_attachments"("p_visit" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_medical_visits"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_vet" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_medical_visits"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_vet" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_medical_visits"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_vet" "uuid", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_product_brands"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_product_brands"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."list_product_brands"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_product_brands"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_product_categories"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer, "p_roots_only" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_product_categories"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer, "p_roots_only" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."list_product_categories"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer, "p_roots_only" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_product_categories"("p_search" "text", "p_include_inactive" boolean, "p_limit" integer, "p_offset" integer, "p_roots_only" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_product_groups"("p_search" "text", "p_include_archived" boolean, "p_limit" integer, "p_offset" integer, "p_category" "uuid", "p_brand" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_product_groups"("p_search" "text", "p_include_archived" boolean, "p_limit" integer, "p_offset" integer, "p_category" "uuid", "p_brand" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."list_product_groups"("p_search" "text", "p_include_archived" boolean, "p_limit" integer, "p_offset" integer, "p_category" "uuid", "p_brand" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_product_groups"("p_search" "text", "p_include_archived" boolean, "p_limit" integer, "p_offset" integer, "p_category" "uuid", "p_brand" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_shop_orders"("p_branch" "uuid", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_shop_orders"("p_branch" "uuid", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_shop_orders"("p_branch" "uuid", "p_status" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."list_vaccine_types"("p_search" "text", "p_kind" "text", "p_page" integer, "p_page_size" integer, "p_branch" "uuid", "p_species" "uuid", "p_active_only" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."list_vaccine_types"("p_search" "text", "p_kind" "text", "p_page" integer, "p_page_size" integer, "p_branch" "uuid", "p_species" "uuid", "p_active_only" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."list_vaccine_types"("p_search" "text", "p_kind" "text", "p_page" integer, "p_page_size" integer, "p_branch" "uuid", "p_species" "uuid", "p_active_only" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_boarding_no_show"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_boarding_no_show"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_boarding_no_show"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_medical_no_show"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_medical_no_show"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_medical_no_show"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_no_show"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_no_show"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_no_show"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_pet_deceased"("p_pet" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_pet_deceased"("p_pet" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_pet_deceased"("p_pet" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."mark_reminded"("p_vaccination" "uuid", "p_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."mark_reminded"("p_vaccination" "uuid", "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."mark_reminded"("p_vaccination" "uuid", "p_note" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."medical_addenda_frozen"() TO "anon";
GRANT ALL ON FUNCTION "public"."medical_addenda_frozen"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_addenda_frozen"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_check_pet"("p_customer" "uuid", "p_pet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_check_pet"("p_customer" "uuid", "p_pet" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."medical_diagnoses_lock"() TO "anon";
GRANT ALL ON FUNCTION "public"."medical_diagnoses_lock"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_diagnoses_lock"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_local_date"("p_at" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_local_date"("p_at" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_next_dose_no"("p_pet" "uuid", "p_type" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_next_dose_no"("p_pet" "uuid", "p_type" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_next_due"("p_type" "uuid", "p_dose_no" integer, "p_given_on" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_next_due"("p_type" "uuid", "p_dose_no" integer, "p_given_on" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_prescription"("p_visit" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_prescription"("p_visit" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_prescription"("p_visit" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_queue"("p_branch" "uuid", "p_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_queue"("p_branch" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_queue"("p_branch" "uuid", "p_date" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_refresh_status"("p_visit" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_refresh_status"("p_visit" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_reminders"("p_branch" "uuid", "p_scope" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_reminders"("p_branch" "uuid", "p_scope" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_reminders"("p_branch" "uuid", "p_scope" "text", "p_search" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_settings_get"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_settings_get"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_settings_get"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_stock_qty"("p_branch" "uuid", "p_product" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_stock_qty"("p_branch" "uuid", "p_product" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_user_can_update"("p_user" "uuid", "p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_user_can_update"("p_user" "uuid", "p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_vets"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_vets"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_vets"("p_branch" "uuid") TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_visits" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_visits" TO "service_role";



REVOKE ALL ON FUNCTION "public"."medical_visit_json"("v" "public"."medical_visits") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."medical_visit_json"("v" "public"."medical_visits") TO "service_role";



GRANT ALL ON FUNCTION "public"."medical_visits_inpatient_guard"() TO "anon";
GRANT ALL ON FUNCTION "public"."medical_visits_inpatient_guard"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_visits_inpatient_guard"() TO "service_role";



GRANT ALL ON FUNCTION "public"."medical_visits_lock"() TO "anon";
GRANT ALL ON FUNCTION "public"."medical_visits_lock"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."medical_visits_lock"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."move_boarding_pet"("p_stay_pet" "uuid", "p_kennel" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."move_boarding_pet"("p_stay_pet" "uuid", "p_kennel" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."move_boarding_pet"("p_stay_pet" "uuid", "p_kennel" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."move_product_category"("p_id" "uuid", "p_direction" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."move_product_category"("p_id" "uuid", "p_direction" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."move_product_category"("p_id" "uuid", "p_direction" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."move_stock"("p_lot" "uuid", "p_qty" numeric, "p_reason" "text", "p_document" "uuid", "p_document_line" "uuid", "p_invoice" "uuid", "p_invoice_line" "uuid", "p_return" "uuid", "p_unit_cost" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."move_stock"("p_lot" "uuid", "p_qty" numeric, "p_reason" "text", "p_document" "uuid", "p_document_line" "uuid", "p_invoice" "uuid", "p_invoice_line" "uuid", "p_return" "uuid", "p_unit_cost" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_addresses"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_addresses"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_addresses"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_appointments"("p_scope" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_appointments"("p_scope" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_appointments"("p_scope" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_boarding_stay"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_boarding_stay"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_boarding_stay"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_boarding_stay_json"("p_stay" "public"."boarding_stays") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_boarding_stay_json"("p_stay" "public"."boarding_stays") TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_boarding_stays"("p_scope" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_boarding_stays"("p_scope" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_boarding_stays"("p_scope" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_customer_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_customer_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_customer_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_permissions"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_permissions"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_permissions"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_pet_health"("p_pet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_pet_health"("p_pet" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_pet_health"("p_pet" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_pets"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_pets"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_pets"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_profile"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_profile"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_profile"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_shop_order"("p_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_shop_order"("p_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_shop_order"("p_code" "text") TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_orders" TO "authenticated";
GRANT ALL ON TABLE "public"."shop_orders" TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_shop_order_json"("o" "public"."shop_orders") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_shop_order_json"("o" "public"."shop_orders") TO "service_role";



REVOKE ALL ON FUNCTION "public"."my_shop_orders"("p_status" "text", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."my_shop_orders"("p_status" "text", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."my_shop_orders"("p_status" "text", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."next_doc_code"("p_branch" "uuid", "p_type" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."next_doc_code"("p_branch" "uuid", "p_type" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."open_cash_shift"("p_branch" "uuid", "p_opening_cash" numeric, "p_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."open_cash_shift"("p_branch" "uuid", "p_opening_cash" numeric, "p_note" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."open_cash_shift"("p_branch" "uuid", "p_opening_cash" numeric, "p_note" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."pack_shop_order"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pack_shop_order"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pack_shop_order"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."pay_pickup_shop_order"("p_id" "uuid", "p_payments" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pay_pickup_shop_order"("p_id" "uuid", "p_payments" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pay_pickup_shop_order"("p_id" "uuid", "p_payments" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."pet_deceased_cleanup"("p_pet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pet_deceased_cleanup"("p_pet" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."pet_deceased_impact"("p_pet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pet_deceased_impact"("p_pet" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."pet_deceased_preview"("p_pet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pet_deceased_preview"("p_pet" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pet_deceased_preview"("p_pet" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."pet_health_flags"("p_pet_ids" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pet_health_flags"("p_pet_ids" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pet_health_flags"("p_pet_ids" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."pet_medical_history"("p_pet" "uuid", "p_page" integer, "p_page_size" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pet_medical_history"("p_pet" "uuid", "p_page" integer, "p_page_size" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."pet_medical_history"("p_pet" "uuid", "p_page" integer, "p_page_size" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."pet_vaccinations"("p_pet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."pet_vaccinations"("p_pet" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."pet_vaccinations"("p_pet" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."pets_deceased_after"() TO "anon";
GRANT ALL ON FUNCTION "public"."pets_deceased_after"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."pets_deceased_after"() TO "service_role";



GRANT ALL ON FUNCTION "public"."pets_deceased_before"() TO "anon";
GRANT ALL ON FUNCTION "public"."pets_deceased_before"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."pets_deceased_before"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."place_shop_order"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."place_shop_order"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."place_shop_order"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."post_stock_document"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."post_stock_document"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."post_stock_document"("p_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."product_categories_check_depth"() TO "anon";
GRANT ALL ON FUNCTION "public"."product_categories_check_depth"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."product_categories_check_depth"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."product_group_json"("p_group" "uuid", "p_all" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."product_group_json"("p_group" "uuid", "p_all" boolean) TO "anon";
GRANT ALL ON FUNCTION "public"."product_group_json"("p_group" "uuid", "p_all" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."product_group_json"("p_group" "uuid", "p_all" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."product_unit_price"("p_product" "uuid", "p_branch" "uuid", "p_unit" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."product_unit_price"("p_product" "uuid", "p_branch" "uuid", "p_unit" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."product_unit_price"("p_product" "uuid", "p_branch" "uuid", "p_unit" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."product_unit_price"("p_product" "uuid", "p_branch" "uuid", "p_unit" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."refresh_appointment_status"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_appointment_status"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."refresh_boarding_stay_status"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_boarding_stay_status"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."refresh_variant_names"("p_group" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_variant_names"("p_group" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."register_pet"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."register_pet"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_pet"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_boarding_extra"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_boarding_extra"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_boarding_extra"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_medical_attachment"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_medical_attachment"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_medical_attachment"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."remove_medical_item"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."remove_medical_item"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_medical_item"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."replace_inpatient_order"("p_id" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."replace_inpatient_order"("p_id" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."replace_inpatient_order"("p_id" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_adjustments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_adjustments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_adjustments"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_branch_ids"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_branch_ids"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_limit"("p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_limit"("p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_overview"("p_branch" "uuid", "p_from" "date", "p_to" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_overview"("p_branch" "uuid", "p_from" "date", "p_to" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_overview"("p_branch" "uuid", "p_from" "date", "p_to" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_overview_core"("p_branches" "uuid"[], "p_range" "tstzrange") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_overview_core"("p_branches" "uuid"[], "p_range" "tstzrange") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_range"("p_from" "date", "p_to" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_range"("p_from" "date", "p_to" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_revenue_series"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_bucket" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_revenue_series"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_bucket" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_revenue_series"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_bucket" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_sales_lines"("p_branches" "uuid"[], "p_from" timestamp with time zone, "p_to" timestamp with time zone) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_sales_lines"("p_branches" "uuid"[], "p_from" timestamp with time zone, "p_to" timestamp with time zone) TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_shifts"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_shifts"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_shifts"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_staff_revenue"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_role" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_staff_revenue"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_role" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_staff_revenue"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_role" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."report_top_items"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_sort" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."report_top_items"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_sort" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."report_top_items"("p_branch" "uuid", "p_from" "date", "p_to" "date", "p_kind" "text", "p_search" "text", "p_sort" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."restore_pet"("p_pet" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."restore_pet"("p_pet" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."restore_pet"("p_pet" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."return_shop_order"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."return_shop_order"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."return_shop_order"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_appointment"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_appointment"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_appointment"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_boarding_settings"("p_branch" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_boarding_settings"("p_branch" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_boarding_settings"("p_branch" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_boarding_stay"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_boarding_stay"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_boarding_stay"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_branch_hours"("p_branch" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_branch_hours"("p_branch" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_branch_hours"("p_branch" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_diagnosis_term"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_diagnosis_term"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_diagnosis_term"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_inpatient_order"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_inpatient_order"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_inpatient_order"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_kennel"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_kennel"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_kennel"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_kennel_type"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_kennel_type"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_kennel_type"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_medical_record"("p_id" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_medical_record"("p_id" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_medical_record"("p_id" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_medical_settings"("p_branch" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_medical_settings"("p_branch" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_medical_settings"("p_branch" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_my_address"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_my_address"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_my_address"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_my_profile"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_my_profile"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_my_profile"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_pet_combo"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_pet_combo"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_pet_combo"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_pet_service"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_pet_service"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_pet_service"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_product_brand"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_product_brand"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_product_brand"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_product_category"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_product_category"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_product_category"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_product_group"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_product_group"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_product_group"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_product_units"("p_product" "uuid", "p_units" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_product_units"("p_product" "uuid", "p_units" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_role"("p" "jsonb", "p_id" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_role"("p" "jsonb", "p_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_role"("p" "jsonb", "p_id" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_service_prices"("p_species_id" "uuid", "p_service_id" "uuid", "p_rows" "jsonb", "p_branch_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_service_prices"("p_species_id" "uuid", "p_service_id" "uuid", "p_rows" "jsonb", "p_branch_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_service_prices"("p_species_id" "uuid", "p_service_id" "uuid", "p_rows" "jsonb", "p_branch_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_shop_settings"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_shop_settings"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_shop_settings"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_spa_resource"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_spa_resource"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_spa_resource"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_species"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_species"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_species"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_staff_branches"("p_user" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_staff_branches"("p_user" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_staff_branches"("p_user" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_stock_document"("p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_stock_document"("p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_stock_document"("p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_vaccine_type"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_vaccine_type"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_vaccine_type"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."save_weight_brackets"("p_species_id" "uuid", "p_rows" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."save_weight_brackets"("p_species_id" "uuid", "p_rows" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."save_weight_brackets"("p_species_id" "uuid", "p_rows" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."schedule_medical_visit"("p" "jsonb", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."schedule_medical_visit"("p" "jsonb", "p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."schedule_medical_visit"("p" "jsonb", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."search_customers"("p_text" "text", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_customers"("p_text" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_customers"("p_text" "text", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."search_unlinked_accounts"("p_text" "text", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."search_unlinked_accounts"("p_text" "text", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_unlinked_accounts"("p_text" "text", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."seed_default_weight_brackets"("p_species_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."seed_default_weight_brackets"("p_species_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."seed_default_weight_brackets"("p_species_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sellable_stock"("p_branch" "uuid", "p_products" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sellable_stock"("p_branch" "uuid", "p_products" "uuid"[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."sellable_stock"("p_branch" "uuid", "p_products" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_appointment_item_status"("p_item" "uuid", "p_status" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_appointment_item_status"("p_item" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_appointment_item_status"("p_item" "uuid", "p_status" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_default_my_address"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_default_my_address"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_default_my_address"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_kennel_status"("p_id" "uuid", "p_status" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_kennel_status"("p_id" "uuid", "p_status" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_kennel_status"("p_id" "uuid", "p_status" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_min_stock"("p_branch" "uuid", "p_product" "uuid", "p_min" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_min_stock"("p_branch" "uuid", "p_product" "uuid", "p_min" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_min_stock"("p_branch" "uuid", "p_product" "uuid", "p_min" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_pet_photo"("p_pet" "uuid", "p_path" "text", "p_url" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_pet_photo"("p_pet" "uuid", "p_path" "text", "p_url" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_pet_photo"("p_pet" "uuid", "p_path" "text", "p_url" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_product_branch_prices"("p_product" "uuid", "p_prices" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_product_branch_prices"("p_product" "uuid", "p_prices" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_product_branch_prices"("p_product" "uuid", "p_prices" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_product_group_active"("p_group" "uuid", "p_active" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_product_group_active"("p_group" "uuid", "p_active" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_product_group_active"("p_group" "uuid", "p_active" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_product_group_clinic_only"("p_group" "uuid", "p_value" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_product_group_clinic_only"("p_group" "uuid", "p_value" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_product_group_clinic_only"("p_group" "uuid", "p_value" boolean) TO "service_role";



REVOKE ALL ON FUNCTION "public"."set_staff_does_services"("p_user" "uuid", "p_branch" "uuid", "p_value" boolean) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."set_staff_does_services"("p_user" "uuid", "p_branch" "uuid", "p_value" boolean) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_staff_does_services"("p_user" "uuid", "p_branch" "uuid", "p_value" boolean) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_updated_at"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."ship_shop_order"("p_id" "uuid", "p_tracking_code" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."ship_shop_order"("p_id" "uuid", "p_tracking_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."ship_shop_order"("p_id" "uuid", "p_tracking_code" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_admin_settings"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_admin_settings"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."shop_admin_settings"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_available_qty"("p_products" "uuid"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_available_qty"("p_products" "uuid"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_cart_lines"("p_lines" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_cart_lines"("p_lines" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."shop_cart_lines"("p_lines" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."shop_cart_lines"("p_lines" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_order_badge"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_order_badge"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."shop_order_badge"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_order_cancel_invoice"("p_invoice" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_order_cancel_invoice"("p_invoice" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_order_for_update"("p_id" "uuid", "p_from" "text"[]) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_order_for_update"("p_id" "uuid", "p_from" "text"[]) TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_order_log"("p_id" "uuid", "p_status" "text", "p_note" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_order_log"("p_id" "uuid", "p_status" "text", "p_note" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_product_groups"("p_search" "text", "p_category" "uuid", "p_brand" "uuid", "p_sort" "text", "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_product_groups"("p_search" "text", "p_category" "uuid", "p_brand" "uuid", "p_sort" "text", "p_limit" integer, "p_offset" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."shop_product_groups"("p_search" "text", "p_category" "uuid", "p_brand" "uuid", "p_sort" "text", "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."shop_product_groups"("p_search" "text", "p_category" "uuid", "p_brand" "uuid", "p_sort" "text", "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_public_settings"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_public_settings"() TO "anon";
GRANT ALL ON FUNCTION "public"."shop_public_settings"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."shop_public_settings"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."shop_related_groups"("p_group" "uuid", "p_limit" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."shop_related_groups"("p_group" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."shop_related_groups"("p_group" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."shop_related_groups"("p_group" "uuid", "p_limit" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."sign_medical_visit"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sign_medical_visit"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."sign_medical_visit"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."skip_inpatient_dose"("p_dose" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."skip_inpatient_dose"("p_dose" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."skip_inpatient_dose"("p_dose" "uuid", "p_reason" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."slugify"("p_text" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."slugify"("p_text" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."slugify"("p_text" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_block_is_free"("p_branch" "uuid", "p_start" timestamp with time zone, "p_minutes" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_block_is_free"("p_branch" "uuid", "p_start" timestamp with time zone, "p_minutes" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_day_board"("p_branch" "uuid", "p_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_day_board"("p_branch" "uuid", "p_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spa_day_board"("p_branch" "uuid", "p_date" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_hours"("p_branch" "uuid", "p_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_hours"("p_branch" "uuid", "p_date" "date") TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_public_catalog"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_public_catalog"("p_branch" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."spa_public_catalog"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spa_public_catalog"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_ticket_quote"("p_branch" "uuid", "p_pet" "uuid", "p_type" "text", "p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_ticket_quote"("p_branch" "uuid", "p_pet" "uuid", "p_type" "text", "p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_web_quote"("p_branch" "uuid", "p_items" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_web_quote"("p_branch" "uuid", "p_items" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spa_web_quote"("p_branch" "uuid", "p_items" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_web_rules"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_web_rules"() TO "anon";
GRANT ALL ON FUNCTION "public"."spa_web_rules"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."spa_web_rules"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_web_slots"("p_branch" "uuid", "p_date" "date", "p_minutes" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_web_slots"("p_branch" "uuid", "p_date" "date", "p_minutes" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."spa_web_slots"("p_branch" "uuid", "p_date" "date", "p_minutes" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."spa_web_slots"("p_branch" "uuid", "p_date" "date", "p_minutes" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."spa_week_hours"("p_branch" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."spa_week_hours"("p_branch" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."spa_week_hours"("p_branch" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."staff_display_name"("p_user" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."staff_display_name"("p_user" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."staff_shop_order_json"("o" "public"."shop_orders") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."staff_shop_order_json"("o" "public"."shop_orders") TO "service_role";



REVOKE ALL ON FUNCTION "public"."start_medical_visit"("p_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."start_medical_visit"("p_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."start_medical_visit"("p_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."stock_alert_counts"("p_branch" "uuid", "p_expiry_days" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."stock_alert_counts"("p_branch" "uuid", "p_expiry_days" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."stock_alert_counts"("p_branch" "uuid", "p_expiry_days" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."stock_rows"("p_branch" "uuid", "p_expiry_days" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."stock_rows"("p_branch" "uuid", "p_expiry_days" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."stock_summary"("p_branch" "uuid", "p_search" "text", "p_status" "text", "p_expiry_days" integer, "p_limit" integer, "p_offset" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."stock_summary"("p_branch" "uuid", "p_search" "text", "p_status" "text", "p_expiry_days" integer, "p_limit" integer, "p_offset" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."stock_summary"("p_branch" "uuid", "p_search" "text", "p_status" "text", "p_expiry_days" integer, "p_limit" integer, "p_offset" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."stop_inpatient_order"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."stop_inpatient_order"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."stop_inpatient_order"("p_id" "uuid", "p_reason" "text") TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_user_email"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_user_email"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."take_stock_fefo"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_invoice" "uuid", "p_invoice_line" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."take_stock_fefo"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_invoice" "uuid", "p_invoice_line" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."take_stock_lot_first"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_lot" "uuid", "p_invoice" "uuid", "p_invoice_line" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."take_stock_lot_first"("p_branch" "uuid", "p_product" "uuid", "p_qty" numeric, "p_lot" "uuid", "p_invoice" "uuid", "p_invoice_line" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_inpatient_order"("p_id" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_inpatient_order"("p_id" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_inpatient_order"("p_id" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_medical_item"("p_id" "uuid", "p" "jsonb") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_medical_item"("p_id" "uuid", "p" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_medical_item"("p_id" "uuid", "p" "jsonb") TO "service_role";



REVOKE ALL ON FUNCTION "public"."vaccine_lots"("p_branch" "uuid", "p_vaccine_type" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."vaccine_lots"("p_branch" "uuid", "p_vaccine_type" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."vaccine_lots"("p_branch" "uuid", "p_vaccine_type" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."void_vaccination"("p_id" "uuid", "p_reason" "text") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."void_vaccination"("p_id" "uuid", "p_reason" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."void_vaccination"("p_id" "uuid", "p_reason" "text") TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."appointment_items" TO "authenticated";
GRANT ALL ON TABLE "public"."appointment_items" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."appointments" TO "authenticated";
GRANT ALL ON TABLE "public"."appointments" TO "service_role";



GRANT ALL ON TABLE "public"."banners" TO "anon";
GRANT ALL ON TABLE "public"."banners" TO "authenticated";
GRANT ALL ON TABLE "public"."banners" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boarding_care_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."boarding_care_logs" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boarding_charges" TO "authenticated";
GRANT ALL ON TABLE "public"."boarding_charges" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boarding_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."boarding_settings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."boarding_stay_pets" TO "authenticated";
GRANT ALL ON TABLE "public"."boarding_stay_pets" TO "service_role";



GRANT ALL ON TABLE "public"."bookings" TO "anon";
GRANT ALL ON TABLE "public"."bookings" TO "authenticated";
GRANT ALL ON TABLE "public"."bookings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."branch_hours" TO "authenticated";
GRANT ALL ON TABLE "public"."branch_hours" TO "service_role";



GRANT ALL ON TABLE "public"."branches" TO "anon";
GRANT ALL ON TABLE "public"."branches" TO "authenticated";
GRANT ALL ON TABLE "public"."branches" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."cash_shifts" TO "authenticated";
GRANT ALL ON TABLE "public"."cash_shifts" TO "service_role";



GRANT ALL ON TABLE "public"."combo_services" TO "anon";
GRANT ALL ON TABLE "public"."combo_services" TO "authenticated";
GRANT ALL ON TABLE "public"."combo_services" TO "service_role";



GRANT ALL ON TABLE "public"."combo_species" TO "anon";
GRANT ALL ON TABLE "public"."combo_species" TO "authenticated";
GRANT ALL ON TABLE "public"."combo_species" TO "service_role";



GRANT ALL ON TABLE "public"."customers" TO "anon";
GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."diagnosis_terms" TO "authenticated";
GRANT ALL ON TABLE "public"."diagnosis_terms" TO "service_role";



GRANT ALL ON TABLE "public"."doc_sequences" TO "anon";
GRANT ALL ON TABLE "public"."doc_sequences" TO "authenticated";
GRANT ALL ON TABLE "public"."doc_sequences" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."inpatient_doses" TO "authenticated";
GRANT ALL ON TABLE "public"."inpatient_doses" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."inpatient_order_changes" TO "authenticated";
GRANT ALL ON TABLE "public"."inpatient_order_changes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoice_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."invoice_lines" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."invoices" TO "authenticated";
GRANT ALL ON TABLE "public"."invoices" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kennel_type_prices" TO "authenticated";
GRANT ALL ON TABLE "public"."kennel_type_prices" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kennel_types" TO "authenticated";
GRANT ALL ON TABLE "public"."kennel_types" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."kennels" TO "authenticated";
GRANT ALL ON TABLE "public"."kennels" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_addenda" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_addenda" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_attachments" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_attachments" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_diagnoses" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_diagnoses" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_settings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."medical_visit_items" TO "authenticated";
GRANT ALL ON TABLE "public"."medical_visit_items" TO "service_role";



GRANT ALL ON TABLE "public"."order_items" TO "anon";
GRANT ALL ON TABLE "public"."order_items" TO "authenticated";
GRANT ALL ON TABLE "public"."order_items" TO "service_role";



GRANT ALL ON TABLE "public"."orders" TO "anon";
GRANT ALL ON TABLE "public"."orders" TO "authenticated";
GRANT ALL ON TABLE "public"."orders" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";



GRANT ALL ON TABLE "public"."permissions" TO "anon";
GRANT ALL ON TABLE "public"."permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."permissions" TO "service_role";



GRANT ALL ON TABLE "public"."pet_owners" TO "anon";
GRANT ALL ON TABLE "public"."pet_owners" TO "authenticated";
GRANT ALL ON TABLE "public"."pet_owners" TO "service_role";



GRANT ALL ON TABLE "public"."pet_weight_logs" TO "anon";
GRANT ALL ON TABLE "public"."pet_weight_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."pet_weight_logs" TO "service_role";



GRANT ALL ON TABLE "public"."pets" TO "anon";
GRANT ALL ON TABLE "public"."pets" TO "authenticated";
GRANT ALL ON TABLE "public"."pets" TO "service_role";



GRANT ALL ON TABLE "public"."species" TO "anon";
GRANT ALL ON TABLE "public"."species" TO "authenticated";
GRANT ALL ON TABLE "public"."species" TO "service_role";



GRANT ALL ON TABLE "public"."weight_brackets" TO "anon";
GRANT ALL ON TABLE "public"."weight_brackets" TO "authenticated";
GRANT ALL ON TABLE "public"."weight_brackets" TO "service_role";



GRANT ALL ON TABLE "public"."pet_overview" TO "anon";
GRANT ALL ON TABLE "public"."pet_overview" TO "authenticated";
GRANT ALL ON TABLE "public"."pet_overview" TO "service_role";



GRANT ALL ON TABLE "public"."pet_service_combos" TO "anon";
GRANT ALL ON TABLE "public"."pet_service_combos" TO "authenticated";
GRANT ALL ON TABLE "public"."pet_service_combos" TO "service_role";



GRANT ALL ON TABLE "public"."pet_service_prices" TO "anon";
GRANT ALL ON TABLE "public"."pet_service_prices" TO "authenticated";
GRANT ALL ON TABLE "public"."pet_service_prices" TO "service_role";



GRANT ALL ON TABLE "public"."pet_services" TO "anon";
GRANT ALL ON TABLE "public"."pet_services" TO "authenticated";
GRANT ALL ON TABLE "public"."pet_services" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_attribute_values" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_attribute_values" TO "authenticated";
GRANT ALL ON TABLE "public"."product_attribute_values" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_attributes" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_attributes" TO "authenticated";
GRANT ALL ON TABLE "public"."product_attributes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_branch_prices" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_branch_prices" TO "authenticated";
GRANT ALL ON TABLE "public"."product_branch_prices" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_brands" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_brands" TO "authenticated";
GRANT ALL ON TABLE "public"."product_brands" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_categories" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."product_categories" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_group_attributes" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_group_attributes" TO "authenticated";
GRANT ALL ON TABLE "public"."product_group_attributes" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_groups" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."product_groups" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_images" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_images" TO "authenticated";
GRANT ALL ON TABLE "public"."product_images" TO "service_role";



GRANT REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_imports" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_imports" TO "authenticated";
GRANT ALL ON TABLE "public"."product_imports" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_units" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_units" TO "authenticated";
GRANT ALL ON TABLE "public"."product_units" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_variant_values" TO "anon";
GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."product_variant_values" TO "authenticated";
GRANT ALL ON TABLE "public"."product_variant_values" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."role_permissions" TO "anon";
GRANT ALL ON TABLE "public"."role_permissions" TO "authenticated";
GRANT ALL ON TABLE "public"."role_permissions" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_return_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_return_lines" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."sales_returns" TO "authenticated";
GRANT ALL ON TABLE "public"."sales_returns" TO "service_role";



GRANT ALL ON TABLE "public"."service_providers" TO "anon";
GRANT ALL ON TABLE "public"."service_providers" TO "authenticated";
GRANT ALL ON TABLE "public"."service_providers" TO "service_role";



GRANT ALL ON TABLE "public"."service_species" TO "anon";
GRANT ALL ON TABLE "public"."service_species" TO "authenticated";
GRANT ALL ON TABLE "public"."service_species" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_order_events" TO "authenticated";
GRANT ALL ON TABLE "public"."shop_order_events" TO "service_role";



GRANT ALL ON SEQUENCE "public"."shop_order_events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."shop_order_events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."shop_order_events_id_seq" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_order_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."shop_order_lines" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."shop_settings" TO "authenticated";
GRANT ALL ON TABLE "public"."shop_settings" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."spa_resources" TO "authenticated";
GRANT ALL ON TABLE "public"."spa_resources" TO "service_role";



GRANT ALL ON TABLE "public"."staff_branches" TO "anon";
GRANT ALL ON TABLE "public"."staff_branches" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_branches" TO "service_role";
GRANT SELECT ON TABLE "public"."staff_branches" TO "supabase_auth_admin";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_document_lines" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_document_lines" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_documents" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_documents" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_lots" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_lots" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_movements" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_movements" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."stock_thresholds" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_thresholds" TO "service_role";



GRANT SELECT,INSERT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN,UPDATE ON TABLE "public"."suppliers" TO "authenticated";
GRANT ALL ON TABLE "public"."suppliers" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";
GRANT SELECT ON TABLE "public"."users" TO "supabase_auth_admin";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vaccinations" TO "authenticated";
GRANT ALL ON TABLE "public"."vaccinations" TO "service_role";



GRANT SELECT,REFERENCES,TRIGGER,TRUNCATE,MAINTAIN ON TABLE "public"."vaccine_types" TO "authenticated";
GRANT ALL ON TABLE "public"."vaccine_types" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







