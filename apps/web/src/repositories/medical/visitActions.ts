import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type {
  CheckInInput,
  ItemInput,
  ItemDirections,
  ItemResult,
  RecordInput,
  ScheduleInput,
  SignResult,
  VisitStatus,
} from "@/types/medicalVisit";
import { unwrap } from "../shared";
import { asRecord, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

export const checkInMedicalVisit = async (
  client: Client,
  input: CheckInInput
): Promise<{ id: string; code: string; queueNo: number }> => {
  const row = asRecord(
    unwrap(
      await client.rpc("check_in_medical_visit", {
        p: {
          visit_id: input.visitId ?? null,
          branch_id: input.branchId,
          customer_id: input.customerId,
          pet_id: input.petId,
          reason: input.reason,
          priority: input.priority,
          vet_id: input.vetId,
          weight_kg: input.weightKg,
          temperature_c: input.temperatureC,
          source: input.source ?? "counter",
        },
      })
    )
  );
  return { id: str(row.id), code: str(row.code), queueNo: Number(row.queue_no ?? 0) };
};

export const scheduleMedicalVisit = async (client: Client, input: ScheduleInput, id?: string): Promise<string> =>
  unwrap(
    await client.rpc("schedule_medical_visit", {
      p: {
        branch_id: input.branchId,
        customer_id: input.customerId,
        pet_id: input.petId,
        scheduled_at: input.scheduledAt,
        reason: input.reason,
        vet_id: input.vetId,
        source: "phone",
      },
      p_id: id,
    })
  );

export const startMedicalVisit = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("start_medical_visit", { p_id: id }));
};

export const assignMedicalVet = async (client: Client, id: string, vetId: string | null): Promise<void> => {
  unwrap(await client.rpc("assign_medical_vet", { p_id: id, p_vet: vetId as string }));
};

export const saveMedicalRecord = async (client: Client, id: string, record: RecordInput): Promise<void> => {
  unwrap(
    await client.rpc("save_medical_record", {
      p_id: id,
      p: {
        weight_kg: record.weightKg,
        temperature_c: record.temperatureC,
        heart_rate: record.heartRate,
        resp_rate: record.respRate,
        vitals_note: record.vitalsNote,
        subjective: record.subjective,
        objective: record.objective,
        assessment: record.assessment,
        plan: record.plan,
        owner_instructions: record.ownerInstructions,
        outcome: record.outcome ?? "",
        recheck_on: record.recheckOn,
        diagnoses: record.diagnoses.map((item) => ({
          term_id: item.termId,
          name: item.name,
          is_contagious: item.isContagious,
          note: item.note,
        })),
      },
    })
  );
};

export const signMedicalVisit = async (client: Client, id: string): Promise<SignResult> => {
  const row = asRecord(unwrap(await client.rpc("sign_medical_visit", { p_id: id })));
  return { id: str(row.id), status: str(row.status) as VisitStatus, recheckVisitId: strOrNull(row.recheck_visit_id) };
};

export const addMedicalAddendum = async (client: Client, id: string, content: string): Promise<void> => {
  unwrap(await client.rpc("add_medical_addendum", { p_id: id, p_content: content }));
};

export const cancelMedicalVisit = async (client: Client, id: string, reason: string): Promise<void> => {
  unwrap(await client.rpc("cancel_medical_visit", { p_id: id, p_reason: reason }));
};

export const markMedicalNoShow = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("mark_medical_no_show", { p_id: id }));
};

// ------------------------------------------------------------------- lines
const toItemResult = (value: unknown): ItemResult => {
  const row = asRecord(value);
  return { id: str(row.id), warnings: Array.isArray(row.warnings) ? row.warnings.map(String) : [] };
};

const directions = (item: ItemDirections) => ({
  take_home: item.takeHome,
  dose: item.dose,
  frequency: item.frequency,
  days: item.days,
  route: item.route,
  instructions: item.instructions,
});

export const addMedicalItem = async (client: Client, visitId: string, input: ItemInput): Promise<ItemResult> =>
  toItemResult(
    unwrap(
      await client.rpc("add_medical_item", {
        p_visit: visitId,
        p: {
          kind: input.kind,
          service_id: input.serviceId ?? null,
          product_id: input.productId ?? null,
          name: input.name ?? null,
          qty: input.qty,
          ...directions(input),
        },
      })
    )
  );

export const updateMedicalItem = async (
  client: Client,
  id: string,
  patch: Partial<ItemDirections> & { qty?: number }
): Promise<ItemResult> =>
  toItemResult(
    unwrap(
      await client.rpc("update_medical_item", {
        p_id: id,
        p: {
          ...(patch.qty !== undefined && { qty: patch.qty }),
          ...(patch.takeHome !== undefined && { take_home: patch.takeHome }),
          ...(patch.dose !== undefined && { dose: patch.dose }),
          ...(patch.frequency !== undefined && { frequency: patch.frequency }),
          ...(patch.days !== undefined && { days: patch.days }),
          ...(patch.route !== undefined && { route: patch.route }),
          ...(patch.instructions !== undefined && { instructions: patch.instructions }),
        },
      })
    )
  );

export const removeMedicalItem = async (client: Client, id: string): Promise<void> => {
  unwrap(await client.rpc("remove_medical_item", { p_id: id }));
};
