// Product categories (two levels) and brands. Both are shared by every branch and written
// through functions that check the "products" permission.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { pageRange, type Page, type PageParams } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

export type ProductCategory = {
  id: string;
  parentId: string | null;
  parentName: string | null;
  name: string;
  slug: string;
  imageUrl: string | null;
  sortOrder: number;
  isActive: boolean;
  /** Products in this category; a top-level category also counts its sub-categories. */
  productCount: number;
  childCount: number;
};

export type ProductBrand = {
  id: string;
  name: string;
  slug: string;
  imageUrl: string | null;
  isActive: boolean;
  productCount: number;
};

export type CatalogFilter = {
  search?: string;
  /** Include categories or brands that were switched off. */
  includeInactive?: boolean;
  /** Top-level categories only (the "parent" choice of the category form). */
  rootsOnly?: boolean;
};

export type ProductCategoryInput = {
  id?: string;
  parentId: string | null;
  name: string;
  imageUrl: string;
  isActive: boolean;
};

export type ProductBrandInput = { id?: string; name: string; imageUrl: string; isActive: boolean };

type CategoryJson = {
  id: string;
  parent_id: string | null;
  parent_name: string | null;
  name: string;
  slug: string;
  image_url: string | null;
  sort_order: number;
  is_active: boolean;
  product_count: number;
  child_count: number;
};

type BrandJson = Omit<CategoryJson, "parent_id" | "parent_name" | "sort_order" | "child_count">;

const toCategory = (row: CategoryJson): ProductCategory => ({
  id: row.id,
  parentId: row.parent_id,
  parentName: row.parent_name,
  name: row.name,
  slug: row.slug,
  imageUrl: row.image_url,
  sortOrder: row.sort_order,
  isActive: row.is_active,
  productCount: Number(row.product_count),
  childCount: Number(row.child_count),
});

const toBrand = (row: BrandJson): ProductBrand => ({
  id: row.id,
  name: row.name,
  slug: row.slug,
  imageUrl: row.image_url,
  isActive: row.is_active,
  productCount: Number(row.product_count),
});

/** "Cha › Con" for a sub-category, else its own name. */
export const categoryLabel = (category: Pick<ProductCategory, "name" | "parentName">): string =>
  category.parentName ? `${category.parentName} › ${category.name}` : category.name;

export const listProductCategories = async (
  client: Client,
  page: PageParams,
  filter: CatalogFilter = {}
): Promise<Page<ProductCategory>> => {
  const { from, to } = pageRange(page);
  const { data, error } = await client.rpc("list_product_categories", {
    p_search: filter.search?.trim() || undefined,
    p_include_inactive: filter.includeInactive ?? false,
    p_roots_only: filter.rootsOnly ?? false,
    p_limit: to - from + 1,
    p_offset: from,
  });
  if (error) throw error;
  const result = data as unknown as { total: number; rows: CategoryJson[] };
  return { rows: result.rows.map(toCategory), total: Number(result.total) };
};

/** Creates or updates a category; returns its id. A new category goes last among its siblings. */
export const saveProductCategory = async (client: Client, input: ProductCategoryInput): Promise<string> => {
  const { data, error } = await client.rpc("save_product_category", {
    p: {
      id: input.id ?? null,
      parent_id: input.parentId,
      name: input.name,
      image_url: input.imageUrl,
      is_active: input.isActive,
    },
  });
  if (error) throw error;
  return data;
};

export const moveProductCategory = async (client: Client, id: string, direction: "up" | "down"): Promise<void> => {
  const { error } = await client.rpc("move_product_category", { p_id: id, p_direction: direction });
  if (error) throw error;
};

export const deleteProductCategory = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.rpc("delete_product_category", { p_id: id });
  if (error) throw error;
};

export const listProductBrands = async (
  client: Client,
  page: PageParams,
  filter: CatalogFilter = {}
): Promise<Page<ProductBrand>> => {
  const { from, to } = pageRange(page);
  const { data, error } = await client.rpc("list_product_brands", {
    p_search: filter.search?.trim() || undefined,
    p_include_inactive: filter.includeInactive ?? false,
    p_limit: to - from + 1,
    p_offset: from,
  });
  if (error) throw error;
  const result = data as unknown as { total: number; rows: BrandJson[] };
  return { rows: result.rows.map(toBrand), total: Number(result.total) };
};

export const saveProductBrand = async (client: Client, input: ProductBrandInput): Promise<string> => {
  const { data, error } = await client.rpc("save_product_brand", {
    p: { id: input.id ?? null, name: input.name, image_url: input.imageUrl, is_active: input.isActive },
  });
  if (error) throw error;
  return data;
};

export const deleteProductBrand = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.rpc("delete_product_brand", { p_id: id });
  if (error) throw error;
};

/** Error hints raised by the category and brand functions, for readable messages. */
export const CATALOG_ERROR_HINTS = [
  "duplicate_name",
  "name_required",
  "too_deep",
  "invalid_parent",
  "in_use",
  "has_children",
] as const;
export type CatalogErrorHint = (typeof CATALOG_ERROR_HINTS)[number];

export const catalogErrorHint = (error: unknown): CatalogErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return CATALOG_ERROR_HINTS.find((item) => item === hint) ?? null;
};
