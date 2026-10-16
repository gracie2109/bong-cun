import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { pageRange, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { num, toStaffRevenue, toTopItem } from "./parse";
import type { StaffFilter, StaffRevenue, TopItem, TopItemFilter } from "./types";

type Client = SupabaseClient<Database>;

/** Items ranked by revenue, quantity or gross profit. */
export const listTopItems = async (
  client: Client,
  page: PageParams,
  filter: TopItemFilter
): Promise<Page<TopItem>> => {
  const rows = unwrap(
    await client.rpc("report_top_items", {
      p_branch: filter.branchId,
      p_from: filter.from,
      p_to: filter.to,
      p_kind: filter.kind,
      p_search: filter.search?.trim() || undefined,
      p_sort: filter.sort,
      p_limit: page.pageSize,
      p_offset: pageRange(page).from,
    })
  );
  return { rows: rows.map(toTopItem), total: rows.length ? num(rows[0].total_count) : 0 };
};

/** Revenue per cashier or per spa staff member. */
export const listStaffRevenue = async (
  client: Client,
  page: PageParams,
  filter: StaffFilter
): Promise<Page<StaffRevenue>> => {
  const rows = unwrap(
    await client.rpc("report_staff_revenue", {
      p_branch: filter.branchId,
      p_from: filter.from,
      p_to: filter.to,
      p_role: filter.role,
      p_search: filter.search?.trim() || undefined,
      p_limit: page.pageSize,
      p_offset: pageRange(page).from,
    })
  );
  return { rows: rows.map(toStaffRevenue), total: rows.length ? num(rows[0].total_count) : 0 };
};
