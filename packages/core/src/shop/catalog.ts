import type { ProductGroup } from "../products/types";

/** Orders the shop catalog offers; the first is the default. */
export const CATALOG_SORTS = ["newest", "price_asc", "price_desc", "name"] as const;
export type CatalogSort = (typeof CATALOG_SORTS)[number];

/** What the shop list is narrowed by; every field is optional and lives in the URL query. */
export type CatalogFilters = {
  search: string;
  categoryId: string | null;
  brandId: string | null;
  sort: CatalogSort;
};

/** A product group as the shop lists it: only sellable variants, plus whether any can be bought now. */
export type ShopGroup = ProductGroup & { inStock: boolean };

/** A top-level category with its sub-categories, for the filter tree. */
export type CategoryNode = { id: string; name: string; children: { id: string; name: string }[] };

/** One active filter shown as a removable pill above the list. */
export type FilterChip = { key: string; label: string; remove: () => void };
