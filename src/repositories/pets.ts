// Pet profiles: one row per animal, with owners and weight history.
// The species catalog (Chó, Mèo...) is in species.ts.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Tables } from "@/types/database.types";
import { toCustomer, type Customer } from "./customers";
import { filterSafe, pageRange, unwrap, type Page, type PageParams } from "./shared";

type Client = SupabaseClient<Database>;

export type PetSex = "male" | "female" | "unknown";
export type PetStatus = "active" | "deceased" | "archived";
export type OwnerRole = "primary" | "co_owner";

const SEXES: readonly PetSex[] = ["male", "female", "unknown"];
const STATUSES: readonly PetStatus[] = ["active", "deceased", "archived"];

const toSex = (value: string): PetSex => SEXES.find((sex) => sex === value) ?? "unknown";
const toStatus = (value: string): PetStatus => STATUSES.find((s) => s === value) ?? "active";

/** One row of the pet list (the pet_overview view). */
export type PetListItem = {
  id: string;
  name: string;
  speciesId: string;
  speciesName: string;
  speciesIcon: string | null;
  breed: string | null;
  sex: PetSex;
  neutered: boolean;
  birthDate: string | null;
  photoUrl: string | null;
  allergies: string | null;
  behaviorNotes: string | null;
  status: PetStatus;
  weightKg: number | null;
  weightMeasuredAt: string | null;
  bracketId: string | null;
  bracketLabel: string | null;
  ownerId: string | null;
  ownerName: string | null;
  ownerPhone: string | null;
  ownerCount: number;
  createdAt: string;
};

export type PetListFilter = {
  search?: string;
  speciesId?: string;
  bracketId?: string;
  status?: PetStatus;
};

export type PetOwner = { customer: Customer; role: OwnerRole; fromDate: string };

export type PetWeightLog = { id: string; weightKg: number; measuredAt: string; note: string | null };

export type PetProfile = {
  id: string;
  name: string;
  speciesId: string;
  speciesName: string;
  speciesIcon: string | null;
  breed: string | null;
  sex: PetSex;
  neutered: boolean;
  birthDate: string | null;
  microchip: string | null;
  photoUrl: string | null;
  allergies: string | null;
  behaviorNotes: string | null;
  status: PetStatus;
  owners: PetOwner[];
  weights: PetWeightLog[];
};

export type PetInput = {
  speciesId: string;
  name: string;
  breed?: string | null;
  sex?: PetSex;
  neutered?: boolean;
  birthDate?: string | null;
  microchip?: string | null;
  photoUrl?: string | null;
  allergies?: string | null;
  behaviorNotes?: string | null;
};

/** The owner of a new pet: an existing customer (id) or the details of a new one. */
export type RegisterOwner = { id: string } | { fullName: string; phone: string; email?: string | null };

export type RegisterPetInput = { owner: RegisterOwner; pet: PetInput; weightKg?: number | null };

type OverviewRow = Database["public"]["Views"]["pet_overview"]["Row"];

export const toPetListItem = (row: OverviewRow): PetListItem => ({
  id: row.id ?? "",
  name: row.name ?? "",
  speciesId: row.species_id ?? "",
  speciesName: row.species_name ?? "",
  speciesIcon: row.species_icon,
  breed: row.breed,
  sex: toSex(row.sex ?? ""),
  neutered: row.neutered ?? false,
  birthDate: row.birth_date,
  photoUrl: row.photo_url,
  allergies: row.allergies,
  behaviorNotes: row.behavior_notes,
  status: toStatus(row.status ?? ""),
  weightKg: row.weight_kg,
  weightMeasuredAt: row.weight_measured_at,
  bracketId: row.bracket_id,
  bracketLabel: row.bracket_label,
  ownerId: row.owner_id,
  ownerName: row.owner_name,
  ownerPhone: row.owner_phone,
  ownerCount: row.owner_count ?? 0,
  createdAt: row.created_at ?? "",
});

