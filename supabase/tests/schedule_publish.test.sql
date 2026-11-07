-- Publishing a week: off by default (nothing changes), draft weeks hidden from staff, publish rejects
-- pending requests and notifies, locked registration, merged "schedule changed" notices, who has not
-- registered, publishing existing weeks, branch scope.
begin;
\ir _helpers/setup.psql
select plan(29);

insert into public.roles (name) values ('t_pub');
insert into public.role_permissions (role, permission, methods)
values ('t_pub', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select b.ba, b.bb,
  tests.create_staff('pu_mgr_a@test.local', b.ba, 't_pub') as mgr_a,
  tests.create_staff('pu_mgr_b@test.local', b.bb, 't_pub') as mgr_b,
  tests.create_staff('pu_a@test.local', b.ba, 'cashier') as sa,
  tests.create_staff('pu_b@test.local', b.ba, 'cashier') as sb,
  tests.create_staff('pu_c@test.local', b.ba, 'cashier') as sc,
  tests.create_staff('pu_d@test.local', b.ba, 'cashier') as sd,
  tests.create_staff('pu_e@test.local', b.ba, 'cashier') as se,
  tests.create_staff('pu_x@test.local', b.bb, 'cashier') as sx,
  public.week_of(current_date) as this_monday,
  (public.week_of(current_date) + 14) as monday,
  gen_random_uuid() as tpl_a, gen_random_uuid() as tpl_b
from (select tests.create_branch('PUA') as ba, tests.create_branch('PUB') as bb) b;
alter table ctx add column res jsonb, add column shift_a uuid, add column shift_c uuid, add column shift_now uuid;
grant select, update on ctx to authenticated;

insert into public.shift_templates (id, branch_id, name, start_time, end_time)
select tpl_a, ba, 'Morning', time '08:00', time '12:00' from ctx
union all select tpl_b, bb, 'Morning', time '08:00', time '12:00' from ctx;
insert into public.shift_registration_settings (branch_id, is_open, weeks_ahead, close_days_before)
select ba, true, 4, 3 from ctx;

-- Shifts as the owner: A in the target week, one in the current week.
create or replace function pg_temp.shift(p_user uuid, p_branch uuid, p_date date, p_tpl uuid) returns uuid language sql as $$
  insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at)
  values (p_branch, p_user, p_date, p_tpl, 'Morning', public.shift_start_at(p_date, time '08:00'), public.shift_end_at(p_date, time '08:00', time '12:00'))
  returning id;
$$;
update ctx set shift_a = pg_temp.shift(sa, ba, monday, tpl_a), shift_now = pg_temp.shift(sa, ba, this_monday, tpl_a);

-- 1. Publishing off: staff see everything, edits send no notice.
select tests.login(sa) from ctx;
set local role authenticated;
select is((select jsonb_array_length(public.my_schedule((select monday from ctx), (select monday + 6 from ctx)) -> 'assignments')), 1, 'publishing off: staff see the shift at once');
reset role;
update public.shift_assignments set note = 'changed' where id = (select shift_a from ctx);
select is((select count(*)::int from public.notifications where kind = 'schedule_changed'), 0, 'publishing off: no change notice');

-- 2. Manager turns publishing on (without publishing the existing weeks).
select tests.login(mgr_a) from ctx;
set local role authenticated;
select public.save_shift_registration_settings((select ba from ctx), '{"is_open":true,"weeks_ahead":4,"close_days_before":3,"require_publish":true}'::jsonb);
select is((select (public.shift_registration_rules(ba) ->> 'require_publish')::boolean from ctx), true, 'the switch is saved');
reset role;

-- 3. Draft week is hidden, the current week stays visible.
select tests.login(sa) from ctx;
set local role authenticated;
select is((select jsonb_array_length(public.my_schedule((select monday from ctx), (select monday + 6 from ctx)) -> 'assignments')), 0, 'a draft week is hidden from staff');
select is((select jsonb_array_length(public.my_schedule((select this_monday from ctx), (select this_monday + 6 from ctx)) -> 'assignments')), 1, 'the week that has started stays visible');
reset role;

-- 4. Requests, a declaration, "like last week".
select tests.login(sa) from ctx;
set local role authenticated;
select public.submit_shift_requests((select ba from ctx), (select monday from ctx), format(
  '[{"work_date":"%s","template_id":"%s"},{"work_date":"%s","template_id":"%s"}]', (select monday + 1 from ctx), (select tpl_a from ctx), (select monday + 2 from ctx), (select tpl_a from ctx))::jsonb);
reset role;
select tests.login(sb) from ctx;
set local role authenticated;
select public.declare_no_shifts((select ba from ctx), (select monday from ctx), 'travelling');
reset role;
select tests.login(sd) from ctx;
set local role authenticated;
select public.declare_no_shifts((select ba from ctx), (select monday from ctx));
select public.submit_shift_requests((select ba from ctx), (select monday from ctx), format('[{"work_date":"%s","template_id":"%s"}]', (select monday + 3 from ctx), (select tpl_a from ctx))::jsonb);
select is((select count(*)::int from public.shift_registration_submissions where user_id = (select sd from ctx)), 0, 'asking for shifts clears an earlier declaration');
select throws_ok(format('select public.declare_no_shifts(%L, %L)', (select ba from ctx), (select monday from ctx)), 'P0001', null, 'declaring with open requests is refused');
reset role;

update ctx set shift_c = pg_temp.shift(sc, ba, monday - 7 + 1, tpl_a);
select tests.login(mgr_a) from ctx;
set local role authenticated;
select public.set_registration_exemption((select ba from ctx), (select se from ctx), true, 'fixed shifts');
update ctx set res = public.assign_to_previous_week(ba, monday, sc);
select is((select res ->> 'copied' from ctx), '1', 'like last week copies the person''s shifts');
select is((select res ->> 'copied' from (select public.assign_to_previous_week((select ba from ctx), (select monday from ctx), (select sc from ctx)) as res) x), '0', 'a second run copies nothing');

