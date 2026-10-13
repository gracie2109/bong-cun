import type { Tables } from "@/types/database.types";
import type { Product, ProductAttribute, ProductGroup } from "./types";

export const toProduct = (row: Tables<"products">): Product => ({
  id: row.id,
  name: row.name,
  desc: row.description,
  sku: row.sku,
  barcode: row.barcode,
  unit: row.unit,
  price: row.price,
  isActive: row.is_active,
  trackStock: row.track_stock,
  groupId: row.group_id,
  imageUrl: row.image_url,
});

/** A group as the product_group_json function returns it. */
export type GroupJson = {
  id: string;
  name: string;
  description: string | null;
  image_url: string | null;
  is_active: boolean;
  category_id: string | null;
  category_name: string | null;
  category_parent_name: string | null;
  brand_id: string | null;
  brand_name: string | null;
  images: { id: string; url: string; storage_path: string | null }[];
  min_price: number | null;
  max_price: number | null;
  attributes: ProductAttribute[];
  variants: {
    id: string;
    name: string;
    options: string[];
    sku: string | null;
    barcode: string | null;
    unit: string;
    price: number;
    track_stock: boolean;
    is_active: boolean;
    image_url: string | null;
  }[];
};

export const toGroup = (row: GroupJson): ProductGroup => ({
  id: row.id,
  name: row.name,
  desc: row.description,
  imageUrl: row.image_url,
  isActive: row.is_active,
  categoryId: row.category_id,
  categoryName: row.category_name,
  categoryParentName: row.category_parent_name,
  brandId: row.brand_id,
  brandName: row.brand_name,
  images: (row.images ?? []).map((image) => ({ id: image.id, url: image.url, storagePath: image.storage_path })),
  minPrice: row.min_price === null ? null : Number(row.min_price),
  maxPrice: row.max_price === null ? null : Number(row.max_price),
  attributes: row.attributes,
  variants: row.variants.map((variant) => ({
    id: variant.id,
    name: variant.name,
    options: variant.options,
    sku: variant.sku,
    barcode: variant.barcode,
    unit: variant.unit,
    price: Number(variant.price),
    trackStock: variant.track_stock,
    isActive: variant.is_active,
    imageUrl: variant.image_url,
  })),
});
