import { Layers2, Package, Scissors } from "lucide-vue-next";
import type { LineType } from "@/repositories/pos";
import { sellableUnits, type ProductUnit, type ProductVariant, type SellableProduct } from "@bongcun/supabase/products";
import type { Priced } from "./branchPricing";

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
  /** The general price, set when this branch sells the product at another price. */
  generalPrice?: number;
  /** The unit this item is sold in; null or missing for the base unit. `unit` and `price` follow it. */
  unitId?: string | null;
  /** Base units in one sold unit (1 for the base unit). */
  factor?: number;
  /** What the product is sold in without a conversion unit, with its price at this branch. */
  baseUnit?: string;
  basePrice?: number;
  baseGeneralPrice?: number;
  /** The conversion units this product can be sold in; missing when it has none. */
  units?: ProductUnit[];
};

export const CATALOG_TABS = [
  { value: "product", label: "pos.catalog.products", icon: Package },
  { value: "service", label: "pos.catalog.services", icon: Scissors },
  { value: "combo", label: "pos.catalog.combos", icon: Layers2 },
] as const;

export const toProductItem = (product: Priced<SellableProduct | ProductVariant>): CatalogItem => {
  const units = sellableUnits(product.units);
  return {
    type: "product",
    id: product.id,
    name: product.name,
    price: product.price,
    unit: product.unit,
    hint: [product.sku, product.unit].filter(Boolean).join(" · "),
    barcode: product.barcode,
    sku: product.sku,
    generalPrice: product.generalPrice,
    unitId: null,
    factor: 1,
    baseUnit: product.unit,
    basePrice: product.price,
    baseGeneralPrice: product.generalPrice,
    units: units.length ? units : undefined,
  };
};

/**
 * Variants of one group found together share one tile; a lone match (a scanned size) shows as itself.
 * `variantCountLabel` words the "n variants" hint of a group tile.
 */
export const groupProductItems = (
  products: readonly Priced<SellableProduct>[],
  variantCountLabel: (count: number) => string
): CatalogItem[] => {
  const byGroup = new Map<string, Priced<SellableProduct>[]>();
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
