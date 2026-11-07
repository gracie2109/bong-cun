-- Mock data to try shift registration with realistic volume (availability, requests, approval, roster).
--
-- Not a migration: nothing runs it automatically. Paste it into the Supabase SQL editor, or
--   psql "$DATABASE_URL" -f supabase/mock/mock-shift-seed.sql
--
-- Everything is tagged so mock-shift-cleanup.sql removes exactly it:
--   * a branch with code 'MOCKCA' (templates, shifts, requests and settings hang off it),
--   * ten staff accounts mock-ca-1..10@mock.invalid (no password, nobody can sign in as them).
-- It never changes an existing row. Admins see the branch in the branch picker.
-- Contents: registration open; ten staff with Vietnamese names and availability; shifts for last
-- week and this week (about 4 days each, never on a day the person blocked); requests for next
-- week (pending, approved, rejected, cancelled) and the week after (pending). Some pending
-- requests land on blocked days on purpose so the warnings show.
-- Publishing is switched on (deadline 3 days before Monday = Friday 00:00): last week and this week are
-- published, next week stays a draft; the first person without a request next week declared "no shifts",
-- the others without one show up as "not registered"; the first user gets two sample notifications.
-- One transaction; running it twice is refused.
begin;

do $seed$
declare
  v_branch  uuid;
  v_admin   uuid;
  v_tpl     uuid[] := '{}';
  v_staff   uuid[] := '{}';
  v_names   text[] := array['Nguyễn Minh Anh', 'Trần Quốc Bảo', 'Lê Thu Hà', 'Phạm Gia Huy', 'Võ Ngọc Lan',
                            'Đặng Hoàng Nam', 'Bùi Thanh Tâm', 'Hoàng Mỹ Linh', 'Phan Đức Trí', 'Đỗ Khánh Vy'];
  -- Weekday (1 = Monday) each person cannot work; 0 = none.
  v_off     int[] := array[2, 0, 5, 0, 7, 3, 0, 6, 0, 4];
  v_monday  date := date_trunc('week', current_date)::date;
  v_next    date := date_trunc('week', current_date)::date + 7;
  v_tname   text[] := array['Ca sáng', 'Ca chiều', 'Ca tối'];
  v_tstart  time[] := array[time '07:30', time '12:00', time '16:30'];
  v_tend    time[] := array[time '12:00', time '16:30', time '21:00'];
  v_id      uuid;
  v_asg     uuid;
  v_day     date;
  v_tp      int;
  v_status  text;
  i         int;
  d         int;
