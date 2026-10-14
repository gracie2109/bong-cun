// What the public shop reads about the catalog: one page of sellable groups and related groups.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type { CatalogFilters, ShopGroup } from "@/types/catalog";
import { toGroup, type GroupJson } from "../products/mappers";
import { pageRange, type Page, type PageParams } from "../shared";

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
