import type { PublicApi, PublicGet } from "./types";

/** The /api/public routes, typed. Empty filters are left out of the query string. */
export const createPublicApi = (get: PublicGet): PublicApi => ({
  branches: () => get("branches"),
  categories: (page, rootsOnly = false) =>
    get("categories", { page: page.pageIndex, pageSize: page.pageSize, rootsOnly: rootsOnly || undefined }),
  brands: (page) => get("brands", { page: page.pageIndex, pageSize: page.pageSize }),
  products: (page, filters) =>
    get("products", {
      page: page.pageIndex,
      pageSize: page.pageSize,
      search: filters.search?.trim() || undefined,
      category: filters.categoryId || undefined,
      brand: filters.brandId || undefined,
      sort: filters.sort,
    }),
  product: (id) => get(`products/${encodeURIComponent(id)}`),
  related: (id) => get(`products/${encodeURIComponent(id)}/related`),
  spaCatalog: (branchId) => get("spa-catalog", { branch: branchId ?? undefined }),
  boardingCatalog: () => get("boarding-catalog"),
  shopSettings: () => get("shop-settings"),
});
