import type { Tables } from "@bongcun/supabase/db";
import type { ShipPolicy } from "@bongcun/core/shop";
import type { Product, ProductAttribute, ProductGroup, ProductUnit } from "@bongcun/core/products";

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

/** A unit as stored in product_units and as product_group_json returns it. */
export type UnitJson = {
  id: string;
  name: string;
  factor: number;
  barcode: string | null;
  price: number | null;
  for_sale: boolean;
  for_purchase: boolean;
  is_active: boolean;
};

export const toUnit = (row: UnitJson): ProductUnit => ({
  id: row.id,
  name: row.name,
  factor: Number(row.factor),
  barcode: row.barcode,
  price: row.price === null ? null : Number(row.price),
  forSale: row.for_sale,
  forPurchase: row.for_purchase,
  isActive: row.is_active,
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
    units?: UnitJson[];
    weight_g?: number | null;
    ship_policy?: ShipPolicy;
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
    units: (variant.units ?? []).map(toUnit),
    weightG: variant.weight_g ?? null,
    shipPolicy: variant.ship_policy ?? "shippable",
  })),
});
