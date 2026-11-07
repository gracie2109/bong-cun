-- Reminders and the safety net for publishing. Everything here runs from pg_cron, not from a client.
-- Only branches that switched publishing on (require_publish) take part: with it off nothing changes.
-- Times: pg_cron runs in UTC; the Vietnamese time is in the comments.

-- Who still has to register for a week: the "missing" state of registration_status, without needing a signed-in user.
create or replace function public.registration_missing_users(p_branch uuid, p_monday date) returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select sb.user_id
  from public.staff_branches sb
  where sb.branch_id = p_branch
    and public.staff_must_register(p_branch, sb.user_id)
    and not exists (select 1 from public.shift_requests r
                    where r.branch_id = p_branch and r.user_id = sb.user_id
                      and r.work_date between p_monday and p_monday + 6 and r.status <> 'cancelled')
    and not exists (select 1 from public.shift_registration_submissions x
                    where x.branch_id = p_branch and x.user_id = sb.user_id and x.week_monday = p_monday);
$$;

-- 24 hours before a deadline: remind the people who have not registered (once each). Right after it:
-- tell every manager of the branch how many are still missing (once each).
create or replace function public.run_registration_reminders(p_now timestamptz default now()) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s          record;
  v_monday   date;
  v_closes   timestamptz;
  v_range    text;
  v_missing  integer;
  v_sent     integer := 0;
  v_user     uuid;
  v_manager  uuid;
  v_id       uuid;
begin
  for s in
    select st.branch_id, st.weeks_ahead, st.close_days_before, b.name as branch_name
    from public.shift_registration_settings st
    join public.branches b on b.id = st.branch_id and b.is_active
    where st.is_open and st.require_publish
  loop
    for k in 0..s.weeks_ahead loop
      v_monday := public.week_of((p_now at time zone 'Asia/Ho_Chi_Minh')::date) + 7 * k;
      v_closes := (v_monday - s.close_days_before)::timestamp at time zone 'Asia/Ho_Chi_Minh';
      v_range := to_char(v_monday, 'DD/MM') || '–' || to_char(v_monday + 6, 'DD/MM');

      if v_closes > p_now and v_closes <= p_now + interval '24 hours' then
        for v_user in select * from public.registration_missing_users(s.branch_id, v_monday) loop
          v_id := public.notify_user(
            v_user, s.branch_id, 'registration_reminder',
            'Sắp hết hạn đăng ký ca tuần ' || v_range,
            'Bạn chưa đăng ký ca tuần ' || v_range || '. Hạn chót: ' || to_char(v_closes at time zone 'Asia/Ho_Chi_Minh', 'DD/MM HH24:MI') || '.',
            jsonb_build_object('name', 'attendanceRegister', 'query', '{}'::jsonb),
            jsonb_build_object('week_monday', v_monday),
            'reminder:' || s.branch_id || ':' || v_monday || ':' || v_user);
          if v_id is not null then v_sent := v_sent + 1; end if;
        end loop;
      end if;

      -- A few hours of slack so one missed run does not lose the notice; the dedupe key keeps it single.
      if v_closes <= p_now and v_closes > p_now - interval '6 hours' then
        select count(*) into v_missing from public.registration_missing_users(s.branch_id, v_monday);
        if v_missing > 0 then
          for v_manager in
            select sb.user_id from public.staff_branches sb
            where sb.branch_id = s.branch_id and public.user_has_attendance(sb.user_id, 'CREATE', s.branch_id)
          loop
            v_id := public.notify_user(
              v_manager, s.branch_id, 'registration_missing',
              v_missing || ' người chưa đăng ký ca tuần ' || v_range,
              'Đã hết hạn đăng ký tại ' || s.branch_name || '. Mở lịch ca để xem ai chưa đăng ký.',
              jsonb_build_object('name', 'attendanceRoster', 'query', '{}'::jsonb),
              jsonb_build_object('week_monday', v_monday, 'missing_count', v_missing),
              'missing:' || s.branch_id || ':' || v_monday || ':' || v_manager);
            if v_id is not null then v_sent := v_sent + 1; end if;
          end loop;
        end if;
      end if;
    end loop;
  end loop;
  return v_sent;
end;
$$;

