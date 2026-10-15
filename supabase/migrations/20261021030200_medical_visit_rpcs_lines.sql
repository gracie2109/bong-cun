-- Medical records, step 3 (3/3): the visit functions that now know about lines
-- (docs/ho-so-benh-an.md, sections 5 and 6). Runs after 20261021030100_medical_item_rpcs.sql.
-- Safe to run more than once. Each function below is the step 2 version plus the lines part:
--   medical_visit_json    + est_total (what the visit will cost)
--   get_medical_visit     + items
--   start_medical_visit   + the default exam service
--   sign_medical_visit    + a visit with nothing to charge becomes `paid` at once
--   cancel_medical_visit  + refuses a case that already has lines (the automatic exam line goes)

create or replace function public.medical_visit_json(v public.medical_visits) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.medical_visit_json(public.medical_visits) from public, anon, authenticated;

create or replace function public.get_medical_visit(p_id uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.get_medical_visit(uuid) from public, anon;
grant execute on function public.get_medical_visit(uuid) to authenticated;

create or replace function public.start_medical_visit(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.start_medical_visit(uuid) from public, anon;
grant execute on function public.start_medical_visit(uuid) to authenticated;

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

  -- A visit with nothing to charge is paid at once.
  perform public.medical_refresh_status(p_id);

  return jsonb_build_object(
    'id', p_id,
    'status', (select status from public.medical_visits where id = p_id),
    'recheck_visit_id', v_child);
end;
$$;

revoke execute on function public.sign_medical_visit(uuid) from public, anon;
grant execute on function public.sign_medical_visit(uuid) to authenticated;

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

revoke execute on function public.cancel_medical_visit(uuid, text) from public, anon;
grant execute on function public.cancel_medical_visit(uuid, text) to authenticated;

-- Visits signed in step 2 had no lines: they have nothing to charge.
select public.medical_refresh_status(id) from public.medical_visits where signed_at is not null and status = 'done';

notify pgrst, 'reload schema';
