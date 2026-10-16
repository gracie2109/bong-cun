// What the public shop reads about the catalog: one page of sellable groups and related groups.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { CatalogFilters, ShopGroup } from "@/types/catalog";
import { toGroup, type GroupJson } from "../products/mappers";
import { fetchCartLines } from "./cart";
import { pageRange, type Page, type PageParams } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

type ShopGroupJson = GroupJson & { in_stock: boolean };

const toShopGroup = (row: ShopGroupJson): ShopGroup => ({ ...toGroup(row), inStock: row.in_stock });

/** One page of groups the shop can sell. Search matches the name (accents ignored), a SKU or a barcode. */
export const listShopGroups = async (
  client: Client,
  page: PageParams,
  filters: Partial<CatalogFilters> = {}
): Promise<Page<ShopGroup>> => {
  const { from, to } = pageRange(page);
  const { data, error } = await client.rpc("shop_product_groups", {
    p_search: filters.search?.trim() || undefined,
    p_category: filters.categoryId || undefined,
    p_brand: filters.brandId || undefined,
    p_sort: filters.sort ?? "newest",
    p_limit: to - from + 1,
    p_offset: from,
  });
  if (error) throw error;
  const result = data as unknown as { total: number; rows: ShopGroupJson[] };
  return { rows: result.rows.map(toShopGroup), total: Number(result.total) };
};

/** Other groups of the same category, newest first. */
export const listRelatedGroups = async (client: Client, groupId: string, limit = 8): Promise<ShopGroup[]> => {
  const { data, error } = await client.rpc("shop_related_groups", { p_group: groupId, p_limit: limit });
  if (error) throw error;
  return (data as unknown as ShopGroupJson[]).map(toShopGroup);
};

/** How many of each variant (in its base unit) can be bought now, up to 99; asks the cart's stock check. */
export const fetchVariantAvailability = async (
  client: Client,
  productIds: readonly string[]
): Promise<Record<string, number>> => {
  const CART_LINES_LIMIT = 30;
  const chunks: string[][] = [];
  for (let i = 0; i < productIds.length; i += CART_LINES_LIMIT) chunks.push(productIds.slice(i, i + CART_LINES_LIMIT));
  const views = (
    await Promise.all(
      chunks.map((chunk) => fetchCartLines(client, chunk.map((productId) => ({ productId, unitId: null, qty: 1 }))))
    )
  ).flat();
  return Object.fromEntries(views.map((view) => [view.productId, view.isSellable ? view.available : 0]));
};
