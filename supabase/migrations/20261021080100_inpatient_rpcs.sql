-- Medical records, step 8 (2/2): admit, order, give, discharge (docs/ho-so-benh-an.md, section 6).
-- Runs after 20261021080000_inpatient.sql. Safe to run more than once.
--
-- Refusals carry a hint: not_found, not_editable, bad_input, no_kennel, need_isolation, kennel_taken,
-- pet_busy, already_admitted, already_done, inpatient_active.

-- ------------------------------------------------------------------ kennels
-- The medical and isolation kennels of a branch, and whether each is free tonight.
create or replace function public.inpatient_kennels(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.inpatient_kennels(uuid) from public, anon;
grant execute on function public.inpatient_kennels(uuid) to authenticated;

-- ------------------------------------------------------------------- admit
-- p: { kennel_id, planned_out_at?, note? }. The pet of an open (in progress, unsigned) visit goes
-- into a medical or isolation kennel; a pet with a contagious diagnosis needs an isolation kennel.
-- Returns { stay_id, stay_pet_id, code }.
create or replace function public.admit_inpatient(p_visit uuid, p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.admit_inpatient(uuid, jsonb) from public, anon;
grant execute on function public.admit_inpatient(uuid, jsonb) to authenticated;

-- --------------------------------------------------------------- the orders
-- p: { stay_pet_id, kind: 'product' | 'service' | 'care', product_id | service_id | name, dose?,
--      qty_per_dose?, times: ['08:00', '20:00'], start_on?, end_on?, note? }
-- Makes one dose per day and hour. Returns the order id.
create or replace function public.save_inpatient_order(p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
  return v_id;
end;
$$;

revoke execute on function public.save_inpatient_order(jsonb) from public, anon;
grant execute on function public.save_inpatient_order(jsonb) to authenticated;

-- Stops an order: the doses that are still waiting are dropped, what was given stays.
create or replace function public.stop_inpatient_order(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
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
  update public.inpatient_orders set stopped_at = coalesce(stopped_at, now()) where id = p_id;
  delete from public.inpatient_doses
  where order_id = p_id and given_at is null and skipped_reason is null and due_at > now();
end;
$$;

revoke execute on function public.stop_inpatient_order(uuid) from public, anon;
grant execute on function public.stop_inpatient_order(uuid) to authenticated;

-- --------------------------------------------------------------- the doses
-- Ticks a dose as given. A medicine or service adds its quantity to one line of the visit, so the
-- cashier bills it after the vet signs. Returns { warnings } (low_stock).
create or replace function public.give_inpatient_dose(p_dose uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
  set given_at = now(), given_by = v_uid, given_by_name = public.staff_display_name(v_uid)
  where id = p_dose;
  return jsonb_build_object('warnings', coalesce(v_res -> 'warnings', '[]'::jsonb));
end;
$$;

revoke execute on function public.give_inpatient_dose(uuid) from public, anon;
grant execute on function public.give_inpatient_dose(uuid) to authenticated;

create or replace function public.skip_inpatient_dose(p_dose uuid, p_reason text) returns void
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.skip_inpatient_dose(uuid, text) from public, anon;
grant execute on function public.skip_inpatient_dose(uuid, text) to authenticated;

-- A vital sign reading or a treatment note on the care log (hidden from the customer).
-- p: { kind: 'vitals' | 'treatment' | 'note', content }
create or replace function public.add_inpatient_log(p_stay_pet uuid, p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.add_inpatient_log(uuid, jsonb) from public, anon;
grant execute on function public.add_inpatient_log(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------- the ward
-- The in-patients of a branch with the orders and the doses of one day (default today).
create or replace function public.inpatient_ward(p_branch uuid, p_date date default null) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
          'id', o.id, 'kind', o.kind, 'name', o.name, 'dose', o.dose, 'qty_per_dose', o.qty_per_dose,
          'times', o.times, 'start_on', o.start_on, 'end_on', o.end_on, 'note', o.note,
          'stopped', o.stopped_at is not null
        ) order by o.created_at)
        from public.inpatient_orders o where o.stay_pet_id = sp.id and o.stopped_at is null
      ), '[]'::jsonb),
      'doses', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', d.id, 'order_id', d.order_id, 'due_at', d.due_at, 'given_at', d.given_at,
          'given_by_name', d.given_by_name, 'skipped_reason', d.skipped_reason
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

revoke execute on function public.inpatient_ward(uuid, date) from public, anon;
grant execute on function public.inpatient_ward(uuid, date) to authenticated;

-- ------------------------------------------------------------- discharge
-- Check-out of the stay (the same calculation as the pet hotel: kennel nights, late fee), orders
-- stopped, kennel to cleaning. The visit stays in progress until the vet signs it; the kennel
-- charges are paid in the POS "boarding" box and the medicine in the "medical" box.
create or replace function public.discharge_inpatient(p_stay uuid) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.discharge_inpatient(uuid) from public, anon;
grant execute on function public.discharge_inpatient(uuid) to authenticated;

-- ------------------------------------------------------------------- signing
-- sign_medical_visit (20261021030200) again, without the refusal of the 'inpatient' outcome. The guard
-- trigger of 20261021080000 keeps a visit unsigned while the pet is still in the kennel.
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

notify pgrst, 'reload schema';
