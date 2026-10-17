// Rows of the stock functions and tables -> domain types. Pure: no client, no Vue.
import type { Database, Tables } from "@bongcun/supabase/db";
import { MOVEMENT_REASONS, type StockAlertCounts, type StockLot, type StockMovement, type StockRow } from "../types";
import { num } from "../helpers";
import type { StockAlertCountsResult } from "@bongcun/core/inventory";

export type StockSummaryRow = Database["public"]["Functions"]["stock_summary"]["Returns"][number];

export const toStockRow = (row: StockSummaryRow): StockRow => ({
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
});

export const toStockAlertCounts = (result: StockAlertCountsResult): StockAlertCounts => result;

export const toLot = (row: Tables<"stock_lots">): StockLot => ({
  id: row.id,
  productId: row.product_id,
  lotNo: row.lot_no,
  expiryDate: row.expiry_date,
  unitCost: num(row.unit_cost),
  qtyOnHand: num(row.qty_on_hand),
  receivedAt: row.received_at,
});

export type MovementRow = Tables<"stock_movements"> & {
  stock_lots: { lot_no: string; expiry_date: string | null } | null;
  stock_documents: { code: string } | null;
  invoices: { code: string } | null;
  sales_returns: { code: string } | null;
};

export const toMovement = (row: MovementRow): StockMovement => ({
  id: row.id,
  createdAt: row.created_at,
  reason: MOVEMENT_REASONS.find((reason) => reason === row.reason) ?? "count",
  qty: num(row.qty),
  balanceAfter: num(row.balance_after),
  unitCost: num(row.unit_cost),
  lotNo: row.stock_lots?.lot_no ?? "",
  expiryDate: row.stock_lots?.expiry_date ?? null,
  ref: row.sales_returns?.code ?? row.stock_documents?.code ?? row.invoices?.code ?? null,
});
