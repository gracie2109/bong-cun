-- Spa appointments, step 3 (1/2): tickets that are done can be paid in the POS.
-- Runs after 20261013040000_spa_check_in.sql; 20261013050100_pos_invoice_appointments.sql follows.
-- Re-runnable.

-- ------------------------------------------------------------------- status
-- Same rule as before plus "paid": every live ticket is on an invoice. A cancelled invoice
-- clears the links, which brings the appointment back to "done".
create or replace function public.refresh_appointment_status(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.refresh_appointment_status(uuid) from public, anon, authenticated;

-- ------------------------------------------------------------ ticket status
-- A ticket already on an invoice is final.
create or replace function public.set_appointment_item_status(p_item uuid, p_status text) returns void
language plpgsql
security definer
set search_path = ''
as $$
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

revoke execute on function public.set_appointment_item_status(uuid, text) from public, anon;
grant execute on function public.set_appointment_item_status(uuid, text) to authenticated;

-- ----------------------------------------------------------------- billable
-- The done tickets of a customer that are not on an invoice yet, for the POS cart.
create or replace function public.billable_appointment_items(p_branch uuid, p_customer uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.billable_appointment_items(uuid, uuid) from public, anon;
grant execute on function public.billable_appointment_items(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------- list
-- Same as before, with a "billed" flag on each ticket (is it on an invoice).
-- Appointments of a branch between two dates (business time, inclusive), newest first.
-- p_search matches the code, customer name or phone, or a pet name. Returns { rows, total }.
create or replace function public.list_appointments(
  p_branch uuid,
  p_from date default null,
  p_to date default null,
  p_status text default null,
  p_search text default null,
  p_page int default 1,
  p_page_size int default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
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

revoke execute on function public.list_appointments(uuid, date, date, text, text, int, int) from public, anon;
grant execute on function public.list_appointments(uuid, date, date, text, text, int, int) to authenticated;

notify pgrst, 'reload schema';
