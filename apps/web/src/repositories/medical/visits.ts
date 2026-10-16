// Medical visits: queue, list, one visit, check-in, booking, the record and its signature.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type {
  MedicalQueue,
  MedicalVisit,
  MedicalVisitDetail,
  Prescription,
  Vet,
  VisitFilter,
} from "@bongcun/core/medical";
import { unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { asRecord, numOrNull, str, strOrNull } from "../spa/parse";
import { rowsOf, toDetail, toMedicalVisit } from "./visitMappers";

export { toMedicalVisit };
export * from "./visitActions";

type Client = SupabaseClient<Database>;

export const getMedicalQueue = async (client: Client, branchId: string, date?: string): Promise<MedicalQueue> => {
  const result = asRecord(unwrap(await client.rpc("medical_queue", { p_branch: branchId, p_date: date || undefined })));
  const counts = asRecord(result.counts);
  return {
    date: str(result.date),
    counts: {
      scheduled: Number(counts.scheduled ?? 0),
      waiting: Number(counts.waiting ?? 0),
      inProgress: Number(counts.in_progress ?? 0),
      done: Number(counts.done ?? 0),
    },
    rows: rowsOf(result.rows).map(toMedicalVisit),
  };
};

export const listMedicalVisits = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: VisitFilter = {}
): Promise<Page<MedicalVisit>> => {
  const result = asRecord(
    unwrap(
      await client.rpc("list_medical_visits", {
        p_branch: branchId,
        p_from: filter.from || undefined,
        p_to: filter.to || undefined,
        p_status: filter.status || undefined,
        p_vet: filter.vetId || undefined,
        p_search: filter.search?.trim() || undefined,
        p_page: page.pageIndex,
        p_page_size: page.pageSize,
      })
    )
  );
  return { rows: rowsOf(result.rows).map(toMedicalVisit), total: Number(result.total ?? 0) };
};

export const getMedicalVisit = async (client: Client, id: string): Promise<MedicalVisitDetail> =>
  toDetail(unwrap(await client.rpc("get_medical_visit", { p_id: id })));

export const petMedicalHistory = async (client: Client, petId: string, page: PageParams): Promise<Page<MedicalVisit>> => {
  const result = asRecord(
    unwrap(await client.rpc("pet_medical_history", { p_pet: petId, p_page: page.pageIndex, p_page_size: page.pageSize }))
  );
  return { rows: rowsOf(result.rows).map(toMedicalVisit), total: Number(result.total ?? 0) };
};

export const listMedicalVets = async (client: Client, branchId: string): Promise<Vet[]> =>
  rowsOf(unwrap(await client.rpc("medical_vets", { p_branch: branchId }))).map((item) => {
    const row = asRecord(item);
    return { id: str(row.id), name: str(row.name) };
  });

export const getMedicalPrescription = async (client: Client, visitId: string): Promise<Prescription> => {
  const row = asRecord(unwrap(await client.rpc("medical_prescription", { p_visit: visitId })));
  return {
    code: str(row.code),
    date: str(row.date),
    branchName: str(row.branch_name),
    petName: str(row.pet_name),
    speciesName: strOrNull(row.species_name),
    weightKg: numOrNull(row.weight_kg),
    customerName: str(row.customer_name),
    customerPhone: str(row.customer_phone),
    vetName: strOrNull(row.vet_name),
    signed: row.signed === true,
    ownerInstructions: strOrNull(row.owner_instructions),
    recheckOn: strOrNull(row.recheck_on),
    diagnoses: rowsOf(row.diagnoses).map(String),
    items: rowsOf(row.items).map((item) => {
      const i = asRecord(item);
      return {
        name: str(i.name),
        qty: Number(i.qty ?? 1),
        unitName: strOrNull(i.unit_name),
        dose: strOrNull(i.dose),
        frequency: strOrNull(i.frequency),
        days: numOrNull(i.days),
        route: strOrNull(i.route),
        instructions: strOrNull(i.instructions),
        external: i.external === true,
      };
    }),
  };
};
