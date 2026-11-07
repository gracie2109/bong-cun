-- Shifts on days that have passed cannot be added, changed, moved, removed or copied into; today still can.
begin;
\ir _helpers/setup.psql
select plan(10);

insert into public.roles (name) values ('t_hr');
insert into public.role_permissions (role, permission, methods)
values ('t_hr', 'attendance', array['CREATE', 'VIEW', 'UPDATE', 'DELETE', 'SETTING']);

create temp table ctx as
select a as ba, public.vn_today() as today, public.week_of(public.vn_today()) as this_monday
from tests.create_branch('NPA') as a;
alter table ctx add column hr uuid, add column s1 uuid, add column s2 uuid, add column tpl uuid, add column past_id uuid, add column today_id uuid, add column res jsonb;
update ctx set
  hr = tests.create_staff('np-hr@test.local', ba, 't_hr'),
  s1 = tests.create_staff('np-s1@test.local', ba, 'cashier'),
  s2 = tests.create_staff('np-s2@test.local', ba, 'cashier');
grant select, update on ctx to authenticated;

insert into public.shift_templates (branch_id, name, start_time, end_time) select ba, 'Morning', time '08:00', time '12:00' from ctx;
update ctx set tpl = (select id from public.shift_templates where branch_id = ba);

-- A shift that was already on the roster yesterday (written directly: the RPCs refuse it now).
update ctx set past_id = gen_random_uuid(), today_id = gen_random_uuid();
insert into public.shift_assignments (id, branch_id, user_id, work_date, template_id, name, start_at, end_at)
select past_id, ba, s1, today - 1, tpl, 'Morning', public.shift_start_at(today - 1, time '08:00'), public.shift_end_at(today - 1, time '08:00', time '12:00') from ctx;

select tests.login(hr) from ctx;
set local role authenticated;

select throws_ok(
  format($$select public.assign_shift(%L, %L, %L::date, %L)$$, (select ba from ctx), (select s2 from ctx), (select today - 1 from ctx), (select tpl from ctx)),
  'P0001', 'past days cannot be changed', 'a shift cannot be added on a past day');
select throws_ok(
  format($$select public.update_shift_assignment(%L, '{"note":"x"}'::jsonb)$$, (select past_id from ctx)),
  'P0001', 'past days cannot be changed', 'a past shift cannot be edited');
select throws_ok(
  format($$select public.remove_shift_assignment(%L)$$, (select past_id from ctx)),
  'P0001', 'past days cannot be changed', 'a past shift cannot be removed');

update ctx set res = public.assign_shift(ba, s2, today, tpl);
select ok((select res ->> 'id' from ctx) is not null, 'a shift can still be added today');
update ctx set today_id = (res ->> 'id')::uuid;
select throws_ok(
  format($$select public.update_shift_assignment(%L, jsonb_build_object('work_date', %L::date))$$, (select today_id from ctx), (select today - 1 from ctx)),
  'P0001', 'past days cannot be changed', 'a shift cannot be moved to a past day');
select lives_ok(format($$select public.remove_shift_assignment(%L)$$, (select today_id from ctx)), 'today stays removable');

-- Copy: a week that is entirely past is refused; a week that has started skips its past days.
select throws_ok(
  format($$select public.copy_roster_week(%L, %L::date, %L::date)$$, (select ba from ctx), (select this_monday + 7 from ctx), (select this_monday - 7 from ctx)),
  'P0001', 'past days cannot be changed', 'copying into a week that is over is refused');

reset role;
insert into public.shift_assignments (branch_id, user_id, work_date, template_id, name, start_at, end_at)
select ba, s1, this_monday + 14 + 0, tpl, 'Morning', public.shift_start_at(this_monday + 14, time '08:00'), public.shift_end_at(this_monday + 14, time '08:00', time '12:00') from ctx
union all
select ba, s1, this_monday + 14 + 6, tpl, 'Morning', public.shift_start_at(this_monday + 14 + 6, time '08:00'), public.shift_end_at(this_monday + 14 + 6, time '08:00', time '12:00') from ctx;
select tests.login(hr) from ctx;
set local role authenticated;
update ctx set res = public.copy_roster_week(ba, this_monday + 14, this_monday);
select is((select (res ->> 'copied')::int + (res ->> 'skipped_past')::int from ctx), 2, 'every source shift is either copied or counted as past');
select ok((select count(*) from public.shift_assignments a, ctx where a.branch_id = ctx.ba and a.work_date >= ctx.this_monday and a.work_date < ctx.this_monday + 7 and a.work_date < ctx.today and a.id <> ctx.past_id) = 0, 'nothing was created on a past day');
select is((select (res ->> 'skipped')::int - (res ->> 'skipped_past')::int from ctx), 0, 'only past days were skipped');

select * from finish();
rollback;
