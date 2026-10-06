// Pet services. The Firestore documents embedded `petIds` and a full copy of each
// pet (`petsProfiles`); here they come from a join table and are rebuilt on read.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { toPet, type Pet, type PetRow } from "./pets";
import { pageRange, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;
type PetServiceRow = Tables<"pet_services">;
type WithPets = PetServiceRow & { pet_service_pets: { pets: PetRow | null }[] };

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
  petIds: string[];
  petsProfiles: Pet[];
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
  petIds?: string[] | null;
};

const SELECT_WITH_PETS = "*, pet_service_pets(pets(*))";

export const toPetService = (row: WithPets): PetService => {
  const pets = row.pet_service_pets.flatMap((link) => (link.pets ? [toPet(link.pets)] : []));
  return {
    id: row.id,
    name: row.name,
    desc: row.description,
    type: row.type,
    unit: row.unit,
    generalPrice: row.general_price,
    duration: [row.duration_minutes ?? 0],
    isShow: row.is_show,
    petIds: pets.map((pet) => pet.id),
    petsProfiles: pets,
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
  pet_ids: input.petIds ?? [],
});

export const listPetServices = async (
  client: Client,
  page: PageParams
): Promise<Page<PetService>> => {
  const { from, to } = pageRange(page);
  const { data, count, error } = await client
    .from("pet_services")
    .select(SELECT_WITH_PETS, { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);
  if (error) throw error;
  return { rows: (data as WithPets[]).map(toPetService), total: count ?? 0 };
};

export const listAllPetServices = async (client: Client): Promise<PetService[]> => {
  const rows = unwrap(
    await client
      .from("pet_services")
      .select(SELECT_WITH_PETS)
      .order("created_at", { ascending: false })
  );
  return (rows as WithPets[]).map(toPetService);
};

export const getPetService = async (client: Client, id: string): Promise<PetService | null> => {
  const row = unwrap(
    await client.from("pet_services").select(SELECT_WITH_PETS).eq("id", id).maybeSingle()
  );
  return row ? toPetService(row as WithPets) : null;
};

/** Services offered for at least one of the given pets (replaces array-contains-any). */
export const listServicesOfPets = async (
  client: Client,
  petIds: string[]
): Promise<PetService[]> => {
  if (petIds.length === 0) return [];
  const rows = unwrap(
    await client
      .from("pet_services")
      .select("*, pet_service_pets!inner(pets(*))")
      .in("pet_service_pets.pet_id", petIds)
      .order("created_at", { ascending: false })
  );
  return (rows as WithPets[]).map(toPetService);
};

export const createPetService = async (client: Client, input: PetServiceInput): Promise<string> =>
  unwrap(await client.rpc("save_pet_service", { p: toRpcPayload(input) }));

export const updatePetService = async (
  client: Client,
  id: string,
  input: PetServiceInput
): Promise<string> =>
  unwrap(await client.rpc("save_pet_service", { p: toRpcPayload(input), p_id: id }));

export const deletePetService = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.from("pet_services").delete().eq("id", id);
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
