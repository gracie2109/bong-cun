// Pet services. The species a service is offered for come from a join table and are rebuilt on read.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { toSpecies, type Species, type SpeciesRow } from "./species";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;
type PetServiceRow = Tables<"pet_services">;
type WithSpecies = PetServiceRow & { service_species: { species: SpeciesRow | null }[] };

export type PetService = {
  id: string;
  name: string;
  desc: string | null;
  type: string | null;
  unit: string | null;
  generalPrice: number | null;
  /** Single-element array: the admin form binds it to a Slider. Minutes. */
  duration: number[];
  isShow: boolean;
  isActive: boolean;
  speciesIds: string[];
  species: Species[];
  createdAt: string;
  updatedAt: string;
};

export type PetServiceInput = {
  name: string;
  desc?: string | null;
  type?: string | null;
  unit?: string | null;
  generalPrice?: number | string | null;
  duration?: number[] | null;
  isShow?: boolean;
  isActive?: boolean;
  speciesIds?: string[] | null;
};

const SELECT_WITH_SPECIES = "*, service_species(species(*))";

export const toPetService = (row: WithSpecies): PetService => {
  const species = row.service_species.flatMap((link) =>
    link.species ? [toSpecies(link.species)] : []
  );
  return {
    id: row.id,
    name: row.name,
    desc: row.description,
    type: row.type,
    unit: row.unit,
    generalPrice: row.general_price,
    duration: [row.duration_minutes ?? 0],
    isShow: row.is_show,
    isActive: row.is_active,
    speciesIds: species.map((item) => item.id),
    species,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
};

const toRpcPayload = (input: PetServiceInput) => ({
  name: input.name,
  description: input.desc ?? null,
  type: input.type ?? null,
  unit: input.unit ?? null,
  general_price: input.generalPrice ?? null,
  duration_minutes: input.duration?.[0] ?? null,
  is_show: input.isShow ?? true,
  is_active: input.isActive ?? true,
  species_ids: input.speciesIds ?? [],
});

export type PetServiceFilter = {
  search?: string;
  speciesId?: string;
  type?: "all" | "by_weight";
  /** Archived services are hidden unless this is true. */
  includeArchived?: boolean;
};

export const listPetServices = async (
  client: Client,
  page: PageParams,
  filter: PetServiceFilter = {}
): Promise<Page<PetService>> => {
  const { from, to } = pageRange(page);
  // `!inner` makes the species filter drop services that are not offered for that species.
  const select = filter.speciesId ? "*, service_species!inner(species(*))" : SELECT_WITH_SPECIES;
  let query = client
    .from("pet_services")
    .select(select, { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);

  if (!filter.includeArchived) query = query.eq("is_active", true);
  if (filter.type) query = query.eq("type", filter.type);
  if (filter.speciesId) query = query.eq("service_species.species_id", filter.speciesId);
  const term = filterSafe(filter.search ?? "");
  if (term) query = query.ilike("name", `%${term}%`);

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data as WithSpecies[]).map(toPetService), total: count ?? 0 };
};

export const listAllPetServices = async (
  client: Client,
  options: { includeArchived?: boolean } = {}
): Promise<PetService[]> => {
  let query = client
    .from("pet_services")
    .select(SELECT_WITH_SPECIES)
    .order("created_at", { ascending: false });
  if (!options.includeArchived) query = query.eq("is_active", true);
  const rows = unwrap(await query);
  return (rows as WithSpecies[]).map(toPetService);
};

export const getPetService = async (client: Client, id: string): Promise<PetService | null> => {
  const row = unwrap(
    await client.from("pet_services").select(SELECT_WITH_SPECIES).eq("id", id).maybeSingle()
  );
  return row ? toPetService(row as WithSpecies) : null;
};

/** Services offered for at least one of the given species (replaces array-contains-any). */
export const listServicesOfSpecies = async (
  client: Client,
  speciesIds: string[]
): Promise<PetService[]> => {
  if (speciesIds.length === 0) return [];
  const rows = unwrap(
    await client
      .from("pet_services")
      .select("*, service_species!inner(species(*))")
      .eq("is_active", true)
      .in("service_species.species_id", speciesIds)
      .order("created_at", { ascending: false })
  );
  return (rows as WithSpecies[]).map(toPetService);
};

export const createPetService = async (client: Client, input: PetServiceInput): Promise<string> =>
  unwrap(await client.rpc("save_pet_service", { p: toRpcPayload(input) }));

export const updatePetService = async (
  client: Client,
  id: string,
  input: PetServiceInput
): Promise<string> =>
  unwrap(await client.rpc("save_pet_service", { p: toRpcPayload(input), p_id: id }));

/** Services are archived, not deleted: orders and combos keep pointing at them. */
export const setPetServiceActive = async (
  client: Client,
  id: string,
  isActive: boolean
): Promise<void> => {
  const { error } = await client.from("pet_services").update({ is_active: isActive }).eq("id", id);
  if (error) throw error;
};

export const updateGeneralPrice = async (
  client: Client,
  id: string,
  generalPrice: number | null
): Promise<void> => {
  const { error } = await client
    .from("pet_services")
    .update({ general_price: generalPrice })
    .eq("id", id);
  if (error) throw error;
};
