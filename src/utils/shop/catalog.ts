import { CATALOG_SORTS, type CatalogFilters, type CatalogSort, type CategoryNode, type ShopGroup } from "@/types/catalog";
import type { ProductCategory } from "@/repositories/productCategories";
import { formatPrice } from "@/lib/utils";

export const DEFAULT_SORT: CatalogSort = "newest";

const queryText = (value: unknown): string => (Array.isArray(value) ? String(value[0] ?? "") : String(value ?? ""));

/** Reads the filters out of the page's URL query; unknown sorts fall back to the default. */
export const filtersFromQuery = (query: Record<string, unknown>): CatalogFilters => {
  const sort = queryText(query.sort);
  return {
    search: queryText(query.q).trim(),
    categoryId: queryText(query.category) || null,
    brandId: queryText(query.brand) || null,
    sort: CATALOG_SORTS.find((item) => item === sort) ?? DEFAULT_SORT,
  };
};

/** The URL query for the filters; empty and default values are left out so links stay short. */
export const filtersToQuery = (filters: CatalogFilters): Record<string, string> => {
  const query: Record<string, string> = {};
  if (filters.search) query.q = filters.search;
  if (filters.categoryId) query.category = filters.categoryId;
  if (filters.brandId) query.brand = filters.brandId;
  if (filters.sort !== DEFAULT_SORT) query.sort = filters.sort;
  return query;
};

export const hasActiveFilters = (filters: CatalogFilters): boolean =>
  Boolean(filters.search || filters.categoryId || filters.brandId);

/** Top-level categories with their sub-categories, both in the order the admin set. */
export const buildCategoryTree = (rows: readonly ProductCategory[]): CategoryNode[] => {
  const bySort = (a: ProductCategory, b: ProductCategory) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name);
  return rows
    .filter((row) => !row.parentId)
    .sort(bySort)
    .map((root) => ({
      id: root.id,
      name: root.name,
      children: rows
        .filter((row) => row.parentId === root.id)
        .sort(bySort)
        .map((child) => ({ id: child.id, name: child.name })),
    }));
};

/** The name of a category (or sub-category) by id, for the "filtering by" chips. */
export const categoryName = (tree: readonly CategoryNode[], id: string | null): string | null => {
  if (!id) return null;
  for (const root of tree) {
    if (root.id === id) return root.name;
    const child = root.children.find((item) => item.id === id);
    if (child) return child.name;
  }
  return null;
};

export const groupCover = (group: ShopGroup): string | undefined =>
  group.imageUrl || group.images[0]?.url || group.variants.find((item) => item.imageUrl)?.imageUrl || undefined;

/** "120.000đ" for one price, "Từ 120.000đ" when the variants differ in price. */
export const groupPriceLabel = (group: ShopGroup, fromLabel: string): string => {
  const { minPrice, maxPrice } = group;
  if (minPrice === null) return "";
  const price = formatPrice(minPrice) ?? "";
  return maxPrice !== null && maxPrice > minPrice ? `${fromLabel} ${price}` : price;
};

/** "3 vị · 2 khối lượng": how many values each attribute with a choice has. */
export const groupOptionHint = (group: ShopGroup): string =>
  group.attributes
    .filter((attribute) => attribute.values.length > 1)
    .map((attribute) => `${attribute.values.length} ${attribute.name.toLowerCase()}`)
    .join(" · ");
