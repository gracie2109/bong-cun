-- Medical records, step 7 (2/4): warning flags for the spa and pet hotel counters
-- (docs/ho-so-benh-an.md, rule 17). Safe to run more than once.
--
-- Before: check-in at the spa or the pet hotel knows nothing about a pet's recent illness.
-- After: pet_health_flags(pet ids) returns, per pet, whether a contagious disease was diagnosed
-- recently (within the longest "contagious days" setting), whether a vaccine is overdue, and the
-- allergy note. It gives flags only, never diagnoses or visits, so any staff member can call it.

create or replace function public.pet_health_flags(p_pet_ids uuid[]) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.pet_health_flags(uuid[]) from public, anon;
grant execute on function public.pet_health_flags(uuid[]) to authenticated;

notify pgrst, 'reload schema';
