-- In-app notifications: own rows only, mark read, dedupe, merging "schedule changed", cleanup.
begin;
\ir _helpers/setup.psql
select plan(14);

create temp table ctx as
select tests.create_user('nt_a@test.local', 'cashier') as a,
       tests.create_user('nt_b@test.local', 'cashier') as b,
       tests.create_branch('NTA') as br,
       (date_trunc('week', current_date)::date + 7) as monday;
alter table ctx add column n1 uuid, add column n2 uuid, add column n3 uuid;
grant select, update on ctx to authenticated;

update ctx set
  n1 = public.notify_user(a, br, 'publish_reminder', 'Hello A', 'body'),
  n2 = public.notify_user(b, br, 'publish_reminder', 'Hello B');

-- Reminders dedupe.
select isnt(public.notify_user((select a from ctx), (select br from ctx), 'registration_reminder', 'R', null, null, '{}', 'k1'), null, 'first reminder is stored');
select is(public.notify_user((select a from ctx), (select br from ctx), 'registration_reminder', 'R', null, null, '{}', 'k1'), null, 'the same dedupe key is ignored');

select tests.login(a) from ctx;
set local role authenticated;
select is((select (public.my_notifications() ->> 'total')::int), 2, 'I see only my own notices');
select is((select public.unread_notification_count()), 2, 'unread count');
select is((select (public.my_notifications(1, 20, true) ->> 'unread')::int), 2, 'unread list reports unread');
select is((select public.mark_notifications_read(array[(select n2 from ctx)])), 0, 'cannot mark another person''s notice');
select is((select public.mark_notifications_read(array[(select n1 from ctx)])), 1, 'marks my notice');
select is((select public.unread_notification_count()), 1, 'unread drops');
select throws_ok('select public.notify_user(gen_random_uuid(), null, ''publish_reminder'', ''x'')', '42501', null, 'clients cannot call notify_user');
reset role;

-- Schedule changed: merged while unread, new one after read.
update ctx set n3 = public.notify_schedule_changed(a, br, monday, 'first');
select is(public.notify_schedule_changed((select a from ctx), (select br from ctx), (select monday from ctx), 'second'), (select n3 from ctx), 'a second change merges into the unread notice');
select is((select (data ->> 'change_count')::int from public.notifications where id = (select n3 from ctx)), 2, 'the counter goes up');
select is((select data ->> 'reason' from public.notifications where id = (select n3 from ctx)), 'second', 'the newest reason wins');
update public.notifications set read_at = now() where id = (select n3 from ctx);
select isnt(public.notify_schedule_changed((select a from ctx), (select br from ctx), (select monday from ctx), null), (select n3 from ctx), 'after it was read a new notice starts');

-- Cleanup.
update public.notifications set created_at = now() - interval '200 days' where id = (select n2 from ctx);
select cmp_ok(public.cleanup_notifications(), '>=', 1, 'cleanup removes old notices');

select * from finish();
rollback;
