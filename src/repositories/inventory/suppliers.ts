import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { filterSafe, pageRange, type Page, type PageParams } from "../shared";

type Client = SupabaseClient<Database>;

// ----------------------------------------------------------------- suppliers
export type Supplier = {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  address: string | null;
  taxCode: string | null;
  note: string | null;
  isActive: boolean;
};

export type SupplierInput = Omit<Supplier, "id" | "isActive"> & { isActive?: boolean };

const toSupplier = (row: Tables<"suppliers">): Supplier => ({
  id: row.id,
  name: row.name,
  phone: row.phone,
  email: row.email,
  address: row.address,
  taxCode: row.tax_code,
  note: row.note,
  isActive: row.is_active,
});

const blankToNull = (value: string | null | undefined): string | null => value?.trim() || null;

const toSupplierRow = (input: SupplierInput) => ({
  name: input.name.trim(),
  phone: blankToNull(input.phone),
  email: blankToNull(input.email),
  address: blankToNull(input.address),
  tax_code: blankToNull(input.taxCode),
  note: blankToNull(input.note),
  is_active: input.isActive ?? true,
});

export type SupplierFilter = { search?: string; includeArchived?: boolean };

export const listSuppliers = async (
  client: Client,
  page: PageParams,
  filter: SupplierFilter = {}
): Promise<Page<Supplier>> => {
  const { from, to } = pageRange(page);
  let query = client.from("suppliers").select("*", { count: "exact" }).order("name").range(from, to);
  if (!filter.includeArchived) query = query.eq("is_active", true);
  const term = filterSafe(filter.search ?? "");
  if (term) query = query.or([`name.ilike.%${term}%`, `phone.ilike.%${term}%`, `tax_code.ilike.%${term}%`].join(","));
  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data ?? []).map(toSupplier), total: count ?? 0 };
};

/** Active suppliers for the receipt picker, a page at a time and searchable by name or phone. */
export const listSupplierOptions = async (
  client: Client,
  page: PageParams,
  search = ""
): Promise<Page<Supplier>> => listSuppliers(client, page, { search });

export const createSupplier = async (client: Client, input: SupplierInput): Promise<void> => {
  const { error } = await client.from("suppliers").insert(toSupplierRow(input));
  if (error) throw error;
};

export const updateSupplier = async (client: Client, id: string, input: SupplierInput): Promise<void> => {
  const { error } = await client.from("suppliers").update(toSupplierRow(input)).eq("id", id);
  if (error) throw error;
};
