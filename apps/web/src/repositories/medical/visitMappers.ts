import type {
  ItemKind,
  MedicalVisit,
  MedicalVisitDetail,
  VisitOutcome,
  VisitPriority,
  VisitSource,
  VisitStatus,
} from "@bongcun/core/medical";
import { asRecord, numOrNull, str, strOrNull } from "@bongcun/supabase/shared";

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

export const rowsOf = (value: unknown): unknown[] => (Array.isArray(value) ? value : []);

export const toDetail = (value: unknown): MedicalVisitDetail => {
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
