-- Revenue reports, step 1 (1/3): permission, branch/date helpers and indexes
-- (docs: bao-cao-doanh-thu.md, sections 3.1, 4 and 5). Safe to run more than once.
--
-- Permission code "reports": VIEW = see every report at the branch, EXPORT = download CSV.
-- Reports are read through security definer RPCs; each one checks can_report('VIEW', branch).

-- --------------------------------------------------------------- permissions
insert into public.permissions (name, description, methods, module, sort_order) values
  ('reports', 'Báo cáo doanh thu, hoàn trả, đối chiếu ca', array['VIEW','EXPORT','ALL'], 'Báo cáo', 40)
on conflict (name) do nothing;

insert into public.role_permissions (role, permission, methods)
select r.role, r.permission, r.methods
from (values
  ('admin', 'reports', array['ALL'])
) as r(role, permission, methods)
where exists (select 1 from public.roles where name = r.role)
on conflict do nothing;

create or replace function public.can_report(p_method text, p_branch uuid default null) returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select public.is_admin()), false)
      or (select public.has_permission('reports', p_method, p_branch));
$$;

revoke execute on function public.can_report(text, uuid) from public, anon;
grant execute on function public.can_report(text, uuid) to authenticated;

-- ------------------------------------------------------------------- helpers
-- The branches a report covers: p_branch when given (the caller must have reports: VIEW
-- there), otherwise every branch where the caller has it.
create or replace function public.report_branch_ids(p_branch uuid) returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
begin
  if p_branch is not null then
    if not public.can_report('VIEW', p_branch) then
      raise exception 'not allowed to see reports at this branch' using errcode = '42501';
    end if;
    return array[p_branch];
  end if;

  select coalesce(array_agg(b.id), '{}') into v_ids
  from public.branches b
  where public.can_report('VIEW', b.id);

  if cardinality(v_ids) = 0 then
    raise exception 'not allowed to see reports' using errcode = '42501';
  end if;
  return v_ids;
end;
$$;

revoke execute on function public.report_branch_ids(uuid) from public, anon, authenticated;

-- [from 00:00, to + 1 day 00:00) in Vietnam time, as an absolute time range.
create or replace function public.report_range(p_from date, p_to date) returns tstzrange
language plpgsql
immutable
set search_path = ''
as $$
begin
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'invalid date range' using errcode = '22023', hint = 'invalid_range';
  end if;
  if p_to - p_from + 1 > 366 then
    raise exception 'date range is longer than 366 days' using errcode = '22023', hint = 'range_too_long';
  end if;
  return tstzrange(
    p_from::timestamp at time zone 'Asia/Ho_Chi_Minh',
    (p_to + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh',
    '[)');
end;
$$;

revoke execute on function public.report_range(date, date) from public, anon, authenticated;

-- Limits for list reports: 1..5000 rows (5000 is the CSV export).
create or replace function public.report_limit(p_limit int) returns int
language sql
immutable
set search_path = ''
as $$
  select least(greatest(coalesce(p_limit, 20), 1), 5000);
$$;

revoke execute on function public.report_limit(int) from public, anon, authenticated;

-- ------------------------------------------------------------------- indexes
create index if not exists sales_returns_branch_created_idx
  on public.sales_returns (branch_id, created_at);
create index if not exists invoices_branch_cancelled_idx
  on public.invoices (branch_id, cancelled_at) where cancelled_at is not null;
create index if not exists appointment_items_invoice_line_idx
  on public.appointment_items (invoice_line_id) where invoice_line_id is not null;
create index if not exists stock_movements_return_reason_idx
  on public.stock_movements (return_id) where reason = 'return';

notify pgrst, 'reload schema';
