import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";
import { toLot } from "./mappers";
import type { StockLot } from "./types";

type Client = SupabaseClient<Database>;

// ---------------------------------------------------------------------- lots
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
