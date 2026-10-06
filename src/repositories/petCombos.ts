// Service combos. `petIds`/`serviceIds` and their denormalized *Profiles copies
// come from two join tables and are rebuilt on read.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { toPet, type Pet, type PetRow } from "./pets";
import { toPetService, type PetService } from "./petServices";
import { pageRange, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;
type ComboRow = Tables<"pet_service_combos">;
type WithRelations = ComboRow & {
  combo_pets: { pets: PetRow | null }[];
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
  petIds: string[];
  petProfiles: Pet[];
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
  petIds?: string[] | null;
  serviceIds?: string[] | null;
};

const SELECT_WITH_RELATIONS = "*, combo_pets(pets(*)), combo_services(pet_services(*))";

const toIso = (value: Date | string | null | undefined): string | null =>
  value ? new Date(value).toISOString() : null;

export const toPetCombo = (row: WithRelations): PetCombo => {
  const pets = row.combo_pets.flatMap((link) => (link.pets ? [toPet(link.pets)] : []));
  const services = row.combo_services.flatMap((link) =>
    link.pet_services ? [toPetService({ ...link.pet_services, pet_service_pets: [] })] : []
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
    petIds: pets.map((pet) => pet.id),
    petProfiles: pets,
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
  pet_ids: input.petIds ?? [],
  service_ids: input.serviceIds ?? [],
});

export const listPetCombos = async (
  client: Client,
  page: PageParams
): Promise<Page<PetCombo>> => {
  const { from, to } = pageRange(page);
  const { data, count, error } = await client
    .from("pet_service_combos")
    .select(SELECT_WITH_RELATIONS, { count: "exact" })
    .order("created_at", { ascending: false })
    .range(from, to);
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

export const deletePetCombo = async (client: Client, id: string): Promise<void> => {
  const { error } = await client.from("pet_service_combos").delete().eq("id", id);
  if (error) throw error;
};
