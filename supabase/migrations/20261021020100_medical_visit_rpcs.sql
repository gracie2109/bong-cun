-- Medical records, step 2 (2/3): the RPCs that write a visit
-- (docs/ho-so-benh-an.md, sections 3, 5 and 6). Runs after 20261021020000_medical_visits.sql.
-- Safe to run more than once.
--
-- Refusals carry a `hint` the screen turns into text:
--   bad_input, not_found, no_customer, no_pet (detail: pet), pet_deceased (detail: pet),
--   pet_busy (detail: code of the open visit), bad_vet, not_scheduled, not_waiting,
--   taken (detail: the vet who took it), not_in_progress, signed, no_outcome, no_assessment,
--   bad_recheck, inpatient_unavailable, not_editable, not_due.
-- Billing is added by step 3; until then a signed visit stays `done`.

-- -------------------------------------------------------------------- helpers
-- Whether a user may write clinical notes at a branch: an admin account, or a staff member whose
-- role there holds medical UPDATE. Used to pick and check the vet of a visit.
create or replace function public.medical_user_can_update(p_user uuid, p_branch uuid) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.users u where u.id = p_user and u.role in ('admin', 'superAdmin'))
      or exists (
        select 1
        from public.staff_branches sb
        join public.role_permissions rp on rp.role = sb.role
        where sb.user_id = p_user and sb.branch_id = p_branch
          and rp.permission = 'medical' and rp.methods && array['UPDATE', 'ALL']
      );
$$;

revoke execute on function public.medical_user_can_update(uuid, uuid) from public, anon, authenticated;

-- Checks that the customer exists and owns the pet now, and the pet is alive.
-- Returns { pet_name, customer_name, customer_phone }.
create or replace function public.medical_check_pet(p_customer uuid, p_pet uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.medical_check_pet(uuid, uuid) from public, anon, authenticated;

-- ------------------------------------------------------------------- check in
-- p: { branch_id, customer_id, pet_id, reason?, priority?, vet_id?, weight_kg?, temperature_c?,
--      source?, visit_id? }
-- With visit_id the booked visit is checked in (branch, customer and pet are taken from it);
-- without it a new walk-in visit is created. The weight is also logged on the pet.
-- Returns { id, code, queue_no }.
create or replace function public.check_in_medical_visit(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.check_in_medical_visit(jsonb) from public, anon;
grant execute on function public.check_in_medical_visit(jsonb) to authenticated;

-- --------------------------------------------------------------- book ahead
-- p: { branch_id, customer_id, pet_id, scheduled_at, reason?, vet_id?, source? }
-- Creates a booked visit, or with p_id changes the time, reason and vet of one still booked.
-- Returns the id.
create or replace function public.schedule_medical_visit(p jsonb, p_id uuid default null) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.schedule_medical_visit(jsonb, uuid) from public, anon;
grant execute on function public.schedule_medical_visit(jsonb, uuid) to authenticated;

-- -------------------------------------------------------------------- take a case
-- The vet takes a waiting visit. The vet stays the one named at check-in, else becomes the caller.
-- Step 3 re-creates this function to add the default exam service.
create or replace function public.start_medical_visit(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := (select auth.uid());
  v_visit public.medical_visits;
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
end;
$$;

revoke execute on function public.start_medical_visit(uuid) from public, anon;
grant execute on function public.start_medical_visit(uuid) to authenticated;

-- Changes the vet of a visit that is not signed; null clears it (not while the case is open).
create or replace function public.assign_medical_vet(p_id uuid, p_vet uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.assign_medical_vet(uuid, uuid) from public, anon;
grant execute on function public.assign_medical_vet(uuid, uuid) to authenticated;

-- --------------------------------------------------------------- the record
-- p: any of { weight_kg, temperature_c, heart_rate, resp_rate, vitals_note, subjective, objective,
--             assessment, plan, owner_instructions, outcome, recheck_on,
--             diagnoses: [{ term_id?, name?, is_contagious?, note? }] }
-- A field that is missing keeps its value; a field sent as null or '' clears it. `diagnoses`
-- replaces the whole list (a term_id copies the name and the contagious flag from the catalog).
-- Only the open case (in_progress, not signed). Returns the time of the save.
create or replace function public.save_medical_record(p_id uuid, p jsonb) returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.save_medical_record(uuid, jsonb) from public, anon;
grant execute on function public.save_medical_record(uuid, jsonb) to authenticated;

-- --------------------------------------------------------------------- sign
-- Finishes the exam: needs an outcome and a diagnosis or an assessment, locks the clinical
-- content, books the re-check, and marks a pet that died. Returns { id, status, recheck_visit_id }.
-- Step 3 re-creates this function so a visit with nothing to pay becomes `paid` at once.
create or replace function public.sign_medical_visit(p_id uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  if v_visit.outcome = 'inpatient' then
    raise exception 'in-patient care is not available yet' using errcode = '22023', hint = 'inpatient_unavailable';
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

  return jsonb_build_object('id', p_id, 'status', 'done', 'recheck_visit_id', v_child);
end;
$$;

revoke execute on function public.sign_medical_visit(uuid) from public, anon;
grant execute on function public.sign_medical_visit(uuid) to authenticated;

-- A correction after signing. Never edited, never deleted.
create or replace function public.add_medical_addendum(p_id uuid, p_content text) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.add_medical_addendum(uuid, text) from public, anon;
grant execute on function public.add_medical_addendum(uuid, text) to authenticated;

-- ---------------------------------------------------------- cancel / no-show
-- A booked or waiting visit, or an open case that is not signed. Step 3 re-creates this function to
-- also refuse a case that already has billable lines.
create or replace function public.cancel_medical_visit(p_id uuid, p_reason text default null) returns void
language plpgsql
security definer
set search_path = ''
as $$
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
  update public.medical_visits set
    status = 'cancelled',
    cancelled_at = now(),
    cancel_reason = nullif(btrim(p_reason), '')
  where id = p_id;
end;
$$;

revoke execute on function public.cancel_medical_visit(uuid, text) from public, anon;
grant execute on function public.cancel_medical_visit(uuid, text) to authenticated;

-- A booked visit whose day has passed and the owner did not come.
create or replace function public.mark_medical_no_show(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.mark_medical_no_show(uuid) from public, anon;
grant execute on function public.mark_medical_no_show(uuid) to authenticated;

notify pgrst, 'reload schema';
