// Medical visits: queue, list, one visit, check-in, booking, the record and its signature.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import type {
  CheckInInput,
  ItemInput,
  ItemKind,
  ItemDirections,
  ItemResult,
  MedicalQueue,
  MedicalVisit,
  MedicalVisitDetail,
  Prescription,
  RecordInput,
  ScheduleInput,
  SignResult,
  Vet,
  VisitFilter,
  VisitOutcome,
  VisitPriority,
  VisitSource,
  VisitStatus,
} from "@/types/medicalVisit";
import { unwrap, type Page, type PageParams } from "../shared";
import { asRecord, numOrNull, str, strOrNull } from "../spa/parse";

type Client = SupabaseClient<Database>;

export const toMedicalVisit = (value: unknown): MedicalVisit => {
  const row = asRecord(value);
  return {
    id: str(row.id),
    code: str(row.code),
    branchId: str(row.branch_id),
    status: str(row.status) as VisitStatus,
    priority: (row.priority === "urgent" ? "urgent" : "normal") as VisitPriority,
    queueNo: numOrNull(row.queue_no),
    scheduledAt: strOrNull(row.scheduled_at),
    checkedInAt: strOrNull(row.checked_in_at),
    startedAt: strOrNull(row.started_at),
    signedAt: strOrNull(row.signed_at),
    createdAt: str(row.created_at),
    petId: str(row.pet_id),
    petName: str(row.pet_name),
    speciesName: strOrNull(row.species_name),
    customerId: str(row.customer_id),
    customerName: str(row.customer_name),
    customerPhone: str(row.customer_phone),
    reason: strOrNull(row.reason),
    vetId: strOrNull(row.vet_id),
    vetName: strOrNull(row.vet_name),
    weightKg: numOrNull(row.weight_kg),
    outcome: strOrNull(row.outcome) as VisitOutcome | null,
    recheckOn: strOrNull(row.recheck_on),
    followUpOf: strOrNull(row.follow_up_of),
    diagnosesText: strOrNull(row.diagnoses_text),
    hasAllergy: row.has_allergy === true,
    hasBehavior: row.has_behavior === true,
    contagious: row.contagious === true,
    branchName: strOrNull(row.branch_name),
    ownerInstructions: strOrNull(row.owner_instructions),
    estTotal: Number(row.est_total ?? 0),
  };
};

const rowsOf = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);

const toDetail = (value: unknown): MedicalVisitDetail => {
  const row = asRecord(value);
  const pet = row.pet ? asRecord(row.pet) : null;
  const recheck = row.recheck_visit ? asRecord(row.recheck_visit) : null;
  return {
    ...toMedicalVisit(row),
    branchName: str(row.branch_name),
    source: str(row.source) as VisitSource,
    subjective: strOrNull(row.subjective),
    objective: strOrNull(row.objective),
    assessment: strOrNull(row.assessment),
    plan: strOrNull(row.plan),
    temperatureC: numOrNull(row.temperature_c),
    heartRate: numOrNull(row.heart_rate),
    respRate: numOrNull(row.resp_rate),
    vitalsNote: strOrNull(row.vitals_note),
    signedByName: strOrNull(row.signed_by_name),
    cancelledAt: strOrNull(row.cancelled_at),
    cancelReason: strOrNull(row.cancel_reason),
    followUpCode: strOrNull(row.follow_up_code),
    recheckVisit: recheck
      ? {
          id: str(recheck.id),
          code: str(recheck.code),
          scheduledAt: strOrNull(recheck.scheduled_at),
          status: str(recheck.status) as VisitStatus,
        }
      : null,
    pet: pet
      ? {
          id: str(pet.id),
          name: str(pet.name),
          speciesName: str(pet.species_name),
          breed: strOrNull(pet.breed),
          sex: strOrNull(pet.sex),
          neutered: typeof pet.neutered === "boolean" ? pet.neutered : null,
          birthDate: strOrNull(pet.birth_date),
          allergies: strOrNull(pet.allergies),
          behaviorNotes: strOrNull(pet.behavior_notes),
          status: str(pet.status),
          photoUrl: strOrNull(pet.photo_url),
          lastWeightKg: numOrNull(pet.last_weight_kg),
        }
      : null,
    diagnoses: rowsOf(row.diagnoses).map((item) => {
      const d = asRecord(item);
      return { id: str(d.id), termId: strOrNull(d.term_id), name: str(d.name), isContagious: d.is_contagious === true, note: strOrNull(d.note) };
    }),
    items: rowsOf(row.items).map((item) => {
      const i = asRecord(item);
      return {
        id: str(i.id),
        kind: str(i.kind) as ItemKind,
        serviceId: strOrNull(i.service_id),
        productId: strOrNull(i.product_id),
        name: str(i.name),
        qty: Number(i.qty ?? 0),
        unitName: strOrNull(i.unit_name),
        unitPrice: Number(i.unit_price ?? 0),
        amount: Number(i.amount ?? 0),
        takeHome: i.take_home === true,
        dose: strOrNull(i.dose),
        frequency: strOrNull(i.frequency),
        days: numOrNull(i.days),
        route: strOrNull(i.route),
        instructions: strOrNull(i.instructions),
        autoAdded: i.auto_added === true,
        invoiceLineId: strOrNull(i.invoice_line_id),
        createdByName: strOrNull(i.created_by_name),
        createdAt: str(i.created_at),
      };
    }),
    addenda: rowsOf(row.addenda).map((item) => {
      const a = asRecord(item);
      return { id: str(a.id), content: str(a.content), createdByName: strOrNull(a.created_by_name), createdAt: str(a.created_at) };
    }),
  };
};

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
