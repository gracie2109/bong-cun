-- A vaccine reminder belongs to the branch that gave the last dose; a dose given elsewhere (no branch)
-- shows at every branch.
begin;
\ir _helpers/setup.psql
select plan(4);

create temp table ctx as
select a as branch_a, b as branch_b, tests.create_user('boss@test.local', 'admin') as boss,
       tests.create_patient('0930000001', 'Inside') as inside_owner,
       tests.create_patient('0930000002', 'Outside') as outside_owner
from tests.create_branch('VA') as a, tests.create_branch('VB') as b;
insert into public.vaccine_types (name, kind) values ('VR rabies', 'vaccine');
insert into public.vaccinations (pet_id, vaccine_type_id, branch_id, given_on, next_due_on, is_external)
select tests.pet_of(inside_owner), (select id from public.vaccine_types where name = 'VR rabies'),
       branch_a, current_date - 400, current_date - 10, false
from ctx;
insert into public.vaccinations (pet_id, vaccine_type_id, branch_id, given_on, next_due_on, is_external, external_place)
select tests.pet_of(outside_owner), (select id from public.vaccine_types where name = 'VR rabies'),
       null, current_date - 400, current_date - 10, true, 'Other clinic'
from ctx;
grant select on ctx to authenticated;

select tests.login(boss) from ctx;
set local role authenticated;

select is((select (public.medical_reminders(branch_a, 'overdue') ->> 'total')::int from ctx), 2,
          'the branch that gave the dose sees it, and the dose given elsewhere');
select is((select (public.medical_reminders(branch_b, 'overdue') ->> 'total')::int from ctx), 1,
          'another branch only sees the dose given elsewhere');
select is((select public.medical_reminders(branch_b, 'overdue') -> 'rows' -> 0 ->> 'pet_name' from ctx), 'Outside',
          'and it is that pet');
select is((select (public.medical_reminders(branch_b, 'due') ->> 'total')::int from ctx), 0,
          'nothing is due soon at the other branch');

reset role;
select * from finish();
rollback;
