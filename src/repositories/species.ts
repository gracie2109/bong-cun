// Species catalog (Chó, Mèo...). One row per kind of animal; the individual animals are in pets.ts.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { unwrap } from "./shared";

type Client = SupabaseClient<Database>;
export type SpeciesRow = Tables<"species">;

export type Species = {
  id: string;
  name: string;
  icon: string | null;
  desc: string | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
};

/** A species with the counters shown next to it in the catalog list. */
export type SpeciesSummary = Species & { petCount: number; serviceCount: number };

export type SpeciesInput = {
  name: string;
  icon?: string | null;
  desc?: string | null;
  isActive?: boolean;
};

type SpeciesWithCounts = SpeciesRow & {
  pets: { count: number }[];
  service_species: { count: number }[];
};

export const toSpecies = (row: SpeciesRow): Species => ({
  id: row.id,
  name: row.name,
  icon: row.icon,
  desc: row.description,
  isActive: row.is_active,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

const toRpcPayload = (input: SpeciesInput) => ({
  name: input.name,
  icon: input.icon ?? null,
  description: input.desc ?? null,
  is_active: input.isActive ?? true,
});

/** Every species, for dropdowns and selectors. Archived ones only when asked. */
export const listSpecies = async (
  client: Client,
  options: { includeArchived?: boolean } = {}
): Promise<Species[]> => {
  let query = client.from("species").select("*").order("name");
  if (!options.includeArchived) query = query.eq("is_active", true);
  return unwrap(await query).map(toSpecies);
};

/** The catalog page: every species (archived too) with how many pets and services use it. */
export const listSpeciesSummaries = async (client: Client): Promise<SpeciesSummary[]> => {
  const rows = unwrap(
    await client.from("species").select("*, pets(count), service_species(count)").order("name")
  ) as SpeciesWithCounts[];
  return rows.map((row) => ({
    ...toSpecies(row),
    petCount: row.pets[0]?.count ?? 0,
    serviceCount: row.service_species[0]?.count ?? 0,
  }));
};

export const getSpecies = async (client: Client, id: string): Promise<Species | null> => {
  const row = unwrap(await client.from("species").select("*").eq("id", id).maybeSingle());
  return row ? toSpecies(row) : null;
};

export const createSpecies = async (client: Client, input: SpeciesInput): Promise<string> =>
  unwrap(await client.rpc("save_species", { p: toRpcPayload(input) }));

export const updateSpecies = async (
  client: Client,
  id: string,
  input: SpeciesInput
): Promise<string> =>
  unwrap(await client.rpc("save_species", { p: toRpcPayload(input), p_id: id }));

/** Species are archived, not deleted: pets, prices and combos keep pointing at them. */
export const setSpeciesActive = async (
  client: Client,
  id: string,
  isActive: boolean
): Promise<void> => {
  const { error } = await client.from("species").update({ is_active: isActive }).eq("id", id);
  if (error) throw error;
};
