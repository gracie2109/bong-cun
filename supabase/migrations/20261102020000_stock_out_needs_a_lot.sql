-- "Out of stock" means a product that had stock here and sold or lost all of it. A product that never
-- received a lot (a new catalogue entry, a service-like item) is not out of stock, it was never in.
-- The count on the dashboard and the "out" filter on the stock screen share this definition.

CREATE OR REPLACE FUNCTION "public"."stock_alert_counts"("p_branch" "uuid", "p_expiry_days" integer DEFAULT 60) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_result jsonb;
begin
  if not public.can_inventory('VIEW', p_branch) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'low',      count(*) filter (where s.min_qty is not null and s.sellable < s.min_qty),
    'out',      count(*) filter (where (s.sellable = 0 and exists (select 1 from public.stock_lots sl where sl.branch_id = p_branch and sl.product_id = s.product_id))),
    'expiring', count(*) filter (where s.expiring > 0),
    'expired',  count(*) filter (where s.expired > 0)
  ) into v_result
  from public.stock_rows(p_branch, p_expiry_days) s;
  return v_result;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."stock_summary"("p_branch" "uuid", "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT 'all'::"text", "p_expiry_days" integer DEFAULT 60, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS TABLE("product_id" "uuid", "name" "text", "sku" "text", "barcode" "text", "unit" "text", "is_active" boolean, "on_hand" numeric, "sellable" numeric, "expired" numeric, "expiring" numeric, "next_expiry" "date", "stock_value" numeric, "min_qty" numeric, "total_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
declare
  v_term text := nullif(btrim(coalesce(p_search, '')), '');
begin
  if not public.can_inventory('VIEW', p_branch) then
    raise exception 'not allowed to see stock at this branch' using errcode = '42501';
  end if;

  return query
  select s.*, count(*) over ()
  from public.stock_rows(p_branch, p_expiry_days) s
  where (v_term is null
         or s.name ilike '%' || v_term || '%'
         or s.sku ilike '%' || v_term || '%'
         or s.barcode = v_term)
    and case coalesce(p_status, 'all')
          when 'low' then s.min_qty is not null and s.sellable < s.min_qty
          when 'out' then (s.sellable = 0 and exists (select 1 from public.stock_lots sl where sl.branch_id = p_branch and sl.product_id = s.product_id))
          when 'expiring' then s.expiring > 0
          when 'expired' then s.expired > 0
          else true
        end
  order by s.name
  limit greatest(coalesce(p_limit, 20), 1) offset greatest(coalesce(p_offset, 0), 0);
end;
$$;
