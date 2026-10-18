-- Deletes product groups (with all their variants) that have never been sold or stocked.
-- Returns {"deleted": [group ids], "blocked": [{"id": group id, "reason": "sold" | "stocked"}]}.
create or replace function public.delete_product_groups(p_groups uuid[]) returns jsonb
    language plpgsql security definer
    set search_path to ''
as $$
declare
  v_id uuid;
  v_deleted uuid[] := '{}';
  v_blocked jsonb := '[]'::jsonb;
  v_reason text;
begin
  if not public.can_products('DELETE') then
    raise exception 'not allowed to delete products' using errcode = '42501';
  end if;

  foreach v_id in array coalesce(p_groups, '{}') loop
    v_reason := null;
    if not exists (select 1 from public.product_groups where id = v_id) then
      continue;
    end if;

    if exists (
      select 1 from public.products p
      where p.group_id = v_id and (
        exists (select 1 from public.invoice_lines l where l.product_id = p.id)
        or exists (select 1 from public.sales_return_lines l where l.product_id = p.id)
        or exists (select 1 from public.shop_order_lines l where l.product_id = p.id)
        or exists (select 1 from public.medical_visit_items l where l.product_id = p.id)
        or exists (select 1 from public.inpatient_orders l where l.product_id = p.id)
      )
    ) then
      v_reason := 'sold';
    elsif exists (
      select 1 from public.products p
      where p.group_id = v_id and (
        exists (select 1 from public.stock_lots l where l.product_id = p.id)
        or exists (select 1 from public.stock_movements l where l.product_id = p.id)
        or exists (select 1 from public.stock_document_lines l where l.product_id = p.id)
      )
    ) then
      v_reason := 'stocked';
    end if;

    if v_reason is null then
      begin
        delete from public.products where group_id = v_id;
        delete from public.product_groups where id = v_id;
        v_deleted := v_deleted || v_id;
      exception when foreign_key_violation then
        v_reason := 'stocked';
      end;
    end if;

    if v_reason is not null then
      v_blocked := v_blocked || jsonb_build_object('id', v_id, 'reason', v_reason);
    end if;
  end loop;

  return jsonb_build_object('deleted', to_jsonb(v_deleted), 'blocked', v_blocked);
end;
$$;

revoke execute on function public.delete_product_groups(uuid[]) from public;
grant execute on function public.delete_product_groups(uuid[]) to authenticated;
