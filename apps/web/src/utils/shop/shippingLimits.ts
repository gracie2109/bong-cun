// Shipping limits used by both the checkout screens and the GHN server route. No imports, so the
// Nitro server can load this file too. place_shop_order enforces the same fee cap in SQL.

/** The shop delivers nothing heavier than this; heavier orders can only be collected in store. */
export const MAX_DELIVERY_G = 30_000;
/** The estimated fee is kept inside this range when an order is placed. */
export const MAX_QUOTE_FEE = 500_000;
