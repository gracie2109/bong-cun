// The e-book of shots: giving, typing in a shot from elsewhere, voiding, reading, reminders.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type {
  BookState,
  ExternalVaccineInput,
  GiveVaccineInput,
  GiveVaccineResult,
  Reminder,
  ReminderFilter,
  VaccineBookEntry,
  VaccineLot,
} from "@bongcun/core/medical";
import { unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { asRecord, str, strOrNull } from "@bongcun/supabase/shared";

type Client = SupabaseClient<Database>;

const rowsOf = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);

export const petVaccinations = async (client: Client, petId: string): Promise<VaccineBookEntry[]> =>
  rowsOf(unwrap(await client.rpc("pet_vaccinations", { p_pet: petId }))).map((value) => {
    const row = asRecord(value);
    return {
      vaccineTypeId: str(row.vaccine_type_id),
      name: str(row.name),
      kind: str(row.kind),
      state: str(row.state) as BookState,
      nextDueOn: strOrNull(row.next_due_on),
      lastGivenOn: str(row.last_given_on),
      doses: rowsOf(row.doses).map((item) => {
        const d = asRecord(item);
        return {
          id: str(d.id),
          doseNo: Number(d.dose_no ?? 1),
          givenOn: str(d.given_on),
          lotNo: strOrNull(d.lot_no),
          expiryDate: strOrNull(d.expiry_date),
          isExternal: d.is_external === true,
          externalPlace: strOrNull(d.external_place),
          vetName: strOrNull(d.vet_name),
          nextDueOn: strOrNull(d.next_due_on),
          branchName: strOrNull(d.branch_name),
          visitId: strOrNull(d.visit_id),
          voidedAt: strOrNull(d.voided_at),
        };
      }),
    };
  });

export const listVaccineLots = async (client: Client, branchId: string, vaccineTypeId: string): Promise<VaccineLot[]> =>
  rowsOf(unwrap(await client.rpc("vaccine_lots", { p_branch: branchId, p_vaccine_type: vaccineTypeId }))).map((value) => {
    const row = asRecord(value);
    return {
      id: str(row.id),
      lotNo: str(row.lot_no),
      expiryDate: strOrNull(row.expiry_date),
      qtyOnHand: Number(row.qty_on_hand ?? 0),
    };
  });

export const giveVaccination = async (client: Client, visitId: string, input: GiveVaccineInput): Promise<GiveVaccineResult> => {
  const row = asRecord(
    unwrap(
      await client.rpc("give_vaccination", {
        p_visit: visitId,
        p: {
          vaccine_type_id: input.vaccineTypeId,
          lot_id: input.lotId,
          dose_no: input.doseNo,
          next_due_on: input.nextDueOn,
        },
      })
    )
  );
  return { id: str(row.id), warnings: rowsOf(row.warnings).map(String) };
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
  const result = asRecord(
    unwrap(
      await client.rpc("medical_reminders", {
        p_branch: branchId,
        p_scope: filter.scope,
        p_search: filter.search?.trim() || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
      })
    )
  );
  return {
    total: Number(result.total ?? 0),
    rows: rowsOf(result.rows).map((value) => {
      const row = asRecord(value);
      return {
        kind: row.kind === "recheck" ? "recheck" : "vaccination",
        vaccinationId: strOrNull(row.vaccination_id),
        visitId: strOrNull(row.visit_id),
        petId: str(row.pet_id),
        petName: str(row.pet_name),
        speciesName: str(row.species_name),
        customerId: str(row.customer_id),
        customerName: str(row.customer_name),
        customerPhone: str(row.customer_phone),
        vaccineName: strOrNull(row.vaccine_name),
        dueOn: str(row.due_on),
        lastGivenOn: strOrNull(row.last_given_on),
        remindedAt: strOrNull(row.reminded_at),
        remindNote: strOrNull(row.remind_note),
        remindedByName: strOrNull(row.reminded_by_name),
      };
    }),
  };
};

export const markReminded = async (client: Client, vaccinationId: string, note: string): Promise<void> => {
  unwrap(await client.rpc("mark_reminded", { p_vaccination: vaccinationId, p_note: note }));
};

