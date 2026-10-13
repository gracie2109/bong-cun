-- Product module, step 4 (7/9): returns of a unit-sold line put back base units (docs/module-san-pham.md, 3.4).
-- Copy of the version in 20261009120000_pos_p1_fixes.sql with one change: the goods go back to the
-- lots as qty x the line's unit_factor. What can still be returned stays counted in the unit sold.
-- Re-runnable.

-- ------------------------------------------------------------------- returns
-- Takes goods back on a paid invoice and refunds them from the caller's open shift.
-- p: { invoice_id, reason, refund_method: 'cash' | 'transfer', lines: [{ invoice_line_id, qty }] }
-- Only product lines are returned. Each line is refunded at what the customer paid for it,
-- the invoice discount spread over the lines, in whole dong. The goods go back into the lots they came from.
-- Needs "pos: DELETE", like cancelling an invoice. Returns { id, code, refund_amount }.
create or replace function public.create_sales_return(p jsonb) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid      uuid := (select auth.uid());
  v_invoice  public.invoices;
  v_shift    uuid;
  v_method   text := coalesce(p ->> 'refund_method', 'cash');
  v_reason   text := btrim(coalesce(p ->> 'reason', ''));
  v_id       uuid;
  v_code     text;
  v_line     jsonb;
  v_inv_line public.invoice_lines;
  v_qty      numeric;
  v_returned numeric;
  v_amount   numeric;
  v_refund   numeric := 0;
  v_left     numeric;
  v_take     numeric;
  v_lot      record;
  v_line_refunded    numeric;
  v_invoice_refunded numeric;
begin
  select * into v_invoice from public.invoices where id = nullif(p ->> 'invoice_id', '')::uuid for update;
  if not found then
    raise exception 'invoice not found' using errcode = 'P0002';
  end if;
  if v_uid is null or not public.can_pos('DELETE', v_invoice.branch_id) then
    raise exception 'not allowed to take returns' using errcode = '42501';
  end if;
  if v_invoice.status <> 'paid' then
    raise exception 'invoice is cancelled' using errcode = '22023';
  end if;
  if v_method not in ('cash', 'transfer') then
    raise exception 'unknown refund method %', v_method using errcode = '22023';
  end if;
  if length(v_reason) = 0 then
    raise exception 'a reason is required' using errcode = '22023', hint = 'reason_required';
  end if;
  if jsonb_array_length(coalesce(p -> 'lines', '[]'::jsonb)) = 0 then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  select id into v_shift
  from public.cash_shifts
  where branch_id = v_invoice.branch_id and opened_by = v_uid and status = 'open'
  for share;
  if v_shift is null then
    raise exception 'open a cash shift before refunding' using errcode = 'P0001', hint = 'no_open_shift';
  end if;

  v_code := public.next_doc_code(v_invoice.branch_id, 'TH');
  insert into public.sales_returns (
    code, branch_id, invoice_id, shift_id, refund_method, refund_amount, reason, created_by, created_by_name
  ) values (
    v_code, v_invoice.branch_id, v_invoice.id, v_shift, v_method, 0, v_reason, v_uid,
    public.staff_display_name(v_uid)
  )
  returning id into v_id;

  for v_line in select * from jsonb_array_elements(p -> 'lines') loop
    v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
    if v_qty <= 0 then
      continue;
    end if;

    select * into v_inv_line from public.invoice_lines
    where id = nullif(v_line ->> 'invoice_line_id', '')::uuid and invoice_id = v_invoice.id
    for update;
    if not found then
      raise exception 'the line is not on this invoice' using errcode = 'P0002';
    end if;
    if v_inv_line.item_type <> 'product' then
      raise exception '% is not a product', v_inv_line.name using errcode = '22023', hint = 'return_products_only';
    end if;

    select coalesce(sum(qty), 0) into v_returned
    from public.sales_return_lines where invoice_line_id = v_inv_line.id;
    if v_qty > v_inv_line.qty - v_returned then
      raise exception 'only % of % can still be returned', v_inv_line.qty - v_returned, v_inv_line.name
        using errcode = '22023', hint = 'return_too_much', detail = v_inv_line.name;
    end if;

    -- Whole dong: what the units returned so far (this one included) cost the customer, less
    -- what earlier returns of the line refunded, and never more than is left of the invoice.
    select coalesce(sum(amount), 0) into v_line_refunded
    from public.sales_return_lines where invoice_line_id = v_inv_line.id;
    v_amount := case when v_invoice.subtotal > 0
      then round(v_inv_line.amount * (v_returned + v_qty) / v_inv_line.qty * v_invoice.total / v_invoice.subtotal)
           - v_line_refunded
      else 0 end;
    select coalesce(sum(l.amount), 0) into v_invoice_refunded
    from public.sales_return_lines l
    join public.sales_returns r on r.id = l.return_id
    where r.invoice_id = v_invoice.id;
    v_amount := greatest(0, least(v_amount, v_invoice.total - v_invoice_refunded));
    insert into public.sales_return_lines (return_id, invoice_line_id, product_id, name, qty, amount)
    values (v_id, v_inv_line.id, v_inv_line.product_id, v_inv_line.name, v_qty, v_amount);
    v_refund := v_refund + v_amount;

    -- Back into the lots this line still has out, the latest taken first. A line sold before
    -- the product tracked stock has none and returns nothing to stock.
    v_left := v_qty * v_inv_line.unit_factor;
    for v_lot in
      select lot_id, -sum(qty) as out_qty
      from public.stock_movements
      where invoice_line_id = v_inv_line.id
      group by lot_id
      having sum(qty) < 0
      order by max(created_at) desc, lot_id
    loop
      exit when v_left <= 0;
      v_take := least(v_left, v_lot.out_qty);
      perform public.move_stock(
        v_lot.lot_id, v_take, 'return', p_invoice => v_invoice.id, p_invoice_line => v_inv_line.id, p_return => v_id
      );
      v_left := v_left - v_take;
    end loop;
  end loop;

  if not exists (select 1 from public.sales_return_lines where return_id = v_id) then
    raise exception 'pick at least one item to return' using errcode = '22023';
  end if;

  update public.sales_returns set refund_amount = v_refund where id = v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'refund_amount', v_refund);
end;
$$;

revoke execute on function public.create_sales_return(jsonb) from public, anon;
grant execute on function public.create_sales_return(jsonb) to authenticated;

notify pgrst, 'reload schema';
