-- Mock data to try shift registration (availability, requests, approval, roster).
--
-- Not a migration: nothing runs it automatically. Paste it into the Supabase SQL editor, or
--   psql "$DATABASE_URL" -f supabase/mock/mock-shift-seed.sql
--
-- Everything is tagged so mock-shift-cleanup.sql removes exactly it:
--   * a branch with code 'MOCKCA' (shifts, templates, requests and settings hang off it),
--   * five staff accounts mock-ca-1..5@mock.invalid (no password, nobody can sign in as them).
-- It never changes an existing row. Admins see the branch in the branch picker.
-- One transaction; running it twice is refused.
begin;

do $seed$
declare
  v_branch  uuid;
  v_admin   uuid;
  v_tpl     uuid[] := '{}';
  v_staff   uuid[] := '{}';
  v_names   text[] := array['An', 'Bình', 'Chi', 'Dũng', 'Hà'];
  v_monday  date := date_trunc('week', current_date)::date;
  v_next    date := date_trunc('week', current_date)::date + 7;
  v_id      uuid;
  v_asg     uuid;
  i         int;
  t         record;
begin
  if exists (select 1 from public.branches where code = 'MOCKCA') then
    raise exception 'The MOCKCA branch already exists. Run mock-shift-cleanup.sql first.';
  end if;
  select u.id into v_admin from public.users u order by u.created_at limit 1;
  if v_admin is null then raise exception 'No user account found.'; end if;

  insert into public.branches (code, name) values ('MOCKCA', 'Chi nhánh mẫu ca làm (MOCKCA)') returning id into v_branch;

  -- Registration is open: 3 weeks ahead, closes 1 day before Monday, 5 shifts a week.
  insert into public.shift_registration_settings (branch_id, is_open, weeks_ahead, close_days_before, max_shifts_per_week, staff_note, updated_by)
  values (v_branch, true, 3, 1, 5, 'Cuối tuần cần ít nhất 2 người', v_admin);

  for t in select * from (values
    ('Ca sáng', time '08:00', time '12:00', 'teal', 1),
    ('Ca chiều', time '13:00', time '17:00', 'sky', 2),
    ('Ca tối', time '17:00', time '21:00', 'violet', 3)) v(name, s, e, color, ord)
  loop
    insert into public.shift_templates (branch_id, name, start_time, end_time, color, sort_order)
    values (v_branch, t.name, t.s, t.e, t.color, t.ord) returning id into v_id;
    v_tpl := v_tpl || v_id;
  end loop;

  -- Staff: auth account (the trigger creates public.users) plus a role at the mock branch.
  for i in 1..5 loop
    v_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'mock-ca-' || i || '@mock.invalid', jsonb_build_object('full_name', '[MOCK] ' || v_names[i]), now(), now());
    update public.users set role = 'cashier' where id = v_id;
    insert into public.staff_branches (user_id, branch_id, role) values (v_id, v_branch, 'cashier');
    v_staff := v_staff || v_id;
  end loop;

  -- Availability: An cannot work Tuesdays, Bình prefers Saturday mornings, Chi is out Friday evenings.
  insert into public.staff_availability (user_id, weekday, kind, start_time, end_time, note) values
    (v_staff[1], 2, 'unavailable', null, null, 'Đi học cả ngày'),
    (v_staff[2], 6, 'preferred', '08:00', '12:00', null),
    (v_staff[3], 5, 'unavailable', '17:00', '21:00', 'Bận việc nhà'),
    (v_staff[4], 7, 'preferred', null, null, null);

  -- Shifts already on the roster this week and the next (made by hand).
  for i in 0..4 loop
    foreach v_id in array v_staff[1:3] loop
      continue when i = 1 and v_id = v_staff[1];
      insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at, created_by)
      select v_branch, v_id, v_monday + i, v_tpl[1], 'Ca sáng',
             public.shift_start_at(v_monday + i, time '08:00'), public.shift_end_at(v_monday + i, time '08:00', time '12:00'), v_admin;
    end loop;
  end loop;

  -- Requests for next week. staff, day offset, template, status, note.
  -- Pending: a clean one; one on An's blocked Tuesday; one on Chi's blocked Friday evening;
  -- one on Bình's preferred Saturday morning. Decided: Dũng approved (and put on the roster),
  -- Hà rejected, Dũng cancelled one.
  for t in select * from (values
    (4, 0, 1, 'pending',   null),
    (1, 1, 1, 'pending',   'Xin đổi ca nếu được'),
    (3, 4, 3, 'pending',   null),
    (2, 5, 1, 'pending',   'Thích ca sáng thứ Bảy'),
    (4, 2, 2, 'approved',  null),
    (5, 3, 2, 'rejected',  'Đủ người ca chiều'),
    (4, 6, 3, 'cancelled', null)) v(ix, d, tp, status, note)
  loop
    declare
      v_s time := (select start_time from public.shift_templates where id = v_tpl[t.tp]);
      v_e time := (select end_time from public.shift_templates where id = v_tpl[t.tp]);
      v_n text := (select name from public.shift_templates where id = v_tpl[t.tp]);
    begin
      v_asg := null;
      if t.status = 'approved' then
        insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at, created_by)
        values (v_branch, v_staff[t.ix], v_next + t.d, v_tpl[t.tp], v_n,
                public.shift_start_at(v_next + t.d, v_s), public.shift_end_at(v_next + t.d, v_s, v_e), v_admin)
        returning id into v_asg;
      end if;
      insert into public.shift_requests (
        branch_id, user_id, user_name, work_date, template_id, name, start_at, end_at, status, assignment_id,
        decided_by, decided_by_name, decided_at, decision_note, note)
      values (
        v_branch, v_staff[t.ix], '[MOCK] ' || v_names[t.ix], v_next + t.d, v_tpl[t.tp], v_n,
        public.shift_start_at(v_next + t.d, v_s), public.shift_end_at(v_next + t.d, v_s, v_e), t.status, v_asg,
        case when t.status in ('approved', 'rejected') then v_admin end,
        case when t.status in ('approved', 'rejected') then 'Quản lý' end,
        case when t.status in ('approved', 'rejected') then now() end,
        case when t.status = 'rejected' then t.note end,
        case when t.status <> 'rejected' then t.note end);
    end;
  end loop;
end;
$seed$;

commit;
