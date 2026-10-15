-- Medical records, step 7 (1/4): the customer's health book, read only (docs/ho-so-benh-an.md, 9).
-- Safe to run more than once.
--
-- Before: the web account shows a pet's profile and nothing about its health.
-- After: my_pet_health(pet) gives the owner the vaccination book and the list of signed visits
-- (date, reason, diagnoses, instructions, medicine to take home, re-check date). It never returns
-- the SOAP note, vitals or prices. my_pets() gains the next vaccine due. Customers read only.

create or replace function public.my_pet_health(p_pet uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
  where p.id = p_pet and po.customer_id = v_cust and po.to_date is null and p.status = 'active';
  if not found then
    raise exception 'pet not found' using errcode = 'P0002', hint = 'not_found';
  end if;

  return jsonb_build_object(
    'pet_id', v_pet.id,
    'pet_name', v_pet.name,
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
          'next_due_on', last.next_due_on,
          'state', case
            when last.next_due_on is null then 'ok'
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

revoke execute on function public.my_pet_health(uuid) from public, anon;
grant execute on function public.my_pet_health(uuid) to authenticated;

-- The pet list of the account (20261018030000_my_pets.sql) with the next vaccine due.
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
               ),
               'next_vaccine', (
                 select jsonb_build_object('name', t.name, 'due_on', l.next_due_on)
                 from public.vaccine_types t
                 join lateral (
                   select v.next_due_on from public.vaccinations v
                   where v.pet_id = p.id and v.vaccine_type_id = t.id and v.voided_at is null
                   order by v.given_on desc, v.created_at desc limit 1
                 ) l on true
                 where l.next_due_on is not null
                 order by l.next_due_on, t.name
                 limit 1
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

notify pgrst, 'reload schema';
