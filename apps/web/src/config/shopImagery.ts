/**
 * Photos of the public shop's marketing sections (home hero, shop / spa tiles, store visit).
 * Unsplash photos, linked the way Unsplash asks (hot-linked from its CDN). To use the shop's own
 * photos, put a full image URL in `src` instead; `ShopImage` shows a soft paw tile if one fails to load.
 */
export type ShopPhoto = { src: string; alt: string };

const unsplash = (id: string): string => `https://images.unsplash.com/${id}`;

export const SHOP_PHOTOS = {
  hero: { src: unsplash("photo-1450778869180-41d0601e046e"), alt: "client.home.photos.hero" },
  shop: { src: unsplash("photo-1583337130417-3346a1be7dee"), alt: "client.home.photos.shop" },
  spa: { src: unsplash("photo-1516734212186-a967f81ad0d7"), alt: "client.home.photos.spa" },
  visit: { src: unsplash("photo-1548199973-03cce0bbc87b"), alt: "client.home.photos.visit" },
} satisfies Record<string, ShopPhoto>;

/** An Unsplash URL sized for its slot; other URLs are returned as they are. */
export const sizedPhoto = (src: string, width: number): string =>
  src.startsWith("https://images.unsplash.com/") ? `${src}?auto=format&fit=crop&w=${width}&q=70` : src;
