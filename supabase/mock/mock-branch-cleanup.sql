-- Removes everything mock-branch-seed.sql created, and only that.
--
--   psql "$DATABASE_URL" -f supabase/mock/mock-branch-cleanup.sql      (or paste it into the SQL editor)
--
-- It deletes rows that belong to the branch with code 'MOCK', then the customers named '[MOCK] ...' with
-- phones 0990000001..0990000009 (and their pets), then the branch itself. The real branch's rows are
-- never matched: every delete is scoped by the MOCK branch id or by the [MOCK] customers.
-- One transaction: if anything fails nothing is deleted. Safe to run when there is nothing to remove.
begin;

do $cleanup$
declare
  v_branch uuid;
  v_table  text;
  v_pass   int;
  v_left   int;
begin
  select id into v_branch from public.branches where code = 'MOCK';
  if v_branch is null then
    raise notice 'No MOCK branch: nothing to remove.';
  else
    -- Rows hang off each other (invoice lines, stock movements, ...), so delete table by table and
    -- go round again when a foreign key still points at a row that is removed in a later table.
    for v_pass in 1..8 loop
      for v_table in
        select c.table_name
        from information_schema.columns c
        join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name
        where c.table_schema = 'public' and c.column_name = 'branch_id' and t.table_type = 'BASE TABLE'
        order by c.table_name
      loop
        begin
          execute format('delete from public.%I where branch_id = $1', v_table) using v_branch;
        exception when foreign_key_violation then
          null; -- a later table still references these rows; the next pass gets it
        end;
      end loop;
    end loop;
  end if;

  -- The mock customers (their pets and ownership rows go first).
  delete from public.pet_owners where customer_id in (select id from public.customers where full_name like '[MOCK] %');
  delete from public.pets where name like '[MOCK] %'
    and not exists (select 1 from public.pet_owners o where o.pet_id = pets.id);
  delete from public.customers where full_name like '[MOCK] %';

  if v_branch is not null then
    delete from public.branches where id = v_branch;
  end if;

  select count(*) into v_left from public.customers where full_name like '[MOCK] %';
  raise notice 'Cleanup finished. Mock customers left: %', v_left;
end
$cleanup$;

commit;
