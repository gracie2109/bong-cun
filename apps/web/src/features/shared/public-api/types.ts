import type { BoardingWebCatalog } from "@bongcun/core/boarding";
import type { CatalogFilters, ShopGroup, ShopPublicSettings } from "@bongcun/core/shop";
import type { ProductGroup } from "@bongcun/core/products";
import type { SpaCatalog } from "@bongcun/core/spa";
import type { Branch } from "@bongcun/supabase/users";
import type { ProductBrand, ProductCategory } from "@bongcun/supabase/products";
import type { Page, PageParams } from "@bongcun/supabase/shared";

/** The spa price list and the branch it is for (the server picks the first one when none is asked for). */
export type SpaCatalogPage = { branchId: string | null; catalog: SpaCatalog };

/** A product group and how many of each variant can be bought now, keyed by variant id. */
export type ProductPage = { group: ProductGroup | null; stock: Record<string, number> };

/** GET /api/public/<path> with an optional query string. */
export type PublicGet = <T>(path: string, query?: Record<string, string | number | boolean | undefined>) => Promise<T>;

/** What the public site reads through its own server instead of calling the database from the browser. */
export type PublicApi = {
  branches: () => Promise<Branch[]>;
  categories: (page: PageParams, rootsOnly?: boolean) => Promise<Page<ProductCategory>>;
  brands: (page: PageParams) => Promise<Page<ProductBrand>>;
  products: (page: PageParams, filters: Partial<CatalogFilters>) => Promise<Page<ShopGroup>>;
  product: (id: string) => Promise<ProductPage>;
  related: (id: string) => Promise<ShopGroup[]>;
  spaCatalog: (branchId: string | null) => Promise<SpaCatalogPage>;
  boardingCatalog: () => Promise<BoardingWebCatalog>;
  shopSettings: () => Promise<ShopPublicSettings>;
};
