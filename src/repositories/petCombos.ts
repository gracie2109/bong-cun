// Service combos. The species and services of a combo come from two join tables and are rebuilt on read.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { toSpecies, type Species, type SpeciesRow } from "./species";
import { toPetService, type PetService } from "./petServices";
import { pageRange, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;
type ComboRow = Tables<"pet_service_combos">;
type WithRelations = ComboRow & {
  combo_species: { species: SpeciesRow | null }[];
  combo_services: { pet_services: Tables<"pet_services"> | null }[];
};

export type PetCombo = {
  id: string;
  name: string;
  desc: string | null;
  origin_price: number | null;
  price: number | null;
  /** Single-element array (Slider binding). Minutes. */
  duration: number[];
  markAsId: string | null;
  /** [start, end] ISO strings, or [] when no promotion window is set. */
  markTime: string[];
  status: number;
  isActive: boolean;
  speciesIds: string[];
  species: Species[];
  serviceIds: string[];
  serviceProfiles: PetService[];
  createdAt: string;
  updatedAt: string;
};

export type PetComboInput = {
  name: string;
  desc?: string | null;
  origin_price?: number | string | null;
  price?: number | string | null;
  duration?: number[] | null;
  markAsId?: string | null;
  markTime?: (Date | string | null)[] | null;
  status?: number;
  isActive?: boolean;
  speciesIds?: string[] | null;
  serviceIds?: string[] | null;
};

const SELECT_WITH_RELATIONS = "*, combo_species(species(*)), combo_services(pet_services(*))";

const toIso = (value: Date | string | null | undefined): string | null =>
  value ? new Date(value).toISOString() : null;

export const toPetCombo = (row: WithRelations): PetCombo => {
  const species = row.combo_species.flatMap((link) =>
    link.species ? [toSpecies(link.species)] : []
  );
  const services = row.combo_services.flatMap((link) =>
    link.pet_services ? [toPetService({ ...link.pet_services, service_species: [] })] : []
  );
  return {
    id: row.id,
    name: row.name,
    desc: row.description,
    origin_price: row.origin_price,
    price: row.price,
    duration: [row.duration_minutes ?? 0],
    markAsId: row.mark_as_id,
    markTime: row.mark_start && row.mark_end ? [row.mark_start, row.mark_end] : [],
    status: row.status,
    isActive: row.is_active,
    speciesIds: species.map((item) => item.id),
    species,
    serviceIds: services.map((service) => service.id),
    serviceProfiles: services,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const toRpcPayload = (input: PetComboInput) => ({
  name: input.name,
  description: input.desc ?? null,
  origin_price: input.origin_price ?? null,
  price: input.price ?? null,
  duration_minutes: input.duration?.[0] ?? null,
  mark_as_id: input.markAsId ?? null,
  mark_start: toIso(input.markTime?.[0]),
  mark_end: toIso(input.markTime?.[1]),
  status: input.status ?? 1,
  is_active: input.isActive ?? true,
  species_ids: input.speciesIds ?? [],
  service_ids: input.serviceIds ?? [],
});

export const listPetCombos = async (
  client: Client,
  page: PageParams,
  options: { includeArchived?: boolean } = {}
): Promise<Page<PetCombo>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("pet_service_combos")
    .select(SELECT_WITH_RELATIONS, { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);
  if (!options.includeArchived) query = query.eq("is_active", true);
  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data as WithRelations[]).map(toPetCombo), total: count ?? 0 };
};

/** Combos by id, used to expand the lines of an order. */
export const listPetCombosByIds = async (client: Client, ids: string[]): Promise<PetCombo[]> => {
  if (ids.length === 0) return [];
  const { data, error } = await client
    .from("pet_service_combos")
    .select(SELECT_WITH_RELATIONS)
    .in("id", ids);
  if (error) throw error;
  return (data as WithRelations[]).map(toPetCombo);
};

export const createPetCombo = async (client: Client, input: PetComboInput): Promise<string> => {
  const { data, error } = await client.rpc("save_pet_combo", { p: toRpcPayload(input) });
  if (error) throw error;
  return data;
};

export const updatePetCombo = async (
  client: Client,
  id: string,
  input: PetComboInput
): Promise<string> => {
  const { data, error } = await client.rpc("save_pet_combo", { p: toRpcPayload(input), p_id: id });
  if (error) throw error;
  return data;
};

/** Combos are archived, not deleted: orders keep pointing at them. */
export const setPetComboActive = async (
  client: Client,
  id: string,
  isActive: boolean
): Promise<void> => {
  const { error } = await client
    .from("pet_service_combos")
    .update({ is_active: isActive })
    .eq("id", id);
  if (error) throw error;
};
