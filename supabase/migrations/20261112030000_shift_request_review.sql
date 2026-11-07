-- Shift registration step 3: managers review requests.
-- Approving creates a shift_assignments row, exactly like assigning by hand, so the clock, the
-- timesheet and "my schedule" need no change. The roster also returns pending requests and the
-- availability of the branch's staff.

-- A request as the review screens read it, with the flags computed at read time.
create or replace function public.shift_request_row(r public.shift_requests, p_branch_name text) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', r.id, 'branch_id', r.branch_id, 'branch_name', p_branch_name,
    'user_id', r.user_id, 'user_name', r.user_name, 'work_date', r.work_date,
    'template_id', r.template_id, 'name', r.name,
    'color', coalesce((select t.color from public.shift_templates t where t.id = r.template_id), 'slate'),
    'start_at', r.start_at, 'end_at', r.end_at, 'break_minutes', r.break_minutes, 'note', r.note,
    'status', r.status, 'assignment_id', r.assignment_id,
    'decided_by_name', r.decided_by_name, 'decided_at', r.decided_at, 'decision_note', r.decision_note,
    'created_at', r.created_at,
    'expired', r.status = 'pending' and r.start_at <= now(),
    'on_leave', public.shift_on_leave(r.user_id, r.start_at),
    'availability', public.availability_conflict(r.user_id, r.start_at, r.end_at),
    'overlaps_assignment', r.status = 'pending' and exists (
      select 1 from public.shift_assignments a
      where a.user_id = r.user_id and tstzrange(a.start_at, a.end_at, '[)') && tstzrange(r.start_at, r.end_at, '[)')),
    'on_roster', r.assignment_id is not null and exists (select 1 from public.shift_assignments a where a.id = r.assignment_id));
$$;

revoke all on function public.shift_request_row(public.shift_requests, text) from public, anon, authenticated;

