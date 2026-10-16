import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";

type Client = SupabaseClient<Database>;

export const setMinStock = async (
  client: Client,
  branchId: string,
  productId: string,
  minQty: number | null
): Promise<void> => {
  const { error } = await client.rpc("set_min_stock", { p_branch: branchId, p_product: productId, p_min: minQty });
  if (error) throw error;
};
