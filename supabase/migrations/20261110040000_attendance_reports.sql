-- Attendance step 4: the timesheet. The numbers come from attendance_rows (step 2); these functions
-- only add them up per person (summary), per day (monthly grid) and for the caller (my timesheet).

-- Totals per staff member over a range (at most 93 days). Rows are staff of the chosen branch, or of
-- every branch the caller may view when p_branch is null (never has_permission(null)).
create or replace function public.report_timesheet(
  p_branch uuid default null, p_from date default null, p_to date default null,
  p_search text default null, p_limit integer default 20, p_offset integer default 0
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[] := public.attendance_branch_ids(p_branch, 'VIEW');
  v_limit    integer := least(greatest(coalesce(p_limit, 20), 1), 200);
  v_offset   integer := greatest(coalesce(p_offset, 0), 0);
  v_rows     jsonb;
  v_total    integer;
begin
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from + 1 > 93 then
    raise exception 'date range is longer than 93 days' using errcode = '22023', hint = 'range_too_long';
  end if;

  with staff as (
    select sb.user_id, public.staff_display_name(sb.user_id) as name, string_agg(distinct b.code, ', ' order by b.code) as codes
    from public.staff_branches sb
    join public.branches b on b.id = sb.branch_id
    where sb.branch_id = any (v_branches)
    group by sb.user_id
  ),
  picked as (
    select * from staff s
    where nullif(btrim(coalesce(p_search, '')), '') is null or s.name ilike '%' || btrim(p_search) || '%'
  ),
  rows as (
    select * from public.attendance_rows(v_branches, p_from, p_to)
  ),
  agg as (
    select r.user_id,
      count(*) filter (where r.assignment_id is not null) as shifts_scheduled,
      count(*) filter (where r.assignment_id is not null and r.entry_id is not null) as shifts_worked,
      coalesce(sum(r.scheduled_minutes), 0) as scheduled_minutes,
      coalesce(sum(r.worked_minutes), 0) as worked_minutes,
      count(*) filter (where r.late_minutes > 0) as late_count,
      coalesce(sum(r.late_minutes), 0) as late_minutes,
      count(*) filter (where r.early_minutes > 0) as early_count,
      coalesce(sum(r.early_minutes), 0) as early_minutes,
      coalesce(sum(r.overtime_minutes), 0) as overtime_minutes,
      count(*) filter (where r.status = 'absent') as absent_count,
      count(*) filter (where r.assignment_id is null and r.entry_id is not null) as unscheduled_count,
      count(*) filter (where r.status = 'missing_checkout') as missing_checkout_count
    from rows r
    group by r.user_id
  ),
  leaves as (
    select x.user_id,
      coalesce(sum(x.d) filter (where x.leave_type = 'annual'), 0) as annual,
      coalesce(sum(x.d) filter (where x.leave_type = 'sick'), 0) as sick,
      coalesce(sum(x.d) filter (where x.leave_type = 'unpaid'), 0) as unpaid,
      coalesce(sum(x.d) filter (where x.leave_type = 'other'), 0) as other
    from (
      select lr.user_id, lr.leave_type,
             public.leave_days(lr.branch_id, greatest(lr.from_date, p_from), least(lr.to_date, p_to), lr.part) as d
      from public.leave_requests lr
      where lr.status = 'approved' and lr.from_date <= p_to and lr.to_date >= p_from
        and lr.user_id in (select user_id from picked)
    ) x
    group by x.user_id
  ),
  page as (
    select * from picked order by name, user_id limit v_limit offset v_offset
  )
  select (select count(*) from picked),
         coalesce((select jsonb_agg(jsonb_build_object(
           'user_id', p.user_id, 'name', p.name, 'branch_codes', p.codes,
           'shifts_scheduled', coalesce(a.shifts_scheduled, 0), 'shifts_worked', coalesce(a.shifts_worked, 0),
           'scheduled_minutes', coalesce(a.scheduled_minutes, 0), 'worked_minutes', coalesce(a.worked_minutes, 0),
           'late_count', coalesce(a.late_count, 0), 'late_minutes', coalesce(a.late_minutes, 0),
           'early_count', coalesce(a.early_count, 0), 'early_minutes', coalesce(a.early_minutes, 0),
           'overtime_minutes', coalesce(a.overtime_minutes, 0), 'absent_count', coalesce(a.absent_count, 0),
           'unscheduled_count', coalesce(a.unscheduled_count, 0), 'missing_checkout_count', coalesce(a.missing_checkout_count, 0),
           'leave_annual', coalesce(l.annual, 0), 'leave_sick', coalesce(l.sick, 0),
           'leave_unpaid', coalesce(l.unpaid, 0), 'leave_other', coalesce(l.other, 0)) order by p.name, p.user_id)
           from page p left join agg a on a.user_id = p.user_id left join leaves l on l.user_id = p.user_id), '[]'::jsonb)
    into v_total, v_rows;

  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$$;

-- One branch, one month: a code per person per day (P/Ô/K/N leave, V absent, ? forgot to clock out,
-- M late, S left early, X worked, X+ worked without a shift) with the minutes and the shifts behind it.
-- A shift that crosses midnight belongs to the day it starts.
create or replace function public.report_timesheet_grid(p_branch uuid, p_month date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[];
  v_first    date;
  v_last     date;
  v_days     jsonb;
  v_staff    jsonb;
begin
  if p_branch is null or p_month is null then
    raise exception 'a branch and a month are required' using errcode = '22023', hint = 'bad_input';
  end if;
  v_branches := public.attendance_branch_ids(p_branch, 'VIEW');
  v_first := date_trunc('month', p_month)::date;
  v_last := (v_first + interval '1 month' - interval '1 day')::date;

  select jsonb_agg(d::date order by d) into v_days from generate_series(v_first, v_last, interval '1 day') d;

  with staff as (
    select sb.user_id, public.staff_display_name(sb.user_id) as name
    from public.staff_branches sb where sb.branch_id = p_branch
  ),
  days as (
    select d::date as day from generate_series(v_first, v_last, interval '1 day') d
  ),
  rows as (
    select r.*,
      case r.status
        when 'absent' then 'V' when 'missing_checkout' then '?' when 'late' then 'M' when 'late_early' then 'M'
        when 'early' then 'S' when 'present' then 'X' when 'unscheduled' then 'X+'
        when 'leave' then case r.leave_type when 'annual' then 'P' when 'sick' then 'Ô' when 'unpaid' then 'K' else 'N' end
      end as code,
      case r.status
        when 'absent' then 5 when 'missing_checkout' then 4 when 'late' then 3 when 'late_early' then 3
        when 'early' then 2 when 'present' then 1 when 'unscheduled' then 1 when 'leave' then 0
      end as pri
    from public.attendance_rows(v_branches, v_first, v_last) r
  ),
  cells as (
    select s.user_id, d.day,
      coalesce(
        (select x.code from rows x where x.user_id = s.user_id and x.work_date = d.day and x.code is not null order by x.pri desc limit 1),
        (select case lr.leave_type when 'annual' then 'P' when 'sick' then 'Ô' when 'unpaid' then 'K' else 'N' end
         from public.leave_requests lr
         where lr.user_id = s.user_id and lr.status = 'approved' and d.day between lr.from_date and lr.to_date limit 1),
        '') as code,
      coalesce((select sum(x.worked_minutes) from rows x where x.user_id = s.user_id and x.work_date = d.day), 0)::int as minutes,
      coalesce((select jsonb_agg(jsonb_build_object(
          'shift_name', x.shift_name, 'status', x.status, 'check_in_at', x.check_in_at,
          'check_out_at', x.check_out_at, 'worked_minutes', x.worked_minutes) order by x.start_at nulls last, x.check_in_at)
        from rows x where x.user_id = s.user_id and x.work_date = d.day), '[]'::jsonb) as detail
    from staff s cross join days d
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'user_id', s.user_id, 'name', s.name,
    'cells', (select jsonb_agg(jsonb_build_object('date', c.day, 'code', c.code, 'minutes', c.minutes, 'detail', c.detail) order by c.day)
              from cells c where c.user_id = s.user_id),
    'totals', (select jsonb_build_object(
                 'days_worked', count(*) filter (where c.code in ('X', 'M', 'S', 'X+')),
                 'late_count', count(*) filter (where c.code = 'M'),
                 'absent_count', count(*) filter (where c.code = 'V'),
                 'unchecked_count', count(*) filter (where c.code = '?'),
                 'leave_days', count(*) filter (where c.code in ('P', 'Ô', 'K', 'N')),
                 'worked_minutes', coalesce(sum(c.minutes), 0))
               from cells c where c.user_id = s.user_id)
  ) order by s.name, s.user_id), '[]'::jsonb)
    into v_staff
  from staff s;

  return jsonb_build_object('days', v_days, 'staff', v_staff);
