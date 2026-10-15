-- Medical records, step 2 (3/3): the RPCs that read visits
-- (docs/ho-so-benh-an.md, section 6). Runs after 20261021020100_medical_visit_rpcs.sql.
-- Safe to run more than once.
--
-- Reading follows rule 5.1: a pet's whole history is visible to anyone holding medical VIEW at any
-- branch; the queue and the visit list are per branch.

-- ------------------------------------------------------------------ one row
-- A visit as the lists show it. diagnoses_text joins the diagnosis names in order.
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
    )
  );
$$;

revoke execute on function public.medical_visit_json(public.medical_visits) from public, anon, authenticated;

-- ------------------------------------------------------------------- queue
-- The day's queue of a branch: booked visits of the day, waiting, in progress and done (not yet
-- paid). For today it also carries older visits still waiting, open or unpaid. Urgent cases first,
-- then by check-in time.
-- { date, counts: { scheduled, waiting, in_progress, done },
--   rows: [visit + { has_allergy, has_behavior, contagious }] }
create or replace function public.medical_queue(p_branch uuid, p_date date default null) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.medical_queue(uuid, date) from public, anon;
grant execute on function public.medical_queue(uuid, date) to authenticated;

-- ---------------------------------------------------------------- the list
-- { total, rows: [visit] } for the visit table. The date filter uses the day of the check-in, else
-- the booked day. Search matches the code, the owner's name (accents ignored) and phone, the pet's
-- name and the diagnoses.
create or replace function public.list_medical_visits(
  p_branch    uuid,
  p_from      date default null,
  p_to        date default null,
  p_status    text default null,
  p_vet       uuid default null,
  p_search    text default null,
  p_page      int default 1,
  p_page_size int default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.list_medical_visits(uuid, date, date, text, uuid, text, int, int) from public, anon;
grant execute on function public.list_medical_visits(uuid, date, date, text, uuid, text, int, int) to authenticated;

-- ---------------------------------------------------------------- one visit
-- The whole visit: its columns, the pet (with the latest weight), the owner, the diagnoses and
-- the addenda, and the booked re-check if any.
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
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.get_medical_visit(uuid) from public, anon;
grant execute on function public.get_medical_visit(uuid) to authenticated;

-- ------------------------------------------------------------------ history
-- A pet's visits, newest first: the ones that were examined or are open (booked, cancelled and
-- no-show visits are left out). { total, rows: [visit + { branch_name }] }
create or replace function public.pet_medical_history(
  p_pet       uuid,
  p_page      int default 1,
  p_page_size int default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.pet_medical_history(uuid, int, int) from public, anon;
grant execute on function public.pet_medical_history(uuid, int, int) to authenticated;

-- ------------------------------------------------------------------- vets
-- The people who can be the vet of a visit at a branch: staff holding medical UPDATE there, and
-- admin accounts. [{ id, name }]
create or replace function public.medical_vets(p_branch uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.medical_vets(uuid) from public, anon;
grant execute on function public.medical_vets(uuid) to authenticated;

notify pgrst, 'reload schema';
