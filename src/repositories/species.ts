// Pets. Rows are mapped to the field names the admin screens already use
// (`desc`, `createdAt`) so the forms and table columns do not change.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { pageRange, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;
export type PetRow = Tables<"pets">;

export type Pet = {
  id: string;
  name: string;
  icon: string | null;
  desc: string | null;
  createdAt: string;
  updatedAt: string;
};

export type PetInput = {
  name: string;
  icon?: string | null;
  desc?: string | null;
};

export const toPet = (row: PetRow): Pet => ({
  id: row.id,
  name: row.name,
  icon: row.icon,
  desc: row.description,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

const toColumns = (input: PetInput) => ({
  name: input.name,
  icon: input.icon || null,
  description: input.desc || null,
});

export const listPets = async (client: Client, page: PageParams): Promise<Page<Pet>> => {
  const { from, to } = pageRange(page);
  const { data, count, error } = await client
    .from("pets")
    .select("*", { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);
  if (error) throw error;
  return { rows: (data ?? []).map(toPet), total: count ?? 0 };
};

/** Every pet, for dropdowns and selectors (the old code asked for pages of 500/5000). */
export const listAllPets = async (client: Client): Promise<Pet[]> => {
  const rows = unwrap(
    await client.from("pets").select("*").order("created_at", { ascending: false })
  );
  return rows.map(toPet);
};

export const getPet = async (client: Client, id: string): Promise<Pet | null> => {
  const row = unwrap(await client.from("pets").select("*").eq("id", id).maybeSingle());
  return row ? toPet(row) : null;
};

export const countPets = async (client: Client): Promise<number> => {
  const { count, error } = await client.from("pets").select("id", { count: "exact", head: true });
  if (error) throw error;
  return count ?? 0;
};

export const createPet = async (client: Client, input: PetInput): Promise<Pet> =>
  toPet(unwrap(await client.from("pets").insert(toColumns(input)).select().single()));

export const updatePet = async (client: Client, id: string, input: PetInput): Promise<Pet> =>
  toPet(unwrap(await client.from("pets").update(toColumns(input)).eq("id", id).select().single()));

export const deletePet = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.from("pets").delete().eq("id", id);
  if (error) throw error;
};