end;
$$;

-- The caller's own rows (all their branches) and totals, at most 93 days.
create or replace function public.my_timesheet(p_from date, p_to date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_branches uuid[];
begin
  if v_uid is null then
    raise exception 'not signed in' using errcode = '42501', hint = 'not_signed_in';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from + 1 > 93 then
    raise exception 'date range is longer than 93 days' using errcode = '22023', hint = 'range_too_long';
  end if;
  select coalesce(array_agg(branch_id), '{}') into v_branches from public.staff_branches where user_id = v_uid;

  return (
    with rows as (select * from public.attendance_rows(v_branches, p_from, p_to, v_uid))
    select jsonb_build_object(
      'rows', coalesce((select jsonb_agg(to_jsonb(r) order by r.work_date, r.start_at nulls last, r.check_in_at) from rows r), '[]'::jsonb),
      'totals', jsonb_build_object(
        'scheduled_minutes', coalesce((select sum(scheduled_minutes) from rows), 0),
        'worked_minutes', coalesce((select sum(worked_minutes) from rows), 0),
        'late_count', (select count(*) from rows where late_minutes > 0),
        'late_minutes', coalesce((select sum(late_minutes) from rows), 0),
        'early_minutes', coalesce((select sum(early_minutes) from rows), 0),
        'overtime_minutes', coalesce((select sum(overtime_minutes) from rows), 0),
        'absent_count', (select count(*) from rows where status = 'absent'))));
end;
$$;

revoke all on function public.report_timesheet(uuid, date, date, text, integer, integer) from public, anon;
revoke all on function public.report_timesheet_grid(uuid, date) from public, anon;
revoke all on function public.my_timesheet(date, date) from public, anon;
grant execute on function public.report_timesheet(uuid, date, date, text, integer, integer) to authenticated;
grant execute on function public.report_timesheet_grid(uuid, date) to authenticated;
grant execute on function public.my_timesheet(date, date) to authenticated;

notify pgrst, 'reload schema';
