// "My pets": the pets the signed-in customer owns, added and edited through RPCs (docs 3.4).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { PET_SEXES, type MyPet, type PetInput, type PetSex } from "@/types/account";
import { unwrap } from "../shared";

type Client = SupabaseClient<Database>;

type PetJson = {
  id: string;
  name: string;
  species_id: string;
  species_name: string;
  breed: string | null;
  sex: string;
  neutered: boolean;
  birth_date: string | null;
  allergies: string | null;
  behavior_notes: string | null;
  weight_kg: number | null;
  can_edit: boolean;
  has_open_appointment: boolean;
};

const toSex = (value: string): PetSex => PET_SEXES.find((sex) => sex === value) ?? "unknown";

const toPet = (row: PetJson): MyPet => ({
  id: row.id,
  name: row.name,
  speciesId: row.species_id,
  speciesName: row.species_name,
  breed: row.breed ?? "",
  sex: toSex(row.sex),
  neutered: row.neutered,
  birthDate: row.birth_date ?? "",
  allergies: row.allergies ?? "",
  behaviorNotes: row.behavior_notes ?? "",
  weightKg: row.weight_kg === null ? null : Number(row.weight_kg),
  canEdit: row.can_edit,
  hasOpenAppointment: row.has_open_appointment,
});

export const listMyPets = async (client: Client): Promise<MyPet[]> =>
  (unwrap(await client.rpc("my_pets")) as PetJson[]).map(toPet);

/** Adds a pet (no id) or edits one; returns the pet id. */
export const saveMyPet = async (client: Client, input: PetInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("save_my_pet", {
      p: {
        name: input.name.trim(),
        species_id: input.speciesId,
        breed: input.breed.trim(),
        sex: input.sex,
        neutered: input.neutered,
        birth_date: input.birthDate || null,
        allergies: input.allergies.trim(),
        behavior_notes: input.behaviorNotes.trim(),
        weight_kg: input.weightKg.trim(),
      },
      p_id: id ?? null,
    })
  );

export const hideMyPet = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("hide_my_pet", { p_id: id }));
};

/** Error hints raised by save_my_pet and hide_my_pet, for readable messages. */
export const PET_ERROR_HINTS = [
  "no_customer",
  "invalid_name",
  "invalid_species",
  "invalid_sex",
  "invalid_birth_date",
  "invalid_weight",
  "too_many_pets",
  "not_found",
  "not_primary",
  "has_open_appointment",
] as const;
export type PetErrorHint = (typeof PET_ERROR_HINTS)[number];

export const petErrorHint = (error: unknown): PetErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return PET_ERROR_HINTS.find((item) => item === hint) ?? null;
};
