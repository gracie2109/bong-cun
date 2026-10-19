// Server-side cache for the anonymous /api/public reads (seconds). Prices and stock are always re-checked
// by the database functions when an order or booking is made, so a cached read is only a display value.
const REFERENCE_SECONDS = 300;
const LISTING_SECONDS = 60;

const cached = (maxAge: number) => ({ cache: { maxAge, swr: true } });

export const publicApiCacheRules = {
  "/api/public/branches": cached(REFERENCE_SECONDS),
  "/api/public/categories": cached(REFERENCE_SECONDS),
  "/api/public/brands": cached(REFERENCE_SECONDS),
  "/api/public/shop-settings": cached(LISTING_SECONDS),
  "/api/public/spa-catalog": cached(LISTING_SECONDS),
  "/api/public/boarding-catalog": cached(LISTING_SECONDS),
  "/api/public/products": cached(LISTING_SECONDS),
  "/api/public/products/*/related": cached(LISTING_SECONDS),
};
