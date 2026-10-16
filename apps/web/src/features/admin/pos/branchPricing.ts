import type { BranchPriceMap } from "@bongcun/supabase/spa";

/** A product whose price may be the branch price; `generalPrice` is kept only when the two differ. */
export type Priced<T> = T & { generalPrice?: number };

/** The product with the price it has at the open branch laid over its general price. */
export const priceAtBranch = <T extends { id: string; price: number }>(
  product: T,
  prices: BranchPriceMap | undefined
): Priced<T> => {
  const own = prices?.[product.id];
  return own === undefined || own === product.price ? product : { ...product, price: own, generalPrice: product.price };
};
