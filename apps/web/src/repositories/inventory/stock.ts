import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { pageRange, unwrap, type Page, type PageParams } from "../shared";
import { num } from "./helpers";

type Client = SupabaseClient<Database>;

// --------------------------------------------------------------------- stock
export const STOCK_STATUSES = ["all", "low", "out", "expiring", "expired"] as const;
export type StockStatus = (typeof STOCK_STATUSES)[number];
export type StockAlertStatus = Exclude<StockStatus, "all">;

/** Days ahead that count as "expiring soon". */
export const EXPIRY_WINDOWS = [30, 60, 90] as const;

export type StockRow = {
  productId: string;
  name: string;
  sku: string | null;
  barcode: string | null;
  unit: string;
  isActive: boolean;
  onHand: number;
  /** Unexpired stock: what a sale can take. */
  sellable: number;
  expired: number;
  expiring: number;
  nextExpiry: string | null;
  stockValue: number;
  minQty: number | null;
};

export type StockFilter = {
  branchId: string;
  search?: string;
  status?: StockStatus;
  expiryDays?: number;
};

export type StockAlertCounts = Record<StockAlertStatus, number>;

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
  return {
    rows: rows.map((row) => ({
      productId: row.product_id,
      name: row.name,
      sku: row.sku,
      barcode: row.barcode,
      unit: row.unit,
      isActive: row.is_active,
      onHand: num(row.on_hand),
      sellable: num(row.sellable),
      expired: num(row.expired),
      expiring: num(row.expiring),
      nextExpiry: row.next_expiry,
      stockValue: num(row.stock_value),
      minQty: row.min_qty === null ? null : num(row.min_qty),
    })),
    total: rows.length ? num(rows[0].total_count) : 0,
  };
};

export const getStockAlertCounts = async (
  client: Client,
  branchId: string,
  expiryDays: number
): Promise<StockAlertCounts> => {
  const raw = (unwrap(await client.rpc("stock_alert_counts", { p_branch: branchId, p_expiry_days: expiryDays })) ??
    {}) as Record<string, unknown>;
  return { low: num(raw.low), out: num(raw.out), expiring: num(raw.expiring), expired: num(raw.expired) };
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
