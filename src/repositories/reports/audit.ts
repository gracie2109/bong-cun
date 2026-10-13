import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { pageRange, unwrap, type Page, type PageParams } from "../shared";
import { num, toAdjustment, toShiftRecon } from "./parse";
import type { Adjustment, AdjustmentFilter, ShiftRecon, ShiftReconFilter } from "./types";

type Client = SupabaseClient<Database>;

/** Goods returns and cancelled invoices in the range, newest first. */
export const listAdjustments = async (
  client: Client,
  page: PageParams,
  filter: AdjustmentFilter
): Promise<Page<Adjustment>> => {
  const rows = unwrap(
    await client.rpc("report_adjustments", {
      p_branch: filter.branchId,
      p_from: filter.from,
      p_to: filter.to,
      p_kind: filter.kind,
      p_search: filter.search?.trim() || undefined,
      p_limit: page.pageSize,
      p_offset: pageRange(page).from,
    })
  );
  return { rows: rows.map(toAdjustment), total: rows.length ? num(rows[0].total_count) : 0 };
};

/** Cash shifts opened in the range, expected cash against counted cash. */
export const listShiftRecon = async (
  client: Client,
  page: PageParams,
  filter: ShiftReconFilter
): Promise<Page<ShiftRecon>> => {
  const rows = unwrap(
    await client.rpc("report_shifts", {
      p_branch: filter.branchId,
      p_from: filter.from,
      p_to: filter.to,
      p_status: filter.status,
      p_search: filter.search?.trim() || undefined,
      p_limit: page.pageSize,
      p_offset: pageRange(page).from,
    })
  );
  return { rows: rows.map(toShiftRecon), total: rows.length ? num(rows[0].total_count) : 0 };
};