-- 5. Approve one of A's requests; it stays hidden as "submitted".
select public.decide_shift_requests(array[(select id from public.shift_requests where user_id = (select sa from ctx) and work_date = (select monday + 1 from ctx))], true);
reset role;
select tests.login(sa) from ctx;
set local role authenticated;
select is((select r ->> 'status' from jsonb_array_elements(public.shift_registration_board((select ba from ctx), (select monday from ctx)) -> 'requests') r
           where r ->> 'work_date' = (select (monday + 1)::text from ctx)), 'submitted', 'a decision is hidden until the week is published');
select is((select jsonb_array_length(public.shift_registration_board((select ba from ctx), (select monday from ctx)) -> 'assignments')), 0, 'the board shows no shift of a draft week');
reset role;

-- 6. Who has not registered.
select tests.login(mgr_a) from ctx;
set local role authenticated;
update ctx set res = public.registration_status(ba, monday);
select is((select res ->> 'missing_count' from ctx), '1', 'one person has not registered');
select is((select r ->> 'state' from ctx, jsonb_array_elements(res -> 'rows') r where (r ->> 'user_id')::uuid = sb), 'declared_none', 'a declaration counts');
select is((select r ->> 'state' from ctx, jsonb_array_elements(res -> 'rows') r where (r ->> 'user_id')::uuid = se), 'exempt', 'an exempted person is not asked');
select is((select r ->> 'state' from ctx, jsonb_array_elements(res -> 'rows') r where (r ->> 'user_id')::uuid = mgr_a), 'manager', 'a manager is not asked');
reset role;

-- 7. Staff and other branches cannot publish.
select tests.login(sa) from ctx;
set local role authenticated;
select throws_ok(format('select public.publish_schedule_week(%L, %L)', (select ba from ctx), (select monday from ctx)), '42501', 'not allowed', 'staff cannot publish');
reset role;
select tests.login(mgr_b) from ctx;
set local role authenticated;
select throws_ok(format('select public.publish_schedule_week(%L, %L)', (select ba from ctx), (select monday from ctx)), '42501', 'not allowed', 'another branch''s manager cannot publish');
reset role;

-- 8. Publish.
select tests.login(mgr_a) from ctx;
set local role authenticated;
update ctx set res = public.publish_schedule_week(ba, monday);
select is((select res ->> 'rejected' from ctx), '2', 'pending requests are rejected');
select is((select res ->> 'notified' from ctx), '4', 'every person who has shifts or had to register is told');
select throws_ok(format('select public.publish_schedule_week(%L, %L)', (select ba from ctx), (select monday from ctx)), 'P0001', 'the week is already published', 'publishing twice is refused');
reset role;
select is((select count(*)::int from public.notifications where kind = 'schedule_published'), 4, 'four publish notices exist');

-- 9. After publishing.
select tests.login(sa) from ctx;
set local role authenticated;
select is((select jsonb_array_length(public.my_schedule((select monday from ctx), (select monday + 6 from ctx)) -> 'assignments')), 2, 'the shifts appear (the old one and the approved request)');
select throws_ok(format('select public.submit_shift_requests(%L, %L, %L::jsonb)', (select ba from ctx), (select monday from ctx),
  format('[{"work_date":"%s","template_id":"%s"}]', (select monday + 5 from ctx), (select tpl_a from ctx))), 'P0001', null, 'staff can no longer send requests for a published week');
reset role;

-- 10. Edits after publishing: one merged notice per person.
select tests.login(mgr_a) from ctx;
set local role authenticated;
select public.update_shift_assignment((select shift_a from ctx), '{"note":"n1"}'::jsonb, 'first');
select public.update_shift_assignment((select shift_a from ctx), '{"note":"n2"}'::jsonb, 'second');
select public.update_shift_assignment((select shift_a from ctx), '{"note":"n3"}'::jsonb, 'third');
reset role;
select is((select count(*)::int from public.notifications where kind = 'schedule_changed' and user_id = (select sa from ctx)), 1, 'three edits make one notice');
select is((select (data ->> 'change_count')::int from public.notifications where kind = 'schedule_changed' and user_id = (select sa from ctx)), 3, 'the notice counts the edits');
select is((select count(*)::int from public.schedule_history where entity = 'assignment' and was_published and action = 'update'), 3, 'history marks the edits made after publishing');

-- 11. A draft week sends nothing.
update ctx set res = to_jsonb(pg_temp.shift(sa, ba, monday + 7, tpl_a));
select is((select count(*)::int from public.notifications where kind = 'schedule_changed' and (data ->> 'week_monday')::date = (select monday + 7 from ctx)), 0, 'editing a draft week sends no notice');

-- 12. Switching on with existing weeks.
update public.shift_registration_settings set require_publish = false where branch_id = (select bb from ctx);
update ctx set res = to_jsonb(pg_temp.shift(sx, bb, monday, tpl_b));
select tests.login(mgr_b) from ctx;
set local role authenticated;
select public.save_shift_registration_settings((select bb from ctx), '{"require_publish":true,"publish_existing":true}'::jsonb);
reset role;
select is((select status from public.schedule_weeks where branch_id = (select bb from ctx) and week_monday = (select monday from ctx)), 'published', 'existing future weeks are published when the switch goes on');
select is((select count(*)::int from public.notifications where branch_id = (select bb from ctx)), 0, 'and nobody is notified');

select * from finish();
rollback;
