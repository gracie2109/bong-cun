// "My pet's health book": vaccination book and signed visits, read only (docs/ho-so-benh-an.md, 9).
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { HealthDose, HealthTakeHome, HealthVaccine, HealthVisit, PetHealth } from "@bongcun/core/account";
import { unwrap } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "../shared/parse";

type Client = SupabaseClient<Database>;

const listOf = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);
const STATES = ["ok", "due_soon", "overdue"] as const;

const toDose = (raw: unknown): HealthDose => {
  const row = asRecord(raw);
  return {
    doseNo: row.dose_no === null || row.dose_no === undefined ? null : Number(row.dose_no),
    givenOn: str(row.given_on),
    isExternal: row.is_external === true,
    externalPlace: str(row.external_place),
  };
};

const toVaccine = (raw: unknown): HealthVaccine => {
  const row = asRecord(raw);
  return {
    vaccineTypeId: str(row.vaccine_type_id),
    name: str(row.name),
    kind: str(row.kind),
    lastGivenOn: str(row.last_given_on),
    nextDueOn: strOrNull(row.next_due_on),
    state: STATES.find((state) => state === row.state) ?? "ok",
    doses: listOf(row.doses).map(toDose),
  };
};

const toTakeHome = (raw: unknown): HealthTakeHome => {
  const row = asRecord(raw);
  return {
    name: str(row.name),
    dose: str(row.dose),
    frequency: str(row.frequency),
    days: row.days === null || row.days === undefined ? null : Number(row.days),
    route: str(row.route),
    instructions: str(row.instructions),
  };
};

const toVisit = (raw: unknown): HealthVisit => {
  const row = asRecord(raw);
  return {
    id: str(row.id),
    date: str(row.date),
    reason: str(row.reason),
    diagnoses: listOf(row.diagnoses).map(str),
    ownerInstructions: str(row.owner_instructions),
    recheckOn: strOrNull(row.recheck_on),
    branchName: str(row.branch_name),
    takeHome: listOf(row.take_home).map(toTakeHome),
  };
};

export const getMyPetHealth = async (client: Client, petId: string): Promise<PetHealth> => {
  const row = asRecord(unwrap(await client.rpc("my_pet_health", { p_pet: petId })));
  return {
    petId: str(row.pet_id),
    petName: str(row.pet_name),
    phone: str(row.phone),
    vaccines: listOf(row.vaccines).map(toVaccine),
    visits: listOf(row.visits).map(toVisit),
  };
};
