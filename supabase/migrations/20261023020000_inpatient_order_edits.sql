-- Before: an in-patient order could only be added or stopped. A wrong dose or hour meant stopping the
-- order and typing a new one, nothing recorded who changed what, a given dose did not remember its own
-- quantity, and only the visit RPCs (not the database) kept a signed visit's orders from changing.
-- After: an order can be edited (dose text, quantity per dose, hours, end date, note; the start date
-- until a dose is recorded) and replaced by another medicine in one step; every create, edit, stop and
-- replace lands in inpatient_order_changes; each given dose stores its quantity; triggers refuse any
-- change to the orders and doses of a signed visit (hint signed).

-- ----------------------------------------------------------------- data
alter table public.inpatient_doses add column if not exists qty numeric(10,2);
update public.inpatient_doses d set qty = o.qty_per_dose
from public.inpatient_orders o
where d.order_id = o.id and d.given_at is not null and d.qty is null;

create table if not exists public.inpatient_order_changes (
  id               uuid primary key default gen_random_uuid(),
  order_id         uuid not null references public.inpatient_orders(id) on delete cascade,
  visit_id         uuid not null references public.medical_visits(id) on delete cascade,
  action           text not null check (action in ('create', 'update', 'stop', 'replace')),
  before           jsonb,
  after            jsonb,
  reason           text,
  changed_by       uuid references auth.users(id) on delete set null,
  changed_by_name  text,
  changed_at       timestamptz not null default now()
);
create index if not exists inpatient_order_changes_order_idx on public.inpatient_order_changes (order_id, changed_at desc);

alter table public.inpatient_order_changes enable row level security;
drop policy if exists "medical read" on public.inpatient_order_changes;
create policy "medical read" on public.inpatient_order_changes for select to authenticated
  using ((select public.can_medical('VIEW')));
revoke insert, update, delete on public.inpatient_order_changes from anon, authenticated;
revoke all on public.inpatient_order_changes from anon;

-- ----------------------------------------------------------------- the signed lock
-- A signed visit is a medical record: its orders and doses never change again (add a note instead).
create or replace function public.inpatient_signed_lock() returns trigger
language plpgsql
set search_path = ''
as $$
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

drop trigger if exists inpatient_orders_signed_lock on public.inpatient_orders;
create trigger inpatient_orders_signed_lock before insert or update or delete on public.inpatient_orders
  for each row execute function public.inpatient_signed_lock();
drop trigger if exists inpatient_doses_signed_lock on public.inpatient_doses;
create trigger inpatient_doses_signed_lock before insert or update or delete on public.inpatient_doses
  for each row execute function public.inpatient_signed_lock();

-- One change-log line, written by the RPCs below (the table has no client write policy).
create or replace function public.inpatient_log_change(
  p_order uuid, p_visit uuid, p_action text, p_before jsonb, p_after jsonb, p_reason text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
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
revoke all on function public.inpatient_log_change(uuid, uuid, text, jsonb, jsonb, text) from public, anon, authenticated;

-- The editable fields of an order, as the change log keeps them.
create or replace function public.inpatient_order_snapshot(p_order public.inpatient_orders) returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'dose', p_order.dose, 'qty_per_dose', p_order.qty_per_dose, 'times', to_jsonb(p_order.times),
    'start_on', p_order.start_on, 'end_on', p_order.end_on, 'note', p_order.note
  );
$$;
revoke all on function public.inpatient_order_snapshot(public.inpatient_orders) from public, anon, authenticated;


-- ----------------------------------------------------------------- edit an order
-- p: dose, qty_per_dose, times, start_on, end_on, note, reason (all optional). The medicine or service
-- itself cannot change: use replace_inpatient_order. Doses that are not yet due and not yet recorded are
-- rebuilt from the new hours and dates; given, skipped and missed doses stay as they are.
create or replace function public.update_inpatient_order(p_id uuid, p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
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
$$;
revoke all on function public.update_inpatient_order(uuid, jsonb) from public, anon;
grant execute on function public.update_inpatient_order(uuid, jsonb) to authenticated;

-- ----------------------------------------------------------------- stop (with a reason)
drop function if exists public.stop_inpatient_order(uuid);
create or replace function public.stop_inpatient_order(p_id uuid, p_reason text default null) returns void
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
revoke all on function public.stop_inpatient_order(uuid, text) from public, anon;
grant execute on function public.stop_inpatient_order(uuid, text) to authenticated;

-- ----------------------------------------------------------------- replace (another medicine)
-- Stops the order and writes a new one from p (the format of save_inpatient_order), in one step.
create or replace function public.replace_inpatient_order(p_id uuid, p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
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
revoke all on function public.replace_inpatient_order(uuid, jsonb) from public, anon;
grant execute on function public.replace_inpatient_order(uuid, jsonb) to authenticated;

-- ----------------------------------------------------------------- history
create or replace function public.inpatient_order_history(p_order uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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
revoke all on function public.inpatient_order_history(uuid) from public, anon;
grant execute on function public.inpatient_order_history(uuid) to authenticated;


-- ----------------------------------------------------------------- existing RPCs, extended

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
