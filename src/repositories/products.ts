// Shop products sold at the counter. Stock by lot and expiry lives in repositories/inventory.ts.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;

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

export type ProductFilter = { search?: string; includeArchived?: boolean };

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

/** Name, SKU or barcode contains the typed text. */
const searchCondition = (text: string): string | null => {
  const term = filterSafe(text);
  return term ? [`name.ilike.%${term}%`, `sku.ilike.%${term}%`, `barcode.ilike.%${term}%`].join(",") : null;
};

export type SellableProduct = Product & { groupName: string };

/** Active products for the POS picker; an exact barcode or SKU comes first. */
export const searchSellableProducts = async (
  client: Client,
  text: string,
  limit = 60
): Promise<SellableProduct[]> => {
  let query = client
    .from("products")
    .select("*, product_groups(name)")
    .eq("is_active", true)
    .order("name")
    .limit(limit);
  const condition = searchCondition(text);
  if (condition) query = query.or(condition);
  const rows = unwrap(await query).map((row) => ({
    ...toProduct(row),
    groupName: row.product_groups?.name ?? row.name,
  }));
  const code = text.trim();
  return [...rows].sort(
    (a, b) => Number(b.barcode === code || b.sku === code) - Number(a.barcode === code || a.sku === code)
  );
};

// ----------------------------------------------------------- groups and variants
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

export type ProductGroup = {
  id: string;
  name: string;
  desc: string | null;
  imageUrl: string | null;
  isActive: boolean;
  minPrice: number | null;
  maxPrice: number | null;
  attributes: ProductAttribute[];
  variants: ProductVariant[];
};

export type ProductGroupInput = {
  id?: string;
  name: string;
  desc: string;
  imageUrl: string;
  isActive: boolean;
  attributes: { name: string; values: string[] }[];
  variants: {
    id?: string;
    options: string[];
    sku: string;
    barcode: string;
    unit: string;
    price: number;
    trackStock: boolean;
    isActive: boolean;
    imageUrl: string;
  }[];
};

type GroupJson = {
  id: string;
  name: string;
  description: string | null;
  image_url: string | null;
  is_active: boolean;
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

const toGroup = (row: GroupJson): ProductGroup => ({
  id: row.id,
  name: row.name,
  desc: row.description,
  imageUrl: row.image_url,
  isActive: row.is_active,
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

/** One page of groups; search matches the name (accents ignored), a SKU or a barcode. */
export const listProductGroups = async (
  client: Client,
  page: PageParams,
  filter: ProductFilter = {}
): Promise<Page<ProductGroup>> => {
  const { from, to } = pageRange(page);
  const { data, error } = await client.rpc("list_product_groups", {
    p_search: filter.search?.trim() || undefined,
    p_include_archived: filter.includeArchived ?? false,
    p_limit: to - from + 1,
    p_offset: from,
  });
  if (error) throw error;
  const result = data as unknown as { total: number; rows: GroupJson[] };
  return { rows: result.rows.map(toGroup), total: result.total };
};

/** A group with all its variants, archived ones included, for the edit form. */
export const getProductGroup = async (client: Client, id: string): Promise<ProductGroup | null> => {
  const { data, error } = await client.rpc("product_group_json", { p_group: id, p_all: true });
  if (error) throw error;
  return data ? toGroup(data as unknown as GroupJson) : null;
};

/** A group with only its sellable variants, for the POS and shop pickers. */
export const getSellableGroup = async (client: Client, id: string): Promise<ProductGroup | null> => {
  const { data, error } = await client.rpc("product_group_json", { p_group: id, p_all: false });
  if (error) throw error;
  return data ? toGroup(data as unknown as GroupJson) : null;
};

/** Every attribute with its known values, to suggest while typing. */
export const listProductAttributes = async (client: Client): Promise<ProductAttribute[]> => {
  const rows = unwrap(
    await client
      .from("product_attributes")
      .select("id, name, product_attribute_values(value, sort_order)")
      .order("name")
  );
  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    values: [...row.product_attribute_values]
      .sort((a, b) => a.sort_order - b.sort_order)
      .map((item) => item.value),
  }));
};

/** Saves the group, its attributes and variants in one transaction; returns the group id. */
export const saveProductGroup = async (client: Client, input: ProductGroupInput): Promise<string> => {
  const { data, error } = await client.rpc("save_product_group", {
    p: {
      id: input.id ?? null,
      name: input.name,
      description: input.desc,
      image_url: input.imageUrl,
      is_active: input.isActive,
      attributes: input.attributes,
      variants: input.variants.map((variant) => ({
        id: variant.id ?? null,
        options: variant.options,
        sku: variant.sku,
        barcode: variant.barcode,
        unit: variant.unit,
        price: variant.price,
        track_stock: variant.trackStock,
        is_active: variant.isActive,
        image_url: variant.imageUrl,
      })),
    },
  });
  if (error) throw error;
  return data;
};

/** Archives or restores a group with all its variants; sold items are never deleted. */
export const setProductGroupActive = async (client: Client, id: string, isActive: boolean): Promise<void> => {
  const { error } = await client.rpc("set_product_group_active", { p_group: id, p_active: isActive });
  if (error) throw error;
};

/** Error hints raised by save_product_group, for readable messages. */
export const PRODUCT_ERROR_HINTS = [
  "duplicate_name",
  "duplicate_sku",
  "duplicate_barcode",
  "duplicate_variant",
  "duplicate_attribute",
  "variant_options",
  "no_variants",
] as const;
export type ProductErrorHint = (typeof PRODUCT_ERROR_HINTS)[number];

export const productErrorHint = (error: unknown): ProductErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return PRODUCT_ERROR_HINTS.find((item) => item === hint) ?? null;
};
