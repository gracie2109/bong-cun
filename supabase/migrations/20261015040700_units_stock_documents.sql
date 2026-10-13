-- Product module, step 4 (8/9): receipts in conversion units (docs/module-san-pham.md, 3.4).
-- Copy of the version in 20261007130000_inventory_lots.sql; a receipt line may pick a unit. The
-- document lines keep base-unit qty/unit_cost (so posting is unchanged) plus what was typed.
-- Write-offs and counts stay in base units. Re-runnable.

-- ------------------------------------------------------------ stock documents
-- Creates or replaces a draft document and returns its id.
-- p: {
--   id?, branch_id, doc_type: 'receipt' | 'writeoff' | 'count', supplier_id?, supplier_ref?, note?,
--   lines: [
--     receipt:  { product_id, unit_id?, lot_no?, expiry_date?, qty, unit_cost, note? }
--               qty and unit_cost are per the chosen unit (entered_qty / entered_cost are accepted
--               as aliases); the document keeps them in base units: qty x factor, cost / factor
--     writeoff: { lot_id, qty, note? }
--     count:    { lot_id, counted_qty, note? }
--   ]
-- }
create or replace function public.save_stock_document(p jsonb) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id       uuid := nullif(p ->> 'id', '')::uuid;
  v_doc      public.stock_documents;
  v_branch   uuid;
  v_type     text;
  v_supplier uuid := nullif(p ->> 'supplier_id', '')::uuid;
  v_line     jsonb;
  v_line_no  int := 0;
  v_product  public.products;
  v_lot      public.stock_lots;
  v_qty      numeric;
  v_cost     numeric;
  v_total    numeric := 0;
  v_unit     public.product_units;
  v_factor   numeric;
  v_entered_qty  numeric;
  v_entered_cost numeric;
