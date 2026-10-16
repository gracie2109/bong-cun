-- The ward board now also carries each order's product/service, how many times it was edited, how many
-- doses were missed and the quantity given per dose. It is its own file (later than the pet photo
-- migration) because that migration also re-creates inpatient_ward and this keeps both changes.
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
