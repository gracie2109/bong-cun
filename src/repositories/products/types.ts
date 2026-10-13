// Shapes of the product catalog as the screens use them. Reading and writing is in the
// other files of this folder; "@/repositories/products" re-exports everything.

export type Product = {
  id: string;
  name: string;
  desc: string | null;
  sku: string | null;
  barcode: string | null;
  unit: string;
  price: number;
  isActive: boolean;
  /** Sold out of stock lots (FEFO). Off for items sold without stock, such as a carry bag. */
  trackStock: boolean;
  /** The product group this variant belongs to; a plain product is a group of one. */
  groupId: string;
  imageUrl: string | null;
};

export type SellableProduct = Product & { groupName: string };

export type ProductFilter = {
  search?: string;
  includeArchived?: boolean;
  /** A category id; a top-level category also matches its sub-categories. */
  categoryId?: string;
  brandId?: string;
};

// A product group is what the customer sees; each variant is one products row (one SKU).
// Groups vary by any number of shared attributes (Kích cỡ, Vị, Màu...).

export type ProductAttribute = { id: string; name: string; values: string[] };

export type ProductVariant = {
  id: string;
  /** "<group> · <value> / <value>", the name printed on invoices and stock screens. */
  name: string;
  /** One value per attribute of the group, in the group's attribute order. */
  options: string[];
  sku: string | null;
  barcode: string | null;
  unit: string;
  price: number;
  trackStock: boolean;
  isActive: boolean;
  imageUrl: string | null;
};

/** One picture of a group's gallery; `storagePath` is empty for a link to an image kept elsewhere. */
export type ProductImage = { id: string; url: string; storagePath: string | null };

/** A group shows at most this many pictures; the first is the cover. */
export const MAX_GROUP_IMAGES = 8;

export type ProductGroup = {
  id: string;
  name: string;
  desc: string | null;
  imageUrl: string | null;
  isActive: boolean;
  categoryId: string | null;
  categoryName: string | null;
  /** Name of the top-level category when the group's category is a sub-category. */
  categoryParentName: string | null;
  brandId: string | null;
  brandName: string | null;
  /** The gallery in order, cover first. */
  images: ProductImage[];
  minPrice: number | null;
  maxPrice: number | null;
  attributes: ProductAttribute[];
  variants: ProductVariant[];
};

export type ProductVariantInput = {
  id?: string;
  options: string[];
  sku: string;
  barcode: string;
  unit: string;
  price: number;
  trackStock: boolean;
  isActive: boolean;
  imageUrl: string;
};

export type ProductGroupInput = {
  id?: string;
  name: string;
  desc: string;
  imageUrl: string;
  isActive: boolean;
  categoryId: string | null;
  brandId: string | null;
  /** The whole gallery in order; the first becomes the cover and a variant may only pick from it. */
  images: { url: string; storagePath: string | null }[];
  attributes: { name: string; values: string[] }[];
  variants: ProductVariantInput[];
};
