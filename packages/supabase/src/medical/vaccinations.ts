// The e-book of shots: giving, typing in a shot from elsewhere, voiding, reading, reminders.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  givenVaccineSchema,
  reminderPageSchema,
  vaccineBookSchema,
  vaccineLotsSchema,
} from "@bongcun/core/medical";
import type {
  ExternalVaccineInput,
  GiveVaccineInput,
  GiveVaccineResult,
  Reminder,
  ReminderFilter,
  VaccineBookEntry,
  VaccineLot,
} from "@bongcun/core/medical";
import { parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toReminder, toVaccineBookEntry, toVaccineLot } from "./mappers";

type Client = SupabaseClient<Database>;

export const petVaccinations = async (client: Client, petId: string): Promise<VaccineBookEntry[]> =>
  (parseRpc("pet_vaccinations", vaccineBookSchema, unwrap(await client.rpc("pet_vaccinations", { p_pet: petId }))) ?? []).map(
    toVaccineBookEntry
  );

export const listVaccineLots = async (client: Client, branchId: string, vaccineTypeId: string): Promise<VaccineLot[]> =>
  (
    parseRpc("vaccine_lots", vaccineLotsSchema, unwrap(await client.rpc("vaccine_lots", { p_branch: branchId, p_vaccine_type: vaccineTypeId }))) ?? []
  ).map(toVaccineLot);

export const giveVaccination = async (client: Client, visitId: string, input: GiveVaccineInput): Promise<GiveVaccineResult> => {
  const raw = unwrap(
    await client.rpc("give_vaccination", {
      p_visit: visitId,
      p: {
        vaccine_type_id: input.vaccineTypeId,
        lot_id: input.lotId,
        dose_no: input.doseNo,
        next_due_on: input.nextDueOn,
      },
    })
  );
  const row = parseRpc("give_vaccination", givenVaccineSchema, raw);
  return { id: row.id, warnings: row.warnings ?? [] };
};

export const addExternalVaccination = async (client: Client, petId: string, input: ExternalVaccineInput): Promise<string> =>
  unwrap(
    await client.rpc("add_external_vaccination", {
      p_pet: petId,
      p: {
        vaccine_type_id: input.vaccineTypeId,
        given_on: input.givenOn,
        external_place: input.externalPlace,
        lot_no: input.lotNo,
        expiry_date: input.expiryDate,
        dose_no: input.doseNo,
        next_due_on: input.nextDueOn,
      },
    })
  );

export const voidVaccination = async (client: Client, id: string, reason: string): Promise<void> => {
  unwrap(await client.rpc("void_vaccination", { p_id: id, p_reason: reason }));
};

export const listMedicalReminders = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: ReminderFilter
): Promise<Page<Reminder>> => {
  const raw = unwrap(
    await client.rpc("medical_reminders", {
      p_branch: branchId,
      p_scope: filter.scope,
      p_search: filter.search?.trim() || undefined,
      p_page: page.pageIndex,
      p_page_size: page.pageSize,
    })
  );
  const result = parseRpc("medical_reminders", reminderPageSchema, raw);
  return { total: result.total, rows: (result.rows ?? []).map(toReminder) };
};

export const markReminded = async (client: Client, vaccinationId: string, note: string): Promise<void> => {
  unwrap(await client.rpc("mark_reminded", { p_vaccination: vaccinationId, p_note: note }));
};
