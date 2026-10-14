-- Customer UI, step 7 (2/3): a signed-in customer books a spa visit (docs/giao-dien-khach-hang.md, 3.5).
--
-- p: { branch_id, start_at, note?, items: [{ pet_id, type: 'service' | 'combo', id }] }
-- The tickets are placed one after another from start_at, in the order given. Names, minutes and
-- estimated prices come from spa_ticket_quote, never from the client. The appointment is saved with
-- source 'web', status 'booked' and no staff or table: the front desk assigns them on the board.
-- Returns { id, code }. Errors (hint): no_customer, empty, no_pet, unavailable, wrong_species,
-- bad_time, too_soon, too_far, too_many, closed, outside_hours, slot_full, pet_busy.
-- Two customers taking the last place at once are serialised by a lock per branch and day.
-- Safe to run more than once.

create or replace function public.book_my_appointment(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid      uuid := auth.uid();
  v_cust     uuid := public.my_customer_id();
  v_rules    jsonb := public.spa_web_rules();
  v_branch   uuid := nullif(p ->> 'branch_id', '')::uuid;
  v_start    timestamptz;
  v_local    timestamp;
  v_hours    record;
  v_items    jsonb := coalesce(p -> 'items', '[]'::jsonb);
  v_item     jsonb;
  v_quote    jsonb;
  v_quotes   jsonb[] := '{}';
  v_minutes  int := 0;
  v_cursor   timestamptz;
  v_end      timestamptz;
  v_line     int := 0;
  v_name     text;
  v_phone    text;
  v_id       uuid;
  v_code     text;
  v_pet      uuid;
  v_kind     text;
  v_obj      uuid;
begin
  if v_uid is null then
    raise exception 'sign in first' using errcode = '28000', hint = 'not_signed_in';
  end if;
  if v_cust is null then
    raise exception 'fill in your profile first' using errcode = '22023', hint = 'no_customer';
  end if;
  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items) = 0 or jsonb_array_length(v_items) > 10 then
    raise exception 'pick at least one service' using errcode = '22023', hint = 'empty';
  end if;
  if v_branch is null or not exists (select 1 from public.branches where id = v_branch and is_active) then
    raise exception 'branch not found' using errcode = 'P0002', hint = 'bad_time';
  end if;
  begin
    v_start := (p ->> 'start_at')::timestamptz;
  exception when others then
    v_start := null;
  end;
  v_local := v_start at time zone c_tz;
  if v_start is null or extract(second from v_local) <> 0 or extract(minute from v_local)::int % 15 <> 0 then
    raise exception 'start on a quarter hour' using errcode = 'P0001', hint = 'bad_time';
  end if;
  if v_start < now() + make_interval(mins => (v_rules ->> 'min_lead_minutes')::int) then
    raise exception 'too soon' using errcode = 'P0001', hint = 'too_soon';
  end if;
  if v_local::date > (now() at time zone c_tz)::date + (v_rules ->> 'max_days')::int then
    raise exception 'too far ahead' using errcode = 'P0001', hint = 'too_far';
  end if;

  -- One customer, one lock per branch and day: the slot count below stays true until we commit.
  perform pg_advisory_xact_lock(hashtextextended(v_branch::text || ':' || v_local::date::text, 0));

  if (
    select count(*) from public.appointments a
    where a.customer_id = v_cust and a.source = 'web' and a.status = 'booked' and a.start_at > now()
  ) >= (v_rules ->> 'max_open')::int then
    raise exception 'too many upcoming web bookings' using errcode = 'P0001', hint = 'too_many';
  end if;

  -- Quote every ticket first (also checks the pets are mine and the offer fits the species).
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_pet := nullif(v_item ->> 'pet_id', '')::uuid;
    if not exists (
      select 1 from public.pet_owners where pet_id = v_pet and customer_id = v_cust and to_date is null
    ) then
      raise exception 'pet not found' using errcode = 'P0002', hint = 'no_pet';
    end if;
    v_quote := public.spa_ticket_quote(v_branch, v_pet, v_item ->> 'type', nullif(v_item ->> 'id', '')::uuid);
    v_quotes := v_quotes || v_quote;
    v_minutes := v_minutes + (v_quote ->> 'minutes')::int;
  end loop;
  v_minutes := ceil(v_minutes / 15.0)::int * 15;
  if v_minutes > (v_rules ->> 'max_block_minutes')::int then
    raise exception 'too long for one booking' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  select * into v_hours from public.spa_hours(v_branch, v_local::date);
  if v_hours.is_closed then
    raise exception 'the branch is closed that day' using errcode = 'P0001', hint = 'closed';
  end if;
  v_end := v_start + make_interval(mins => v_minutes);
  if v_local::time < v_hours.open_time
     or (v_end at time zone c_tz)::date <> v_local::date
     or (v_end at time zone c_tz)::time > v_hours.close_time then
    raise exception 'outside opening hours' using errcode = 'P0001', hint = 'outside_hours';
  end if;

  if not public.spa_block_is_free(v_branch, v_start, v_minutes) then
    raise exception 'that time is full' using errcode = 'P0001', hint = 'slot_full';
  end if;

  -- A pet cannot be in two places at once.
  for v_item in select * from jsonb_array_elements(v_items) loop
    if exists (
      select 1 from public.appointment_items i
      where i.pet_id = (v_item ->> 'pet_id')::uuid and i.status <> 'cancelled'
        and i.start_at < v_end and i.end_at > v_start
    ) then
      raise exception 'the pet already has a visit at that time' using errcode = 'P0001', hint = 'pet_busy';
    end if;
  end loop;

  select full_name, phone into v_name, v_phone from public.customers where id = v_cust;
  insert into public.appointments (
    code, branch_id, customer_id, customer_name, customer_phone, start_at, end_at, source, note, created_by
  )
  values (
    public.next_doc_code(v_branch, 'LH'), v_branch, v_cust, v_name, v_phone,
    v_start, v_end, 'web', left(nullif(btrim(p ->> 'note'), ''), 500), v_uid
  )
  returning id, code into v_id, v_code;

  v_cursor := v_start;
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_line := v_line + 1;
    v_quote := v_quotes[v_line];
    v_kind := v_item ->> 'type';
    v_obj := nullif(v_item ->> 'id', '')::uuid;
    insert into public.appointment_items (
      appointment_id, branch_id, line_no, pet_id, item_type, service_id, combo_id, name,
      duration_minutes, start_at, end_at, est_price, weight_kg
    )
    values (
      v_id, v_branch, v_line, (v_item ->> 'pet_id')::uuid, v_kind,
      case when v_kind = 'service' then v_obj end,
      case when v_kind = 'combo' then v_obj end,
      v_quote ->> 'name', (v_quote ->> 'minutes')::int,
      v_cursor, v_cursor + make_interval(mins => (v_quote ->> 'minutes')::int),
      (v_quote ->> 'price')::numeric, (v_quote ->> 'weight_kg')::numeric
    );
    v_cursor := v_cursor + make_interval(mins => (v_quote ->> 'minutes')::int);
  end loop;

  update public.appointments set end_at = v_cursor where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code);
end;
$$;

revoke execute on function public.book_my_appointment(jsonb) from public, anon;
grant execute on function public.book_my_appointment(jsonb) to authenticated;

notify pgrst, 'reload schema';
