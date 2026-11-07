-- In-app notifications, shared by every module. A row is one message for one person.
-- Writes go through internal functions (notify_user, notify_schedule_changed); clients only read
-- their own rows and mark them read.
create table if not exists public.notifications (
  id         uuid        primary key default gen_random_uuid(),
  user_id    uuid        not null references public.users (id) on delete cascade,
  branch_id  uuid        references public.branches (id) on delete cascade,
  kind       text        not null check (kind in (
    'schedule_published', 'schedule_changed', 'registration_reminder', 'registration_missing', 'publish_reminder')),
  title      text        not null check (char_length(title) between 1 and 120),
  body       text        check (body is null or char_length(body) <= 500),
  link       jsonb,
  data       jsonb       not null default '{}'::jsonb,
  dedupe_key text,
  read_at    timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists notifications_dedupe_key_uidx on public.notifications (dedupe_key) where dedupe_key is not null;
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_user_unread_idx on public.notifications (user_id) where read_at is null;

drop trigger if exists notifications_set_updated_at on public.notifications;
create trigger notifications_set_updated_at before update on public.notifications
  for each row execute function public.set_updated_at();

alter table public.notifications enable row level security;
revoke all on public.notifications from anon, authenticated;
grant select on public.notifications to authenticated;

drop policy if exists "own notifications read" on public.notifications;
create policy "own notifications read" on public.notifications
  for select to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------- internal writers
-- Inserts one notification. A repeated dedupe key does nothing (reminders). Returns the id or null.
create or replace function public.notify_user(
  p_user uuid, p_branch uuid, p_kind text, p_title text, p_body text default null,
  p_link jsonb default null, p_data jsonb default '{}'::jsonb, p_dedupe text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
begin
  insert into public.notifications (user_id, branch_id, kind, title, body, link, data, dedupe_key)
  values (p_user, p_branch, p_kind, p_title, p_body, p_link, coalesce(p_data, '{}'::jsonb), p_dedupe)
  on conflict (dedupe_key) where dedupe_key is not null do nothing
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.notify_user(uuid, uuid, text, text, text, jsonb, jsonb, text) from public, anon, authenticated;

-- "The schedule changed": one unread notice per (person, branch, week). Another change raises the
-- counter and moves it to the top instead of adding a second notice. After it is read, a new one starts.
create or replace function public.notify_schedule_changed(
  p_user uuid, p_branch uuid, p_monday date, p_reason text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_count   integer;
  v_reason  text := nullif(btrim(p_reason), '');
  v_range   text := to_char(p_monday, 'DD/MM') || '–' || to_char(p_monday + 6, 'DD/MM');
  v_branch  text := (select b.name from public.branches b where b.id = p_branch);
  v_title   text;
  v_body    text;
  v_link    jsonb := jsonb_build_object('name', 'attendanceMe', 'query', jsonb_build_object('week', p_monday));
begin
  select n.id, coalesce((n.data ->> 'change_count')::integer, 1) + 1 into v_id, v_count
  from public.notifications n
  where n.user_id = p_user and n.kind = 'schedule_changed' and n.read_at is null
    and n.branch_id is not distinct from p_branch and n.data ->> 'week_monday' = p_monday::text
  order by n.created_at desc
  limit 1
  for update;

  v_count := coalesce(v_count, 1);
  v_title := left('Lịch tuần ' || v_range || ' đã thay đổi', 120);
  v_body := left(
    'Lịch tuần ' || v_range || coalesce(' tại ' || v_branch, '') || ' đã thay đổi'
    || case when v_count > 1 then ' (' || v_count || ' thay đổi)' else '' end || '.'
    || coalesce(' Lý do: ' || v_reason, ''), 500);

  if v_id is null then
    insert into public.notifications (user_id, branch_id, kind, title, body, link, data)
    values (p_user, p_branch, 'schedule_changed', v_title, v_body, v_link,
            jsonb_build_object('week_monday', p_monday, 'change_count', v_count, 'reason', v_reason))
    returning id into v_id;
  else
    update public.notifications
       set title = v_title, body = v_body, created_at = now(),
           data = jsonb_build_object('week_monday', p_monday, 'change_count', v_count, 'reason',
                                     coalesce(v_reason, data ->> 'reason'))
     where id = v_id;
  end if;
  return v_id;
end;
$$;

revoke all on function public.notify_schedule_changed(uuid, uuid, date, text) from public, anon, authenticated;

-- ---------------------------------------------------------------- what the client calls
create or replace function public.my_notifications(
  p_page integer default 1, p_page_size integer default 20, p_unread_only boolean default false
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_me     uuid := (select auth.uid());
  v_size   integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * v_size;
  v_total  integer;
  v_unread integer;
  v_rows   jsonb;
begin
  if v_me is null then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;

  select count(*) filter (where not coalesce(p_unread_only, false) or n.read_at is null),
         count(*) filter (where n.read_at is null)
    into v_total, v_unread
  from public.notifications n where n.user_id = v_me;

  select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc, p.id), '[]'::jsonb) into v_rows
  from (
    select n.id, n.branch_id, n.kind, n.title, n.body, n.link, n.data, n.read_at, n.created_at
    from public.notifications n
    where n.user_id = v_me and (not coalesce(p_unread_only, false) or n.read_at is null)
    order by n.created_at desc, n.id
    limit v_size offset v_offset
  ) p;

  return jsonb_build_object('rows', v_rows, 'total', v_total, 'unread', v_unread);
end;
$$;

create or replace function public.unread_notification_count() returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer from public.notifications n
  where n.user_id = (select auth.uid()) and n.read_at is null;
$$;

-- Marks my notifications read: the given ids, or all of mine when null. Returns how many changed.
create or replace function public.mark_notifications_read(p_ids uuid[] default null) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me uuid := (select auth.uid());
  v_n  integer;
begin
  if v_me is null then
    raise exception 'not allowed' using errcode = '42501', hint = 'forbidden';
  end if;
  update public.notifications n set read_at = now()
   where n.user_id = v_me and n.read_at is null and (p_ids is null or n.id = any (p_ids));
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.my_notifications(integer, integer, boolean) from public, anon;
revoke all on function public.unread_notification_count() from public, anon;
revoke all on function public.mark_notifications_read(uuid[]) from public, anon;
grant execute on function public.my_notifications(integer, integer, boolean) to authenticated;
grant execute on function public.unread_notification_count() to authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;

-- ---------------------------------------------------------------- cleanup
-- Read notices live 90 days, any notice 180. The real history of a schedule lives elsewhere.
create or replace function public.cleanup_notifications() returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_n integer;
begin
  delete from public.notifications
   where created_at < now() - interval '180 days'
      or (read_at is not null and read_at < now() - interval '90 days');
  get diagnostics v_n = row_count;
  return v_n;
end;
$$;

revoke all on function public.cleanup_notifications() from public, anon, authenticated;

-- 19:30 UTC = 02:30 in Vietnam, every day.
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  perform cron.unschedule('cleanup-notifications')
  where exists (select 1 from cron.job where jobname = 'cleanup-notifications');
  perform cron.schedule('cleanup-notifications', '30 19 * * *', 'select public.cleanup_notifications()');
end;
$$;