begin
  if exists (select 1 from public.branches where code = 'MOCKCA') then
    raise exception 'The MOCKCA branch already exists. Run mock-shift-cleanup.sql first.';
  end if;
  select u.id into v_admin from public.users u order by u.created_at limit 1;
  if v_admin is null then raise exception 'No user account found.'; end if;

  insert into public.branches (code, name) values ('MOCKCA', 'Chi nhánh mẫu ca làm (MOCKCA)') returning id into v_branch;

  insert into public.shift_registration_settings (branch_id, is_open, weeks_ahead, close_days_before, max_shifts_per_week, staff_note, updated_by, require_publish)
  values (v_branch, true, 3, 3, 5, 'Cuối tuần cần ít nhất 3 người. Đăng ký trước 0h thứ Sáu.', v_admin, true);

  for i in 1..3 loop
    insert into public.shift_templates (branch_id, name, start_time, end_time, color, sort_order)
    values (v_branch, v_tname[i], v_tstart[i], v_tend[i], (array['teal', 'sky', 'violet'])[i], i) returning id into v_id;
    v_tpl := v_tpl || v_id;
  end loop;

  for i in 1..10 loop
    v_id := gen_random_uuid();
    insert into auth.users (id, instance_id, aud, role, email, raw_user_meta_data, created_at, updated_at)
    values (v_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            'mock-ca-' || i || '@mock.invalid', jsonb_build_object('full_name', v_names[i]), now(), now());
    update public.users set role = 'cashier' where id = v_id;
    insert into public.staff_branches (user_id, branch_id, role) values (v_id, v_branch, 'cashier');
    v_staff := v_staff || v_id;
  end loop;

  -- Availability: a blocked weekday, a few time-range blocks and some preferred slots.
  for i in 1..10 loop
    if v_off[i] > 0 then
      insert into public.staff_availability (user_id, weekday, kind, note)
      values (v_staff[i], v_off[i], 'unavailable',
              (array['Đi học cả ngày', null, 'Việc gia đình', 'Học thêm', 'Đi làm thêm', 'Về quê'])[1 + i % 6]);
    end if;
  end loop;
  insert into public.staff_availability (user_id, weekday, kind, start_time, end_time, note) values
    (v_staff[2], 3, 'unavailable', '16:30', '21:00', 'Học buổi tối'),
    (v_staff[4], 1, 'unavailable', '07:30', '12:00', 'Có lớp sáng thứ Hai'),
    (v_staff[7], 5, 'unavailable', '12:00', '16:30', null),
    (v_staff[9], 4, 'unavailable', '16:30', '21:00', 'Đón em'),
    (v_staff[1], 6, 'preferred', '07:30', '12:00', 'Thích ca sáng cuối tuần'),
    (v_staff[3], 7, 'preferred', null, null, null),
    (v_staff[5], 6, 'preferred', '12:00', '21:00', null),
    (v_staff[6], 2, 'preferred', '07:30', '12:00', null),
    (v_staff[8], 1, 'preferred', '16:30', '21:00', null),
    (v_staff[10], 7, 'preferred', '07:30', '16:30', null);

  -- Roster: last week and this week, about four days each, never on a day the person blocked.
  for i in 1..10 loop
    for d in -7..6 loop
      v_day := v_monday + d;
      continue when ((i * 2 + d + 14) % 7) >= 4;
      continue when extract(isodow from v_day)::int = v_off[i];
      v_tp := ((i + d + 14) % 3) + 1;
      insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at, created_by)
      values (v_branch, v_staff[i], v_day, v_tpl[v_tp], v_tname[v_tp],
              public.shift_start_at(v_day, v_tstart[v_tp]), public.shift_end_at(v_day, v_tstart[v_tp], v_tend[v_tp]), v_admin);
    end loop;
  end loop;

  -- Requests: next week (mixed outcomes) and the week after (all pending).
  for i in 1..10 loop
    for d in 7..20 loop
      v_day := v_monday + d;
      continue when ((i * 3 + d * 5) % 7) not in (0, 1);
      -- The last two people send nothing for next week: one declares it below, the other is "not registered".
      continue when i in (9, 10) and d < 14;
      v_tp := ((i + d) % 3) + 1;
      v_status := case when d >= 14 then 'pending'
                       else (array['approved', 'rejected', 'cancelled', 'pending', 'pending', 'pending', 'approved', 'pending', 'pending', 'pending'])[1 + (i + d) % 10] end;
      v_asg := null;
      if v_status = 'approved' then
        insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at, created_by)
        values (v_branch, v_staff[i], v_day, v_tpl[v_tp], v_tname[v_tp],
                public.shift_start_at(v_day, v_tstart[v_tp]), public.shift_end_at(v_day, v_tstart[v_tp], v_tend[v_tp]), v_admin)
        returning id into v_asg;
      end if;
      insert into public.shift_requests (
        branch_id, user_id, user_name, work_date, template_id, name, start_at, end_at, status, assignment_id,
        decided_by, decided_by_name, decided_at, decision_note, note)
      values (
        v_branch, v_staff[i], v_names[i], v_day, v_tpl[v_tp], v_tname[v_tp],
        public.shift_start_at(v_day, v_tstart[v_tp]), public.shift_end_at(v_day, v_tstart[v_tp], v_tend[v_tp]), v_status, v_asg,
        case when v_status in ('approved', 'rejected') then v_admin end,
        case when v_status in ('approved', 'rejected') then 'Quản lý' end,
        case when v_status in ('approved', 'rejected') then now() - (i || ' hours')::interval end,
        case when v_status = 'rejected' then 'Đã đủ người ca này' end,
        case when v_status = 'pending' and (i + d) % 4 = 0 then 'Mong được xếp ca này' end);
    end loop;
  end loop;

  -- Publishing: the past and the running week are published, next week is a draft.
  insert into public.schedule_weeks (branch_id, week_monday, status, published_at, published_by, published_by_name)
  values (v_branch, v_monday - 7, 'published', now() - interval '9 days', v_admin, 'Quản lý'),
         (v_branch, v_monday, 'published', now() - interval '2 days', v_admin, 'Quản lý');

  -- The first person with no request next week said they are not working; the others stay "not registered".
  insert into public.shift_registration_submissions (branch_id, user_id, week_monday, reason)
  select v_branch, u, v_next, 'Về quê'
  from unnest(v_staff) as u
  where not exists (select 1 from public.shift_requests r
                    where r.user_id = u and r.work_date between v_next and v_next + 6 and r.status <> 'cancelled')
  limit 1;

  perform public.notify_user(v_admin, v_branch, 'publish_reminder', 'Lịch tuần ' || to_char(v_next, 'DD/MM') || ' chưa phát hành',
    'Tuần sau nhân viên chưa thấy lịch. Mở lịch ca để phát hành.', jsonb_build_object('name', 'attendanceRoster', 'query', '{}'::jsonb),
    jsonb_build_object('week_monday', v_next));
  perform public.notify_user(v_admin, v_branch, 'registration_missing', 'Có người chưa đăng ký ca tuần ' || to_char(v_next, 'DD/MM'),
    'Đã hết hạn đăng ký. Mở lịch ca để xem ai chưa đăng ký.', jsonb_build_object('name', 'attendanceRoster', 'query', '{}'::jsonb),
    jsonb_build_object('week_monday', v_next));
end;
$seed$;

commit;
