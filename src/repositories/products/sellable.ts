// Shop products sold at the counter. Stock by lot and expiry lives in repositories/inventory.ts.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "../shared";
import { toProduct } from "./mappers";
import type { SellableProduct } from "./types";

type Client = SupabaseClient<Database>;

/** Name, SKU or barcode contains the typed text. */
const searchCondition = (text: string): string | null => {
  const term = filterSafe(text);
  return term ? [`name.ilike.%${term}%`, `sku.ilike.%${term}%`, `barcode.ilike.%${term}%`].join(",") : null;
};

/** Active products a page at a time, for pickers that load more as they scroll. */
export const listSellableProducts = async (
  client: Client,
  page: PageParams,
  search = ""
): Promise<Page<SellableProduct>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("products")
    .select("*, product_groups(name)", { count: "exact" })
    .eq("is_active", true)
    .order("name")
    .range(from, to);
  const condition = searchCondition(search);
  if (condition) query = query.or(condition);
  const { data, count, error } = await query;
  if (error) throw error;
  const rows = (data ?? []).map((row) => ({ ...toProduct(row), groupName: row.product_groups?.name ?? row.name }));
  return { rows, total: count ?? 0 };
};

/**
 * Active products for the POS picker; an exact barcode or SKU comes first. `categoryIds` keeps
 * only products whose group is in one of those categories.
 */
export const searchSellableProducts = async (
  client: Client,
  text: string,
  limit = 60,
  categoryIds: readonly string[] = []
): Promise<SellableProduct[]> => {
  let query = client
    .from("products")
    .select("*, product_groups!inner(name, category_id)")
    .eq("is_active", true)
    .order("name")
    .limit(limit);
  if (categoryIds.length > 0) query = query.in("product_groups.category_id", [...categoryIds]);
  const condition = searchCondition(text);
  if (condition) query = query.or(condition);
  const rows = unwrap(await query).map((row) => ({
    ...toProduct(row),
    groupName: row.product_groups?.name ?? row.name,
  }));
  const code = text.trim();
  return [...rows].sort(
    (a, b) => Number(b.barcode === code || b.sku === code) - Number(a.barcode === code || a.sku === code)
  );
};
