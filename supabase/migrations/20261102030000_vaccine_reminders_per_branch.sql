-- Vaccine reminders belong to the branch that gave the pet's last dose, so a branch's "overdue" count is
-- its own work. Doses with no branch recorded keep showing at every branch.

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
      v.id, v.pet_id, v.branch_id, v.vaccine_type_id, v.given_on, v.next_due_on, v.reminded_at, v.remind_note, v.reminded_by
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
      -- The branch that gave the last dose follows it up; doses without a branch (entered before branches
      -- were tracked) stay visible everywhere.
      and (s.branch_id = p_branch or s.branch_id is null)
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
