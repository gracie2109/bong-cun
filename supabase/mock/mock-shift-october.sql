-- Fills October 2026 for the MOCKCA branch (made by mock-shift-seed.sql) so the timesheet screens have a
-- full month to show: shifts, check-ins with a realistic mix (on time, late, early out, overtime, a forgotten
-- check-out closed at 0 minutes and flagged, absent), a few approved leave days and a couple of unscheduled days.
--
-- Not a migration: paste it into the Supabase SQL editor after mock-shift-seed.sql.
-- It only touches the MOCKCA branch and its mock-ca-N@mock.invalid staff, and mock-shift-cleanup.sql removes it
-- with the rest. A shift the seed already made for a day is kept; this script only adds what is missing.
-- One transaction; running it twice is refused.
begin;

do $oct$
declare
  v_branch uuid;
  v_admin  uuid;
  v_tpl    uuid[] := '{}';
  v_tname  text[] := '{}';
  v_tstart time[] := '{}';
  v_tend   time[] := '{}';
  v_staff  uuid[] := '{}';
  v_names  text[] := '{}';
  v_off    int[]  := '{}';
  v_day    date;
  v_tp     int;
  v_h      int;
  v_in     timestamptz;
  v_out    timestamptz;
  v_reason text;
  r        record;
  i        int;
  n        int;
begin
  select id into v_branch from public.branches where code = 'MOCKCA';
  if v_branch is null then raise exception 'Run mock-shift-seed.sql first (the MOCKCA branch does not exist).'; end if;
  if exists (select 1 from public.time_entries where branch_id = v_branch and work_date between date '2026-10-01' and date '2026-10-31') then
    raise exception 'October is already filled. Run mock-shift-cleanup.sql and the seed again first.';
  end if;
  select u.id into v_admin from public.users u order by u.created_at limit 1;

  for r in select id, name, start_time, end_time from public.shift_templates where branch_id = v_branch order by sort_order loop
    v_tpl := v_tpl || r.id; v_tname := v_tname || r.name; v_tstart := v_tstart || r.start_time; v_tend := v_tend || r.end_time;
  end loop;
  for r in
    select u.id, coalesce(u.raw_user_meta_data ->> 'full_name', u.email) as name,
           coalesce((select min(a.weekday) from public.staff_availability a where a.user_id = u.id and a.kind = 'unavailable' and a.start_time is null), 0) as off
    from auth.users u where u.email like 'mock-ca-%@mock.invalid'
    order by substring(u.email from 'mock-ca-(\d+)')::int
  loop
    v_staff := v_staff || r.id; v_names := v_names || r.name; v_off := v_off || r.off;
  end loop;
  if coalesce(array_length(v_staff, 1), 0) = 0 or coalesce(array_length(v_tpl, 1), 0) = 0 then
    raise exception 'The MOCKCA staff or shift templates are missing.';
  end if;

  -- Approved leave first, so those days get no shift.
  insert into public.leave_requests (user_id, user_name, branch_id, leave_type, from_date, to_date, part, days, reason, status, decided_by, decided_by_name, decided_at, created_by)
  select v_staff[x.i], v_names[x.i], v_branch, x.kind, x.d1, x.d2, 'full', (x.d2 - x.d1 + 1), x.why, 'approved', v_admin, 'Quản lý', timestamptz '2026-10-01 09:00+07', v_admin
  from (values
    (3, 'annual', date '2026-10-12', date '2026-10-13', 'Việc gia đình'),
    (6, 'sick',   date '2026-10-20', date '2026-10-20', 'Sốt'),
    (8, 'unpaid', date '2026-10-27', date '2026-10-28', 'Về quê')
  ) as x(i, kind, d1, d2, why);

  -- Shifts: about four days a week, never on a blocked weekday, none on leave days.
  for i in 1..array_length(v_staff, 1) loop
    for n in 0..30 loop
      v_day := date '2026-10-01' + n;
      continue when ((i * 2 + n + 14) % 7) >= 4;
      continue when extract(isodow from v_day)::int = v_off[i];
      continue when exists (select 1 from public.leave_requests l where l.user_id = v_staff[i] and l.status = 'approved' and v_day between l.from_date and l.to_date);
      continue when exists (select 1 from public.shift_assignments a where a.user_id = v_staff[i] and a.branch_id = v_branch and a.work_date = v_day);
      v_tp := ((i + n + 14) % 3) + 1;
      insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at, created_by)
      values (v_branch, v_staff[i], v_day, v_tpl[v_tp], v_tname[v_tp],
              public.shift_start_at(v_day, v_tstart[v_tp]), public.shift_end_at(v_day, v_tstart[v_tp], v_tend[v_tp]), v_admin);
    end loop;
  end loop;

  -- Check-ins for every October shift of the mock staff. h picks the story, the same every run.
  for r in
    select a.id, a.user_id, a.work_date, a.start_at, a.end_at, s.ord
    from public.shift_assignments a
    join unnest(v_staff) with ordinality as s(uid, ord) on s.uid = a.user_id
    where a.branch_id = v_branch and a.work_date between date '2026-10-01' and date '2026-10-31'
      and not exists (select 1 from public.time_entries e where e.assignment_id = a.id)
  loop
    v_h := (r.ord * 7 + (r.work_date - date '2026-10-01') * 13) % 24;
    v_reason := null;
    if v_h = 0 then continue; end if;                                               -- absent
    v_in := r.start_at + ((v_h % 5) - 2) * interval '1 minute';                     -- on time
    v_out := r.end_at + ((v_h % 4)) * interval '1 minute';
    if v_h in (1, 2) then v_in := r.start_at + (10 + v_h * 6) * interval '1 minute'; end if;     -- late
    if v_h = 3 then v_out := r.end_at - interval '25 minutes'; end if;                          -- early out
    if v_h = 4 then v_out := r.end_at + interval '50 minutes'; end if;                          -- overtime
    if v_h = 5 then v_out := v_in; v_reason := 'missing_checkout'; end if;                      -- forgot to check out: closed at 0 minutes and flagged
    insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, check_out_at, in_source, out_source, review_reason)
    values (v_branch, r.user_id, v_names[r.ord], r.id, v_in, v_out, 'self', case when v_reason is not null then 'auto' else 'self' end, v_reason);
  end loop;

  -- A few unscheduled days: the fourth person came in without a shift.
  for n in 0..30 loop
    v_day := date '2026-10-01' + n;
    continue when n % 9 <> 4;
    continue when exists (select 1 from public.shift_assignments a where a.user_id = v_staff[4] and a.work_date = v_day)
               or exists (select 1 from public.leave_requests l where l.user_id = v_staff[4] and l.status = 'approved' and v_day between l.from_date and l.to_date);
    insert into public.time_entries (branch_id, user_id, user_name, assignment_id, check_in_at, check_out_at, in_source, out_source, review_reason, reviewed_by, reviewed_at)
    values (v_branch, v_staff[4], v_names[4], null, public.shift_start_at(v_day, time '09:00'), public.shift_start_at(v_day, time '13:00'), 'self', 'self', 'unscheduled', v_admin, timestamptz '2026-11-01 09:00+07');
  end loop;
end;
$oct$;

commit;