begin
  if v_id is null then
    v_branch := nullif(p ->> 'branch_id', '')::uuid;
    v_type := p ->> 'doc_type';
    if v_type is null or v_type not in ('receipt', 'writeoff', 'count') then
      raise exception 'unknown document type %', v_type using errcode = '22023';
    end if;
    if (select auth.uid()) is null or v_branch is null or not public.can_inventory('CREATE', v_branch) then
      raise exception 'not allowed to write stock documents at this branch' using errcode = '42501';
    end if;
    insert into public.stock_documents (code, branch_id, doc_type, created_by, created_by_name)
    values (
      public.next_doc_code(v_branch, case v_type when 'receipt' then 'NK' when 'writeoff' then 'XH' else 'KK' end),
      v_branch, v_type, (select auth.uid()), public.staff_display_name((select auth.uid()))
    )
    returning * into v_doc;
  else
    select * into v_doc from public.stock_documents where id = v_id for update;
    if not found then
      raise exception 'document % not found', v_id using errcode = 'P0002';
    end if;
    if not public.can_inventory('CREATE', v_doc.branch_id) then
      raise exception 'not allowed to write stock documents at this branch' using errcode = '42501';
    end if;
    if v_doc.status <> 'draft' then
      raise exception 'only a draft can be edited' using errcode = '22023', hint = 'not_draft';
    end if;
  end if;

  if v_supplier is not null and v_doc.doc_type <> 'receipt' then
    v_supplier := null;
  end if;
  if v_supplier is not null and not exists (select 1 from public.suppliers where id = v_supplier) then
    raise exception 'supplier % not found', v_supplier using errcode = 'P0002';
  end if;

  delete from public.stock_document_lines where document_id = v_doc.id;

  for v_line in select * from jsonb_array_elements(coalesce(p -> 'lines', '[]'::jsonb)) loop
    v_line_no := v_line_no + 1;

    if v_doc.doc_type = 'receipt' then
      select * into v_product from public.products where id = nullif(v_line ->> 'product_id', '')::uuid;
      if not found then
        raise exception 'line %: product not found', v_line_no using errcode = 'P0002';
      end if;
      if not v_product.track_stock then
        raise exception 'line %: % does not track stock', v_line_no, v_product.name
          using errcode = '22023', hint = 'untracked_product', detail = v_product.name;
      end if;
      v_entered_qty := coalesce(nullif(coalesce(v_line ->> 'entered_qty', v_line ->> 'qty'), '')::numeric, 0);
      v_entered_cost := coalesce(nullif(coalesce(v_line ->> 'entered_cost', v_line ->> 'unit_cost'), '')::numeric, 0);
      if v_entered_qty <= 0 or v_entered_cost < 0 then
        raise exception 'line %: quantity must be more than zero and cost zero or more', v_line_no
          using errcode = '22023';
      end if;
      v_unit := null;
      v_factor := 1;
      if nullif(v_line ->> 'unit_id', '') is not null then
        select * into v_unit from public.product_units
        where id = (v_line ->> 'unit_id')::uuid and product_id = v_product.id and is_active;
        if not found then
          raise exception 'line %: the unit is not available', v_line_no using errcode = 'P0002', hint = 'unit_not_available';
        end if;
        v_factor := v_unit.factor;
      end if;
      -- Stock is kept in base units; the line total comes from what was typed so it does not drift.
      v_qty := round(v_entered_qty * v_factor, 2);
      v_cost := round(v_entered_cost / v_factor, 2);
      insert into public.stock_document_lines (
        document_id, line_no, product_id, lot_no, expiry_date, qty, unit_cost, note,
        unit_id, unit_name, unit_factor, entered_qty, entered_cost
      ) values (
        v_doc.id, v_line_no, v_product.id,
        coalesce(btrim(v_line ->> 'lot_no'), ''),
        nullif(v_line ->> 'expiry_date', '')::date,
        v_qty, v_cost, nullif(btrim(v_line ->> 'note'), ''),
        v_unit.id, v_unit.name, v_factor, v_entered_qty, v_entered_cost
      );
      v_total := v_total + round(v_entered_qty * v_entered_cost, 2);
    else
      select * into v_lot from public.stock_lots
      where id = nullif(v_line ->> 'lot_id', '')::uuid and branch_id = v_doc.branch_id;
      if not found then
        raise exception 'line %: lot not found at this branch', v_line_no using errcode = 'P0002';
      end if;
      if exists (
        select 1 from public.stock_document_lines where document_id = v_doc.id and lot_id = v_lot.id
      ) then
        raise exception 'line %: the lot is listed twice', v_line_no using errcode = '22023';
      end if;
      if v_doc.doc_type = 'writeoff' then
        v_qty := coalesce(nullif(v_line ->> 'qty', '')::numeric, 0);
        if v_qty <= 0 then
          raise exception 'line %: quantity must be more than zero', v_line_no using errcode = '22023';
        end if;
        insert into public.stock_document_lines (
          document_id, line_no, product_id, lot_id, lot_no, expiry_date, qty, unit_cost, note
        ) values (
          v_doc.id, v_line_no, v_lot.product_id, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
          v_qty, v_lot.unit_cost, nullif(btrim(v_line ->> 'note'), '')
        );
      else
        v_qty := nullif(v_line ->> 'counted_qty', '')::numeric;
        if v_qty is null or v_qty < 0 then
          raise exception 'line %: counted quantity must be zero or more', v_line_no using errcode = '22023';
        end if;
        insert into public.stock_document_lines (
          document_id, line_no, product_id, lot_id, lot_no, expiry_date, unit_cost, system_qty, counted_qty, note
        ) values (
          v_doc.id, v_line_no, v_lot.product_id, v_lot.id, v_lot.lot_no, v_lot.expiry_date,
          v_lot.unit_cost, v_lot.qty_on_hand, v_qty, nullif(btrim(v_line ->> 'note'), '')
        );
      end if;
    end if;
  end loop;

  update public.stock_documents
  set supplier_id = v_supplier,
      supplier_ref = case when v_doc.doc_type = 'receipt' then nullif(btrim(p ->> 'supplier_ref'), '') end,
      note = nullif(btrim(p ->> 'note'), ''),
      total_cost = v_total
  where id = v_doc.id;

  return v_doc.id;
end;
$$;

revoke execute on function public.save_stock_document(jsonb) from public, anon;
grant execute on function public.save_stock_document(jsonb) to authenticated;

notify pgrst, 'reload schema';