-- The manager's list. A null branch means "every branch I may view", never "any branch".
create or replace function public.list_shift_requests(
  p_branch uuid default null, p_status text default 'pending', p_from date default null, p_to date default null,
  p_search text default null, p_page integer default 1, p_page_size integer default 20
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_branches uuid[] := public.attendance_branch_ids(p_branch, 'VIEW');
  v_size     integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset   integer := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total    integer;
  v_rows     jsonb;
begin
  if p_status is not null and p_status not in ('all', 'pending', 'approved', 'rejected', 'cancelled') then
    raise exception 'invalid status' using errcode = '22023', hint = 'bad_input';
  end if;

  with picked as (
    select r.id, r.work_date, r.start_at, r.created_at
    from public.shift_requests r
    where r.branch_id = any (v_branches)
      and (p_status is null or p_status = 'all' or r.status = p_status)
      and (p_from is null or r.work_date >= p_from)
      and (p_to is null or r.work_date <= p_to)
      and (nullif(btrim(coalesce(p_search, '')), '') is null or r.user_name ilike '%' || btrim(p_search) || '%')
  ),
  page as (
    select id from picked order by work_date, start_at, created_at limit v_size offset v_offset
  )
  select (select count(*) from picked),
         coalesce((select jsonb_agg(public.shift_request_row(r, b.name) order by r.work_date, r.start_at, r.created_at)
                   from public.shift_requests r
                   join public.branches b on b.id = r.branch_id
                   where r.id in (select id from page)), '[]'::jsonb)
    into v_total, v_rows;
  return jsonb_build_object('rows', v_rows, 'total', v_total);
end;
$$;

-- Approves or rejects many requests. Each one is decided on its own, so one failure does not undo the rest.
create or replace function public.decide_shift_requests(p_ids uuid[], p_approve boolean, p_note text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me       uuid := (select auth.uid());
  v_name     text := public.staff_display_name((select auth.uid()));
  v_note     text := nullif(btrim(p_note), '');
  v_id       uuid;
  v_req      public.shift_requests;
  v_assign   uuid;
  v_hint     text;
  v_approved integer := 0;
  v_rejected integer := 0;
  v_failed   jsonb := '[]'::jsonb;
begin
  if v_me is null then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_ids is null or cardinality(p_ids) not between 1 and 200 or p_approve is null or length(coalesce(v_note, '')) > 300 then
    raise exception 'invalid request' using errcode = '22023', hint = 'bad_input';
  end if;

  foreach v_id in array p_ids loop
    begin
      select * into v_req from public.shift_requests where id = v_id for update;
      if not found then
        raise exception 'request not found' using errcode = 'P0001', hint = 'not_found';
      end if;
      if not public.can_attendance('CREATE', v_req.branch_id) then
        raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
      end if;
      if v_req.status <> 'pending' then
        raise exception 'the request was already decided' using errcode = 'P0001', hint = 'not_pending';
      end if;
      if v_req.user_id = v_me and not public.is_super_admin() then
        raise exception 'you cannot decide your own request' using errcode = 'P0001', hint = 'own_request';
      end if;

      v_assign := null;
      if p_approve then
        if v_req.start_at <= now() then
          raise exception 'the shift already started' using errcode = 'P0001', hint = 'too_late';
        end if;
        if not exists (select 1 from public.staff_branches where user_id = v_req.user_id and branch_id = v_req.branch_id) then
          raise exception 'this person no longer works at the branch' using errcode = 'P0001', hint = 'not_branch_staff';
        end if;
        -- The manager may have put this person on the same shift by hand already.
        select a.id into v_assign from public.shift_assignments a
        where a.user_id = v_req.user_id and a.branch_id = v_req.branch_id and a.work_date = v_req.work_date
          and a.template_id is not distinct from v_req.template_id and a.start_at = v_req.start_at and a.end_at = v_req.end_at
        limit 1;
        if v_assign is null then
          begin
            insert into public.shift_assignments (
              branch_id, user_id, work_date, template_id, name, start_at, end_at, break_minutes, note, created_by
            ) values (
              v_req.branch_id, v_req.user_id, v_req.work_date, v_req.template_id, v_req.name, v_req.start_at,
              v_req.end_at, v_req.break_minutes, v_req.note, v_me
            ) returning id into v_assign;
          exception when exclusion_violation then
            raise exception 'this person already has a shift at that time' using errcode = 'P0001', hint = 'shift_overlap';
          end;
        end if;
      end if;

      update public.shift_requests set
        status = case when p_approve then 'approved' else 'rejected' end,
        assignment_id = v_assign, decided_by = v_me, decided_by_name = v_name, decided_at = now(), decision_note = v_note
      where id = v_id;
      if p_approve then v_approved := v_approved + 1; else v_rejected := v_rejected + 1; end if;
    exception when others then
      get stacked diagnostics v_hint = pg_exception_hint;
      v_failed := v_failed || jsonb_build_object('id', v_id, 'hint', coalesce(v_hint, 'bad_input'));
    end;
  end loop;
  return jsonb_build_object('approved', v_approved, 'rejected', v_rejected, 'failed', v_failed);
end;
$$;

-- Badge: pending requests that can still be decided at the branches the caller manages.
create or replace function public.pending_shift_request_count(p_branch uuid default null) returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.shift_requests r
  where r.status = 'pending' and r.start_at > now()
    and r.user_id <> (select auth.uid())
    and public.can_attendance('CREATE', r.branch_id)
    and (p_branch is null or r.branch_id = p_branch);
$$;

-- The roster, now with the pending requests and the availability of the branch's staff.
-- Rewritten from the definition in supabase/schema.sql: the four old keys are unchanged.
create or replace function public.shift_roster(p_branch uuid, p_from date, p_to date) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_attendance('VIEW', p_branch) then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from + 1 > 42 then
    raise exception 'date range is longer than 42 days' using errcode = '22023', hint = 'range_too_long';
  end if;

  return jsonb_build_object(
    'staff', coalesce((
      select jsonb_agg(jsonb_build_object(
        'user_id', sb.user_id, 'name', public.staff_display_name(sb.user_id), 'role', sb.role,
        'photo_url', u.photo_url) order by public.staff_display_name(sb.user_id))
      from public.staff_branches sb
      join public.users u on u.id = sb.user_id
      where sb.branch_id = p_branch), '[]'::jsonb),
    'templates', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', t.id, 'branch_id', t.branch_id, 'name', t.name,
        'start_time', to_char(t.start_time, 'HH24:MI'), 'end_time', to_char(t.end_time, 'HH24:MI'),
        'break_minutes', t.break_minutes, 'color', t.color, 'is_active', t.is_active,
        'sort_order', t.sort_order, 'overnight', t.end_time < t.start_time)
        order by t.sort_order, t.start_time, t.name)
      from public.shift_templates t
      where t.branch_id = p_branch and t.is_active), '[]'::jsonb),
    'assignments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'user_id', a.user_id, 'work_date', a.work_date, 'template_id', a.template_id,
        'name', a.name, 'color', coalesce(t.color, 'slate'), 'start_at', a.start_at, 'end_at', a.end_at,
        'break_minutes', a.break_minutes, 'note', a.note, 'has_entry', public.assignment_has_entry(a.id))
        order by a.start_at)
      from public.shift_assignments a
      left join public.shift_templates t on t.id = a.template_id
      where a.branch_id = p_branch and a.work_date between p_from and p_to), '[]'::jsonb),
    'leaves', public.roster_leaves(p_branch, p_from, p_to),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id, 'user_id', r.user_id, 'work_date', r.work_date, 'template_id', r.template_id,
        'name', r.name, 'color', coalesce(t.color, 'slate'), 'start_at', r.start_at, 'end_at', r.end_at,
        'note', r.note, 'expired', r.start_at <= now(),
        'availability', public.availability_conflict(r.user_id, r.start_at, r.end_at),
        'on_leave', public.shift_on_leave(r.user_id, r.start_at))
        order by r.start_at, r.created_at)
      from public.shift_requests r
      left join public.shift_templates t on t.id = r.template_id
      where r.branch_id = p_branch and r.status = 'pending' and r.work_date between p_from and p_to), '[]'::jsonb),
    'availability', public.roster_availability(p_branch)
  );
end;
$$;

revoke all on function public.list_shift_requests(uuid, text, date, date, text, integer, integer) from public, anon;
revoke all on function public.decide_shift_requests(uuid[], boolean, text) from public, anon;
revoke all on function public.pending_shift_request_count(uuid) from public, anon;
grant execute on function public.list_shift_requests(uuid, text, date, date, text, integer, integer) to authenticated;
grant execute on function public.decide_shift_requests(uuid[], boolean, text) to authenticated;
grant execute on function public.pending_shift_request_count(uuid) to authenticated;
