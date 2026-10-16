import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";
import { num } from "./helpers";

type Client = SupabaseClient<Database>;

// ----------------------------------------------------------------- movements
export const MOVEMENT_REASONS = [
  "receipt",
  "receipt_cancel",
  "sale",
  "sale_cancel",
  "return",
  "writeoff",
  "count",
] as const;
export type MovementReason = (typeof MOVEMENT_REASONS)[number];

export type StockMovement = {
  id: string;
  createdAt: string;
  reason: MovementReason;
  qty: number;
  balanceAfter: number;
  unitCost: number;
  lotNo: string;
  expiryDate: string | null;
  /** The document, invoice or return code it came from. */
  ref: string | null;
};

type MovementRow = Tables<"stock_movements"> & {
  stock_lots: { lot_no: string; expiry_date: string | null } | null;
  stock_documents: { code: string } | null;
  invoices: { code: string } | null;
  sales_returns: { code: string } | null;
};

/** The stock card of a product at a branch, newest first. */
export const listProductMovements = async (
  client: Client,
  branchId: string,
  productId: string,
  limit = 50
): Promise<StockMovement[]> => {
  const rows = unwrap(
    await client
      .from("stock_movements")
      .select(
        "*, stock_lots(lot_no, expiry_date), stock_documents(code), invoices(code), sales_returns(code)"
      )
      .eq("branch_id", branchId)
      .eq("product_id", productId)
      .order("created_at", { ascending: false })
      .limit(limit)
  ) as unknown as MovementRow[];
  return rows.map((row) => ({
    id: row.id,
    createdAt: row.created_at,
    reason: MOVEMENT_REASONS.find((reason) => reason === row.reason) ?? "count",
    qty: num(row.qty),
    balanceAfter: num(row.balance_after),
    unitCost: num(row.unit_cost),
    lotNo: row.stock_lots?.lot_no ?? "",
    expiryDate: row.stock_lots?.expiry_date ?? null,
    ref: row.sales_returns?.code ?? row.stock_documents?.code ?? row.invoices?.code ?? null,
  }));
};
