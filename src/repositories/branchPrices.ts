// Per-branch product prices: a row overrides products.price at one branch.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;

/** Product id -> the price at one branch, only for products that have one. */
export type BranchPriceMap = Record<string, number>;

/** Product id -> branch id -> price, for the product screen's price grid. */
export type ProductBranchPrices = Record<string, Record<string, number>>;

/** `price: null` removes the branch price, so the general price applies again. */
export type BranchPriceChange = { branchId: string; price: number | null };

export const getBranchPrices = async (client: Client, branchId: string, productIds: string[]): Promise<BranchPriceMap> => {
  if (productIds.length === 0) return {};
  const rows = unwrap(await client.rpc("branch_prices", { p_branch: branchId, p_products: productIds }));
  return Object.fromEntries(rows.map((row) => [row.product_id, Number(row.price)]));
};

export const listProductBranchPrices = async (client: Client, productIds: string[]): Promise<ProductBranchPrices> => {
  if (productIds.length === 0) return {};
  const rows = unwrap(await client.from("product_branch_prices").select("product_id, branch_id, price").in("product_id", productIds));
  const prices: ProductBranchPrices = {};
  for (const row of rows) (prices[row.product_id] ??= {})[row.branch_id] = Number(row.price);
  return prices;
};

export const setProductBranchPrices = async (
  client: Client,
  productId: string,
  changes: BranchPriceChange[]
): Promise<void> => {
  const { error } = await client.rpc("set_product_branch_prices", {
    p_product: productId,
    p_prices: changes.map((change) => ({ branch_id: change.branchId, price: change.price })),
  });
  if (error) throw error;
};

const EDIT_METHODS = ["UPDATE", "ALL"];

/** Ids of the branches where the caller holds "products: UPDATE", which lets them set a price there. */
export const listPriceEditableBranchIds = async (client: Client): Promise<string[]> => {
  const rows = unwrap(await client.rpc("my_permissions"));
  return [
    ...new Set(
      rows
        .filter((row) => row.permission === "products" && row.methods.some((method) => EDIT_METHODS.includes(method)))
        .map((row) => row.branch_id)
    ),
  ];
};
