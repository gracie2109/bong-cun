-- Past days are history: shifts on a day before today (Vietnam time) can no longer be added, changed,
-- moved or removed through the roster. Check-ins and timesheet fixes are separate and unaffected.
-- Copying a week also gets cheaper: one set-based insert instead of a loop, and past target days are skipped.

create or replace function public.assert_schedule_day_editable(p_date date)
returns void
language plpgsql
stable
set search_path to ''
as $$
begin
  if p_date < public.vn_today() then
    raise exception 'past days cannot be changed' using errcode = 'P0001', hint = 'past_date';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public.assign_shift("p_branch" "uuid", "p_user" "uuid", "p_date" "date", "p_template" "uuid", "p_start" time without time zone DEFAULT NULL::time without time zone, "p_end" time without time zone DEFAULT NULL::time without time zone, "p_break" integer DEFAULT NULL::integer, "p_note" "text" DEFAULT NULL::"text", "p_reason" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_tpl    public.shift_templates;
  v_name   text;
  v_start  time := p_start;
  v_end    time := p_end;
  v_break  int := p_break;
  v_start_at timestamptz;
  v_id     uuid;
begin
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'assign_shift', true);
  if not public.can_attendance('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_user is null or p_date is null then
    raise exception 'user and date are required' using errcode = '22023', hint = 'bad_input';
  end if;
  perform public.assert_schedule_day_editable(p_date);
  if not exists (select 1 from public.staff_branches where user_id = p_user and branch_id = p_branch) then
    raise exception 'this person does not work at the branch' using errcode = 'P0001', hint = 'not_branch_staff';
  end if;

  if p_template is not null then
    select * into v_tpl from public.shift_templates where id = p_template and branch_id = p_branch and is_active;
    if not found then
      raise exception 'template not found' using errcode = 'P0001', hint = 'not_found';
    end if;
    v_name := v_tpl.name;
    v_start := v_tpl.start_time;
    v_end := v_tpl.end_time;
    v_break := coalesce(p_break, v_tpl.break_minutes);
  else
    if v_start is null or v_end is null or v_start = v_end then
      raise exception 'start and end are required' using errcode = '22023', hint = 'bad_input';
    end if;
    v_name := 'Tùy chỉnh';
    v_break := coalesce(v_break, 0);
  end if;
  if v_break < 0 or v_break >= public.shift_minutes(v_start, v_end) or public.shift_minutes(v_start, v_end) > 960 then
    raise exception 'bad shift length' using errcode = '22023', hint = 'bad_input';
  end if;

  v_start_at := public.shift_start_at(p_date, v_start);
  begin
    insert into public.shift_assignments (
      branch_id, user_id, work_date, template_id, name, start_at, end_at, break_minutes, note, created_by
    ) values (
      p_branch, p_user, p_date, p_template, v_name, v_start_at,
      public.shift_end_at(p_date, v_start, v_end), v_break, nullif(btrim(p_note), ''), (select auth.uid())
    ) returning id into v_id;
  exception
    when exclusion_violation then
      raise exception 'this person already has a shift at that time' using errcode = 'P0001', hint = 'shift_overlap';
    when check_violation then
      raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end;

  return jsonb_strip_nulls(jsonb_build_object(
    'id', v_id,
    'warning', case when public.shift_on_leave(p_user, v_start_at) then 'on_leave' end
  ));
end;
$$;

CREATE OR REPLACE FUNCTION public.update_shift_assignment("p_id" "uuid", "p" "jsonb", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_row    public.shift_assignments;
  v_tpl    public.shift_templates;
  v_date   date;
  v_start  time;
  v_end    time;
  v_break  int;
  v_name   text;
  v_tpl_id uuid;
  v_note   text;
begin
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'update_shift_assignment', true);
  select * into v_row from public.shift_assignments where id = p_id;
  if not found then
    raise exception 'shift not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if not public.can_attendance('UPDATE', v_row.branch_id) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if jsonb_typeof(p) is distinct from 'object' then
    raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end if;
  perform public.assert_schedule_day_editable(v_row.work_date);

  v_note := case when p ? 'note' then nullif(btrim(p ->> 'note'), '') else v_row.note end;
  if public.assignment_has_entry(p_id) then
    if p ?| array['template_id', 'start_time', 'end_time', 'break_minutes', 'work_date'] then
      raise exception 'this shift already has a clock-in' using errcode = 'P0001', hint = 'has_entry';
    end if;
    update public.shift_assignments set note = v_note where id = p_id;
    return;
  end if;

  begin
    v_date := coalesce((p ->> 'work_date')::date, v_row.work_date);
    v_tpl_id := case when p ? 'template_id' then nullif(p ->> 'template_id', '')::uuid else v_row.template_id end;
    v_start := coalesce((p ->> 'start_time')::time, (v_row.start_at at time zone 'Asia/Ho_Chi_Minh')::time);
    v_end := coalesce((p ->> 'end_time')::time, (v_row.end_at at time zone 'Asia/Ho_Chi_Minh')::time);
    v_break := coalesce((p ->> 'break_minutes')::int, v_row.break_minutes);
  exception when invalid_text_representation or datetime_field_overflow or invalid_datetime_format then
    raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end;
  v_name := v_row.name;
  perform public.assert_schedule_day_editable(v_date);

  if p ? 'template_id' and v_tpl_id is not null then
    select * into v_tpl from public.shift_templates where id = v_tpl_id and branch_id = v_row.branch_id and is_active;
    if not found then
      raise exception 'template not found' using errcode = 'P0001', hint = 'not_found';
    end if;
    v_name := v_tpl.name;
    if not (p ? 'start_time') then v_start := v_tpl.start_time; end if;
    if not (p ? 'end_time') then v_end := v_tpl.end_time; end if;
    if not (p ? 'break_minutes') then v_break := v_tpl.break_minutes; end if;
  elsif p ? 'template_id' then
    v_name := 'Tùy chỉnh';
  end if;

  if v_start = v_end or v_break < 0 or v_break >= public.shift_minutes(v_start, v_end)
     or public.shift_minutes(v_start, v_end) > 960 then
    raise exception 'bad shift length' using errcode = '22023', hint = 'bad_input';
  end if;

  begin
    update public.shift_assignments set
      work_date = v_date, template_id = v_tpl_id, name = v_name,
      start_at = public.shift_start_at(v_date, v_start), end_at = public.shift_end_at(v_date, v_start, v_end),
      break_minutes = v_break, note = v_note
    where id = p_id;
  exception
    when exclusion_violation then
      raise exception 'this person already has a shift at that time' using errcode = 'P0001', hint = 'shift_overlap';
    when check_violation then
      raise exception 'bad shift' using errcode = '22023', hint = 'bad_input';
  end;
end;
$$;

CREATE OR REPLACE FUNCTION public.remove_shift_assignment("p_id" "uuid", "p_reason" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_branch uuid;
  v_date   date;
begin
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'remove_shift_assignment', true);
  select branch_id, work_date into v_branch, v_date from public.shift_assignments where id = p_id;
  if v_branch is null then
    raise exception 'shift not found' using errcode = 'P0001', hint = 'not_found';
  end if;
  if not public.can_attendance('DELETE', v_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  perform public.assert_schedule_day_editable(v_date);
  if public.assignment_has_entry(p_id) then
    raise exception 'this shift already has a clock-in' using errcode = 'P0001', hint = 'has_entry';
  end if;
  delete from public.shift_assignments where id = p_id;
end;
$$;


create or replace function public.copy_roster_week(
  p_branch uuid, p_from_monday date, p_to_monday date, p_overwrite boolean default false, p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_shift   int;
  v_today   date := public.vn_today();
  v_total   int;
  v_copied  int;
  v_past    int;
begin
  perform set_config('app.schedule_reason', left(coalesce(nullif(btrim(p_reason), ''), ''), 300), true);
  perform set_config('app.schedule_source', 'copy_roster_week', true);
  if not public.can_attendance('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_from_monday is null or p_to_monday is null or p_from_monday = p_to_monday
     or extract(isodow from p_from_monday) <> 1 or extract(isodow from p_to_monday) <> 1 then
    raise exception 'both dates must be different Mondays' using errcode = '22023', hint = 'bad_input';
  end if;
  perform public.assert_schedule_day_editable(p_to_monday + 6);
  v_shift := p_to_monday - p_from_monday;

  select count(*) into v_total
  from public.shift_assignments
  where branch_id = p_branch and work_date >= p_from_monday and work_date < p_from_monday + 7;

  select count(*) into v_past
  from public.shift_assignments
  where branch_id = p_branch and work_date >= p_from_monday and work_date < p_from_monday + 7
    and work_date + v_shift < v_today;

  -- Overwrite: clear the days that will be refilled (never a shift that already has a clock-in).
  if coalesce(p_overwrite, false) then
    delete from public.shift_assignments a
    where a.branch_id = p_branch
      and a.work_date >= p_to_monday + greatest(0, v_today - p_to_monday) and a.work_date < p_to_monday + 7
      and not public.assignment_has_entry(a.id)
      and exists (
        select 1 from public.shift_assignments s
        join public.staff_branches sb on sb.user_id = s.user_id and sb.branch_id = p_branch
        where s.branch_id = p_branch and s.user_id = a.user_id and s.work_date + v_shift = a.work_date);
  end if;

  insert into public.shift_assignments (
    branch_id, user_id, work_date, template_id, name, start_at, end_at, break_minutes, note, created_by
  )
  select p_branch, s.user_id, s.work_date + v_shift, s.template_id, s.name,
         ((s.start_at at time zone 'Asia/Ho_Chi_Minh') + v_shift * interval '1 day') at time zone 'Asia/Ho_Chi_Minh',
         ((s.end_at at time zone 'Asia/Ho_Chi_Minh') + v_shift * interval '1 day') at time zone 'Asia/Ho_Chi_Minh',
         s.break_minutes, s.note, (select auth.uid())
  from public.shift_assignments s
  where s.branch_id = p_branch and s.work_date >= p_from_monday and s.work_date < p_from_monday + 7
    and s.work_date + v_shift >= v_today
    and exists (select 1 from public.staff_branches sb where sb.user_id = s.user_id and sb.branch_id = p_branch)
    and not exists (
      select 1 from public.shift_assignments t
      where t.branch_id = p_branch and t.user_id = s.user_id and t.work_date = s.work_date + v_shift)
  order by s.start_at
  on conflict do nothing;
  get diagnostics v_copied = row_count;

  return jsonb_build_object('copied', v_copied, 'skipped', v_total - v_copied, 'skipped_past', v_past);
end;
$$;
