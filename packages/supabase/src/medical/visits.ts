// Medical visits: queue, list, one visit, history, vets and the prescription.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import {
  prescriptionSchema,
  queueSchema,
  vetsSchema,
  visitDetailSchema,
  visitPageSchema,
} from "@bongcun/core/medical";
import type { MedicalQueue, MedicalVisit, MedicalVisitDetail, Prescription, Vet, VisitFilter } from "@bongcun/core/medical";
import { parseRpc, unwrap, type Page, type PageParams } from "@bongcun/supabase/shared";
import { toDetail, toMedicalVisit, toPrescription, toQueue } from "./mappers";

export * from "./visitActions";

type Client = SupabaseClient<Database>;

export const getMedicalQueue = async (client: Client, branchId: string, date?: string): Promise<MedicalQueue> => {
  const raw = unwrap(await client.rpc("medical_queue", { p_branch: branchId, p_date: date || undefined }));
  return toQueue(parseRpc("medical_queue", queueSchema, raw));
};

export const listMedicalVisits = async (
  client: Client,
  branchId: string,
  page: PageParams,
  filter: VisitFilter = {}
): Promise<Page<MedicalVisit>> => {
  const raw = unwrap(
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
  );
  const result = parseRpc("list_medical_visits", visitPageSchema, raw);
  return { rows: (result.rows ?? []).map(toMedicalVisit), total: result.total };
};

export const getMedicalVisit = async (client: Client, id: string): Promise<MedicalVisitDetail> =>
  toDetail(parseRpc("get_medical_visit", visitDetailSchema, unwrap(await client.rpc("get_medical_visit", { p_id: id }))));

export const petMedicalHistory = async (client: Client, petId: string, page: PageParams): Promise<Page<MedicalVisit>> => {
  const raw = unwrap(await client.rpc("pet_medical_history", { p_pet: petId, p_page: page.pageIndex, p_page_size: page.pageSize }));
  const result = parseRpc("pet_medical_history", visitPageSchema, raw);
  return { rows: (result.rows ?? []).map(toMedicalVisit), total: result.total };
};

export const listMedicalVets = async (client: Client, branchId: string): Promise<Vet[]> =>
  parseRpc("medical_vets", vetsSchema, unwrap(await client.rpc("medical_vets", { p_branch: branchId }))) ?? [];

export const getMedicalPrescription = async (client: Client, visitId: string): Promise<Prescription> =>
  toPrescription(parseRpc("medical_prescription", prescriptionSchema, unwrap(await client.rpc("medical_prescription", { p_visit: visitId }))));
