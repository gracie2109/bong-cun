// Reading and saving product groups and their variants. One group is a card in the admin list;
// each variant is a products row (one SKU).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { pageRange, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toGroup, type GroupJson } from "./mappers";
import type { ProductAttribute, ProductFilter, ProductGroup, ProductGroupInput } from "@bongcun/core/products";

type Client = SupabaseClient<Database>;

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
    p_category: filter.categoryId || undefined,
    p_brand: filter.brandId || undefined,
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
      category_id: input.categoryId,
      brand_id: input.brandId,
      images: input.images.map((image) => ({ url: image.url, storage_path: image.storagePath })),
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
        weight_g: variant.weightG,
        ship_policy: variant.shipPolicy,
        // Left out (not null) when the caller does not edit units, so the database keeps them.
        units: variant.units?.map((unit) => ({
          id: unit.id ?? null,
          name: unit.name,
          factor: unit.factor,
          barcode: unit.barcode,
          price: unit.price,
          for_sale: unit.forSale,
          for_purchase: unit.forPurchase,
          is_active: unit.isActive,
        })),
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
  "invalid_category",
  "invalid_brand",
  "too_many_images",
  "unit_name_required",
  "duplicate_unit",
  "unit_factor",
  "unit_in_use",
  "invalid_weight",
  "invalid_ship_policy",
] as const;
export type ProductErrorHint = (typeof PRODUCT_ERROR_HINTS)[number];

export const productErrorHint = (error: unknown): ProductErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return PRODUCT_ERROR_HINTS.find((item) => item === hint) ?? null;
};
