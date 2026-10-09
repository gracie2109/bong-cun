import { Layers2, Package, Scissors } from "lucide-vue-next";
import type { LineType } from "@/repositories/pos";
import type { ProductVariant, SellableProduct } from "@/repositories/products";

/** One tile; `price` is null for a by-weight service (priced once a pet is picked). */
export type CatalogItem = {
  type: LineType;
  id: string;
  name: string;
  price: number | null;
  unit: string | null;
  hint: string;
  barcode?: string | null;
  sku?: string | null;
  /** Set on a tile that stands for several variants: picking it opens the variant picker. */
  groupId?: string;
  maxPrice?: number;
};

export const CATALOG_TABS = [
  { value: "product", label: "pos.catalog.products", icon: Package },
  { value: "service", label: "pos.catalog.services", icon: Scissors },
  { value: "combo", label: "pos.catalog.combos", icon: Layers2 },
] as const;

export const toProductItem = (product: SellableProduct | ProductVariant): CatalogItem => ({
  type: "product",
  id: product.id,
  name: product.name,
  price: product.price,
  unit: product.unit,
  hint: [product.sku, product.unit].filter(Boolean).join(" · "),
  barcode: product.barcode,
  sku: product.sku,
});

/**
 * Variants of one group found together share one tile; a lone match (a scanned size) shows as itself.
 * `variantCountLabel` words the "n variants" hint of a group tile.
 */
export const groupProductItems = (
  products: readonly SellableProduct[],
  variantCountLabel: (count: number) => string
): CatalogItem[] => {
  const byGroup = new Map<string, SellableProduct[]>();
  for (const product of products) {
    byGroup.set(product.groupId, [...(byGroup.get(product.groupId) ?? []), product]);
  }
  return [...byGroup.values()].map((variants) => {
    const [first] = variants;
    if (variants.length === 1) return toProductItem(first);
    const prices = variants.map((variant) => variant.price);
    return {
      type: "product",
      id: `group:${first.groupId}`,
      groupId: first.groupId,
      name: first.groupName,
      price: Math.min(...prices),
      maxPrice: Math.max(...prices),
      unit: null,
      hint: variantCountLabel(variants.length),
    };
  });
};
