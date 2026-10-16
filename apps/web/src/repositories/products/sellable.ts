// Shop products sold at the counter. Stock by lot and expiry lives in repositories/inventory.ts.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@bongcun/supabase/db";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toProduct, toUnit } from "./mappers";
import type { SellableProduct } from "./types";

type Client = SupabaseClient<Database>;

type UnitRow = Tables<"product_units">;

const sortedUnits = (rows: UnitRow[] | null) =>
  [...(rows ?? [])].sort((a, b) => a.sort_order - b.sort_order || a.factor - b.factor).map(toUnit);

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
    .select("*, product_groups(name), product_units(*)", { count: "exact" })
    .eq("is_active", true)
    .order("name")
    .range(from, to);
  const condition = searchCondition(search);
  if (condition) query = query.or(condition);
  const { data, count, error } = await query;
  if (error) throw error;
  const rows = (data ?? []).map((row) => ({
    ...toProduct(row),
    groupName: row.product_groups?.name ?? row.name,
    units: sortedUnits(row.product_units),
  }));
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
    .select("*, product_groups!inner(name, category_id), product_units(*)")
    .eq("is_active", true)
    .order("name")
    .limit(limit);
  if (categoryIds.length > 0) query = query.in("product_groups.category_id", [...categoryIds]);
  const condition = searchCondition(text);
  if (condition) query = query.or(condition);
  const rows = unwrap(await query).map((row) => ({
    ...toProduct(row),
    groupName: row.product_groups?.name ?? row.name,
    units: sortedUnits(row.product_units),
  }));
  const code = text.trim();
  return [...rows].sort(
    (a, b) => Number(b.barcode === code || b.sku === code) - Number(a.barcode === code || a.sku === code)
  );
};

/** What find_by_barcode answers: the product a code belongs to and the unit when it is a unit's code. */
export type BarcodeHit = { productId: string; unitId: string | null };

/** The sellable product or unit with exactly this barcode, or null. */
export const findByBarcode = async (client: Client, code: string, branchId?: string): Promise<BarcodeHit | null> => {
  const hit = unwrap(await client.rpc("find_by_barcode", { p_code: code, p_branch: branchId })) as {
    product_id: string;
    unit_id: string | null;
  } | null;
  return hit ? { productId: hit.product_id, unitId: hit.unit_id } : null;
};

/** One active product with its conversion units, for the POS once a scan found it. */
export const getSellableProduct = async (client: Client, id: string): Promise<SellableProduct | null> => {
  const { data: row, error } = await client
    .from("products")
    .select("*, product_groups(name), product_units(*)")
    .eq("id", id)
    .eq("is_active", true)
    .maybeSingle();
  if (error) throw error;
  if (!row) return null;
  return { ...toProduct(row), groupName: row.product_groups?.name ?? row.name, units: sortedUnits(row.product_units) };
};
