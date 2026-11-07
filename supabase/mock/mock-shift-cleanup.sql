-- Removes exactly what mock-shift-seed.sql created: the MOCKCA branch (its templates, shifts,
-- requests and settings go with it) and the ten mock-ca-N@mock.invalid accounts.
-- Existing rows are untouched. One transaction.
begin;

delete from public.shift_requests where branch_id in (select id from public.branches where code = 'MOCKCA');
delete from public.shift_assignments where branch_id in (select id from public.branches where code = 'MOCKCA');
delete from public.staff_availability where user_id in (select id from auth.users where email like 'mock-ca-%@mock.invalid');
delete from public.branches where code = 'MOCKCA';
delete from auth.users where email like 'mock-ca-%@mock.invalid';

commit;
