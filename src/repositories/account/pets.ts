// "My pets": the pets the signed-in customer owns, read-only (docs 3.4). Only staff add, edit or remove pets.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import { PET_SEXES, type MyPet, type PetSex } from "@/types/account";
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
});

export const listMyPets = async (client: Client): Promise<MyPet[]> =>
  (unwrap(await client.rpc("my_pets")) as PetJson[]).map(toPet);
