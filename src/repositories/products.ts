// Shop products sold at the counter. Stock by lot and expiry comes with the inventory module.
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
};

export type ProductInput = {
  name: string;
  desc?: string | null;
  sku?: string | null;
  barcode?: string | null;
  unit: string;
  price: number;
  isActive?: boolean;
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
});

const blankToNull = (value: string | null | undefined): string | null => value?.trim() || null;

const toRow = (input: ProductInput) => ({
  name: input.name.trim(),
  description: blankToNull(input.desc),
  sku: blankToNull(input.sku),
  barcode: blankToNull(input.barcode),
  unit: input.unit.trim(),
  price: input.price,
  is_active: input.isActive ?? true,
});

/** Name, SKU or barcode contains the typed text. */
const searchCondition = (text: string): string | null => {
  const term = filterSafe(text);
  return term ? [`name.ilike.%${term}%`, `sku.ilike.%${term}%`, `barcode.ilike.%${term}%`].join(",") : null;
};

export const listProducts = async (
  client: Client,
  page: PageParams,
  filter: ProductFilter = {}
): Promise<Page<Product>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("products")
    .select("*", { count: "exact" })
    .order("name")
    .range(from, to);
  if (!filter.includeArchived) query = query.eq("is_active", true);
  const condition = searchCondition(filter.search ?? "");
  if (condition) query = query.or(condition);

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data ?? []).map(toProduct), total: count ?? 0 };
};

/** Active products for the POS picker; an exact barcode or SKU comes first. */
export const searchSellableProducts = async (
  client: Client,
  text: string,
  limit = 24
): Promise<Product[]> => {
  let query = client.from("products").select("*").eq("is_active", true).order("name").limit(limit);
  const condition = searchCondition(text);
  if (condition) query = query.or(condition);
  const rows = unwrap(await query).map(toProduct);
  const code = text.trim();
  return [...rows].sort(
    (a, b) => Number(b.barcode === code || b.sku === code) - Number(a.barcode === code || a.sku === code)
  );
};

export const createProduct = async (client: Client, input: ProductInput): Promise<void> => {
  const { error } = await client.from("products").insert(toRow(input));
  if (error) throw error;
};

export const updateProduct = async (client: Client, id: string, input: ProductInput): Promise<void> => {
  const { error } = await client.from("products").update(toRow(input)).eq("id", id);
  if (error) throw error;
};

/** Products are archived, not deleted: invoice lines keep pointing at them. */
export const setProductActive = async (client: Client, id: string, isActive: boolean): Promise<void> => {
  const { error } = await client.from("products").update({ is_active: isActive }).eq("id", id);
  if (error) throw error;
};