export const listPets = async (
  client: Client,
  page: PageParams,
  filter: PetListFilter = {}
): Promise<Page<PetListItem>> => {
  const { from, to } = pageRange(page);
  let query = client
    .from("pet_overview")
    .select("*", { count: "exact" })
    .eq("status", filter.status ?? "active")
    .order("created_at", { ascending: false })
    .range(from, to);

  if (filter.speciesId) query = query.eq("species_id", filter.speciesId);
  if (filter.bracketId) query = query.eq("bracket_id", filter.bracketId);

  const term = filterSafe(filter.search ?? "");
  if (term) {
    const digits = term.replace(/\D/g, "");
    const conditions = [`name.ilike.%${term}%`, `owner_name.ilike.%${term}%`];
    if (digits.length >= 3) conditions.push(`owner_phone.ilike.%${digits}%`);
    query = query.or(conditions.join(","));
  }

  const { data, count, error } = await query;
  if (error) throw error;
  return { rows: (data ?? []).map(toPetListItem), total: count ?? 0 };
};

type ProfileRow = Tables<"pets"> & {
  species: Tables<"species"> | null;
  pet_owners: (Tables<"pet_owners"> & { customers: Tables<"customers"> | null })[];
  pet_weight_logs: Tables<"pet_weight_logs">[];
};

export const getPet = async (client: Client, id: string): Promise<PetProfile | null> => {
  const row = unwrap(
    await client
      .from("pets")
      .select("*, species(*), pet_owners(*, customers(*)), pet_weight_logs(*)")
      .eq("id", id)
      .is("pet_owners.to_date", null)
      .maybeSingle()
  ) as ProfileRow | null;
  if (!row) return null;

  return {
    id: row.id,
    name: row.name,
    speciesId: row.species_id,
    speciesName: row.species?.name ?? "",
    speciesIcon: row.species?.icon ?? null,
    breed: row.breed,
    sex: toSex(row.sex),
    neutered: row.neutered,
    birthDate: row.birth_date,
    microchip: row.microchip,
    photoUrl: row.photo_url,
    allergies: row.allergies,
    behaviorNotes: row.behavior_notes,
    status: toStatus(row.status),
    owners: row.pet_owners.flatMap((link) =>
      link.customers
        ? [{
            customer: toCustomer(link.customers),
            role: link.role === "co_owner" ? ("co_owner" as const) : ("primary" as const),
            fromDate: link.from_date,
          }]
        : []
    ),
    weights: row.pet_weight_logs
      .map((log) => ({
        id: log.id,
        weightKg: log.weight_kg,
        measuredAt: log.measured_at,
        note: log.note,
      }))
      .sort((a, b) => b.measuredAt.localeCompare(a.measuredAt)),
  };
};

const toPetColumns = (input: PetInput) => ({
  species_id: input.speciesId,
  name: input.name,
  breed: input.breed || null,
  sex: input.sex ?? "unknown",
  neutered: input.neutered ?? false,
  birth_date: input.birthDate || null,
  microchip: input.microchip || null,
  photo_url: input.photoUrl || null,
  allergies: input.allergies || null,
  behavior_notes: input.behaviorNotes || null,
});

/** Customer (found by phone or new), pet, owner link and first weight in one transaction. */
export const registerPet = async (client: Client, input: RegisterPetInput): Promise<string> => {
  const customer =
    "id" in input.owner
      ? { id: input.owner.id }
      : {
          full_name: input.owner.fullName,
          phone: input.owner.phone,
          email: input.owner.email ?? null,
        };
  const pet = toPetColumns(input.pet);
  return unwrap(
    await client.rpc("register_pet", {
      p: { customer, pet, weight_kg: input.weightKg ?? null },
    })
  );
};

export const updatePet = async (client: Client, id: string, input: PetInput): Promise<void> => {
  const { error } = await client.from("pets").update(toPetColumns(input)).eq("id", id);
  if (error) throw error;
};

export const setPetStatus = async (client: Client, id: string, status: PetStatus): Promise<void> => {
  const { error } = await client.from("pets").update({ status }).eq("id", id);
  if (error) throw error;
};

export const addPetWeight = async (
  client: Client,
  petId: string,
  weightKg: number,
  note?: string | null
): Promise<void> => {
  const { error } = await client
    .from("pet_weight_logs")
    .insert({ pet_id: petId, weight_kg: weightKg, note: note || null });
  if (error) throw error;
};