-- Sunday evening: next week is still a draft, remind the managers (once each).
create or replace function public.run_publish_reminders() returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s         record;
  v_monday  date := public.week_of(public.vn_today()) + 7;
  v_range   text := to_char(public.week_of(public.vn_today()) + 7, 'DD/MM') || '–' || to_char(public.week_of(public.vn_today()) + 13, 'DD/MM');
  v_shifts  integer;
  v_manager uuid;
  v_sent    integer := 0;
  v_id      uuid;
begin
  for s in
    select st.branch_id, b.name as branch_name
    from public.shift_registration_settings st
    join public.branches b on b.id = st.branch_id and b.is_active
    where st.require_publish and not public.week_is_published(st.branch_id, v_monday)
  loop
    select count(*) into v_shifts from public.shift_assignments a
    where a.branch_id = s.branch_id and a.work_date between v_monday and v_monday + 6;
    for v_manager in
      select sb.user_id from public.staff_branches sb
      where sb.branch_id = s.branch_id and public.user_has_attendance(sb.user_id, 'CREATE', s.branch_id)
    loop
      v_id := public.notify_user(
        v_manager, s.branch_id, 'publish_reminder',
        'Lịch tuần ' || v_range || ' chưa phát hành',
        'Tuần sau có ' || v_shifts || ' ca tại ' || s.branch_name || ' nhưng nhân viên chưa thấy. Mở lịch ca để phát hành.',
        jsonb_build_object('name', 'attendanceRoster', 'query', '{}'::jsonb),
        jsonb_build_object('week_monday', v_monday, 'shift_count', v_shifts),
        'publish:' || s.branch_id || ':' || v_monday || ':' || v_manager);
      if v_id is not null then v_sent := v_sent + 1; end if;
    end loop;
  end loop;
  return v_sent;
end;
$$;

-- Monday 00:05: the week that has started is published if a manager forgot, so staff never work without
-- seeing their shifts. A week with nothing in it is only marked published, with no notices.
create or replace function public.auto_publish_started_weeks() returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  s        record;
  v_monday date := public.week_of(public.vn_today());
  v_busy   boolean;
  v_done   integer := 0;
begin
  for s in
    select st.branch_id from public.shift_registration_settings st
    join public.branches b on b.id = st.branch_id and b.is_active
    -- week_is_published() counts a started week as visible; here the real status is what matters.
    where st.require_publish
      and not exists (select 1 from public.schedule_weeks w
                      where w.branch_id = st.branch_id and w.week_monday = v_monday and w.status = 'published')
  loop
    select exists (select 1 from public.shift_assignments a where a.branch_id = s.branch_id and a.work_date between v_monday and v_monday + 6)
        or exists (select 1 from public.shift_requests r where r.branch_id = s.branch_id and r.status = 'pending' and r.work_date between v_monday and v_monday + 6)
      into v_busy;
    if v_busy then
      perform public.do_publish_week(s.branch_id, v_monday, true, 'Tuần đã bắt đầu, lịch được phát hành tự động');
    else
      perform set_config('app.schedule_publishing', 'on', true);
      perform set_config('app.schedule_source', 'cron:auto_publish', true);
      insert into public.schedule_weeks (branch_id, week_monday, status, published_at, published_by_name, auto_published)
      values (s.branch_id, v_monday, 'published', now(), 'Hệ thống', true)
      on conflict (branch_id, week_monday) do update set
        status = 'published', published_at = now(), published_by = null, published_by_name = 'Hệ thống', auto_published = true
      where public.schedule_weeks.status <> 'published';
    end if;
    v_done := v_done + 1;
  end loop;
  return v_done;
end;
$$;

revoke all on function public.registration_missing_users(uuid, date) from public, anon, authenticated;
revoke all on function public.run_registration_reminders(timestamptz) from public, anon, authenticated;
revoke all on function public.run_publish_reminders() from public, anon, authenticated;
revoke all on function public.auto_publish_started_weeks() from public, anon, authenticated;

-- Schedules (UTC): hourly at :10; Sunday 11:00 = 18:00 in Vietnam; Sunday 17:05 = Monday 00:05 in Vietnam.
do $$
begin
  perform cron.unschedule(jobname) from cron.job
  where jobname in ('registration-reminders', 'publish-reminders', 'auto-publish-weeks');
  perform cron.schedule('registration-reminders', '10 * * * *', 'select public.run_registration_reminders()');
  perform cron.schedule('publish-reminders', '0 11 * * 0', 'select public.run_publish_reminders()');
  perform cron.schedule('auto-publish-weeks', '5 17 * * 0', 'select public.auto_publish_started_weeks()');
end;
$$;
