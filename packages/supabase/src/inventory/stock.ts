import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { stockAlertCountsSchema } from "@bongcun/core/inventory";
import { pageRange, parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { num } from "./helpers";
import { toStockAlertCounts, toStockRow } from "./mappers";
import type { StockAlertCounts, StockFilter, StockRow } from "./types";

type Client = SupabaseClient<Database>;

export const getStockSummary = async (
  client: Client,
  page: PageParams,
  filter: StockFilter
): Promise<Page<StockRow>> => {
  const { from } = pageRange(page);
  const rows = unwrap(
    await client.rpc("stock_summary", {
      p_branch: filter.branchId,
      p_search: filter.search?.trim() || undefined,
      p_status: filter.status ?? "all",
      p_expiry_days: filter.expiryDays,
      p_limit: page.pageSize,
      p_offset: from,
    })
  );
  return { rows: rows.map(toStockRow), total: rows.length ? num(rows[0].total_count) : 0 };
};

export const getStockAlertCounts = async (
  client: Client,
  branchId: string,
  expiryDays: number
): Promise<StockAlertCounts> => {
  const raw = unwrap(await client.rpc("stock_alert_counts", { p_branch: branchId, p_expiry_days: expiryDays }));
  return toStockAlertCounts(parseRpc("stock_alert_counts", stockAlertCountsSchema, raw));
};

/** Unexpired stock per product at a branch, for the counter. Products that do not track stock are absent. */
export const getSellableStock = async (
  client: Client,
  branchId: string,
  productIds: string[]
): Promise<Record<string, number>> => {
  if (productIds.length === 0) return {};
  const rows = unwrap(await client.rpc("sellable_stock", { p_branch: branchId, p_products: productIds }));
  return Object.fromEntries(rows.map((row) => [row.product_id, num(row.qty)]));
};
