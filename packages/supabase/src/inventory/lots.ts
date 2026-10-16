import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";
import { num } from "./helpers";

type Client = SupabaseClient<Database>;

// ---------------------------------------------------------------------- lots
export type StockLot = {
  id: string;
  productId: string;
  lotNo: string;
  expiryDate: string | null;
  unitCost: number;
  qtyOnHand: number;
  receivedAt: string;
};

const toLot = (row: Tables<"stock_lots">): StockLot => ({
  id: row.id,
  productId: row.product_id,
  lotNo: row.lot_no,
  expiryDate: row.expiry_date,
  unitCost: num(row.unit_cost),
  qtyOnHand: num(row.qty_on_hand),
  receivedAt: row.received_at,
});

/** A product's lots at a branch in FEFO order; empty lots only when asked. */
export const listProductLots = async (
  client: Client,
  branchId: string,
  productId: string,
  includeEmpty = false
): Promise<StockLot[]> => {
  let query = client
    .from("stock_lots")
    .select("*")
    .eq("branch_id", branchId)
    .eq("product_id", productId)
    .order("expiry_date", { ascending: true, nullsFirst: false })
    .order("received_at");
  if (!includeEmpty) query = query.gt("qty_on_hand", 0);
  return unwrap(await query).map(toLot);
};

export { businessDate, isExpired } from "@bongcun/core/inventory";
