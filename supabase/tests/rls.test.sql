begin;
\ir _helpers/setup.psql
select plan(2);

select is(
  (select array_agg(c.relname::text order by c.relname)
   from pg_class c
   where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p') and not c.relrowsecurity),
  null,
  'every table in public has row level security on'
);

select is(
  (select array_agg(p.proname::text order by p.proname)
   from pg_proc p
   where p.pronamespace = 'public'::regnamespace and p.prosecdef
     and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  null,
  'every security definer function in public pins its search_path'
);

select * from finish();
rollback;
