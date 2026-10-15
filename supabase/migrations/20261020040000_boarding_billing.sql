-- Pet hotel, step 4 (1/2): boarding charges can be paid in the POS (docs/khach-san-thu-cung.md, 6).
-- Runs after 20261020030100_boarding_check_in_out.sql; 20261020040100_boarding_invoice_rpcs.sql follows.
-- Re-runnable.

-- ------------------------------------------------------------ invoice lines
-- A boarding line has no catalog item: name, qty and price come from the charge.
alter table public.invoice_lines drop constraint if exists invoice_lines_item_type_check;
alter table public.invoice_lines
  add constraint invoice_lines_item_type_check check (item_type in ('product', 'service', 'combo', 'boarding'));

alter table public.invoice_lines drop constraint if exists invoice_lines_check;
alter table public.invoice_lines
  add constraint invoice_lines_check check (
    (item_type = 'product' and product_id is not null and service_id is null and combo_id is null)
    or (item_type = 'service' and service_id is not null and product_id is null and combo_id is null)
    or (item_type = 'combo' and combo_id is not null and product_id is null and service_id is null)
    or (item_type = 'boarding' and product_id is null and service_id is null and combo_id is null)
  );

-- ------------------------------------------------------------------- status
-- A checked-out stay is "paid" once every charge is on an invoice; a cancelled invoice clears the
-- links, which brings the stay back to "checked_out".
create or replace function public.refresh_boarding_stay_status(p_id uuid) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_open int;
begin
  select count(*) into v_open from public.boarding_charges where stay_id = p_id and invoice_line_id is null;

  update public.boarding_stays set status = case when v_open = 0 then 'paid' else 'checked_out' end
  where id = p_id and status in ('checked_out', 'paid');
end;
$$;

revoke execute on function public.refresh_boarding_stay_status(uuid) from public, anon, authenticated;

-- ----------------------------------------------------------------- billable
-- The checked-out stays of a customer with charges that are not on an invoice yet, for the POS
-- cart: [{ stay_id, code, total, charges: [{ id, kind, name, qty, unit_price, amount, pet_name }] }].
create or replace function public.billable_boarding_charges(p_branch uuid, p_customer uuid) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.can_pos('CREATE', p_branch) then
    raise exception 'not allowed' using errcode = '42501';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'stay_id', s.id,
      'code', s.code,
      'total', c.total,
      'charges', c.charges
    ) order by s.checked_out_at, s.code)
    from public.boarding_stays s
    cross join lateral (
      select sum(bc.amount) as total,
             jsonb_agg(jsonb_build_object(
               'id', bc.id,
               'kind', bc.kind,
               'name', bc.name,
               'qty', bc.qty,
               'unit_price', bc.unit_price,
               'amount', bc.amount,
               'pet_name', (
                 select p.name
                 from public.boarding_stay_pets sp
                 join public.pets p on p.id = sp.pet_id
                 where sp.id = bc.stay_pet_id
               )
             ) order by bc.created_at, bc.id) as charges
      from public.boarding_charges bc
      where bc.stay_id = s.id and bc.invoice_line_id is null
    ) c
    where s.branch_id = p_branch
      and s.customer_id = p_customer
      and s.status = 'checked_out'
      and c.charges is not null
  ), '[]'::jsonb);
end;
$$;

revoke execute on function public.billable_boarding_charges(uuid, uuid) from public, anon;
grant execute on function public.billable_boarding_charges(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';
