import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { unwrap } from "@bongcun/supabase/shared";
import { toMovement, type MovementRow } from "./mappers";
import type { StockMovement } from "./types";

type Client = SupabaseClient<Database>;

// ----------------------------------------------------------------- movements
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
  return rows.map(toMovement);
};
