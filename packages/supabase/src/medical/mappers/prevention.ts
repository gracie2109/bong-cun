// Vaccination, catalog, settings, health-flag and attachment rows -> domain types. Pure.
import type {
  AttachmentRow,
  DiagnosisTerm,
  DiagnosisTermRow,
  MedicalAttachment,
  MedicalRules,
  MedicalRulesRow,
  PetHealthFlags,
  Reminder,
  ReminderRow,
  VaccineBookEntry,
  VaccineBookRow,
  VaccineLot,
  VaccineType,
  VaccineTypeRow,
} from "@bongcun/core/medical";

export const toVaccineBookEntry = (row: VaccineBookRow): VaccineBookEntry => ({
  vaccineTypeId: row.vaccine_type_id,
  name: row.name,
  kind: row.kind,
  state: row.state,
  nextDueOn: row.next_due_on ?? null,
  lastGivenOn: row.last_given_on,
  doses: (row.doses ?? []).map((dose) => ({
    id: dose.id,
    doseNo: dose.dose_no,
    givenOn: dose.given_on,
    lotNo: dose.lot_no ?? null,
    expiryDate: dose.expiry_date ?? null,
    isExternal: dose.is_external,
    externalPlace: dose.external_place ?? null,
    vetName: dose.vet_name ?? null,
    nextDueOn: dose.next_due_on ?? null,
    branchName: dose.branch_name ?? null,
    visitId: dose.visit_id ?? null,
    voidedAt: dose.voided_at ?? null,
  })),
});

export const toVaccineLot = (row: { id: string; lot_no: string; expiry_date?: string | null; qty_on_hand: number }): VaccineLot => ({
  id: row.id,
  lotNo: row.lot_no,
  expiryDate: row.expiry_date ?? null,
  qtyOnHand: row.qty_on_hand,
});

export const toReminder = (row: ReminderRow): Reminder => ({
  kind: row.kind,
  vaccinationId: row.vaccination_id ?? null,
  visitId: row.visit_id ?? null,
  petId: row.pet_id,
  petName: row.pet_name,
  speciesName: row.species_name ?? "",
  customerId: row.customer_id,
  customerName: row.customer_name,
  customerPhone: row.customer_phone,
  vaccineName: row.vaccine_name ?? null,
  dueOn: row.due_on,
  lastGivenOn: row.last_given_on ?? null,
  remindedAt: row.reminded_at ?? null,
  remindNote: row.remind_note ?? null,
  remindedByName: row.reminded_by_name ?? null,
});

export const toVaccineType = (row: VaccineTypeRow): VaccineType => ({
  id: row.id,
  name: row.name,
  kind: row.kind,
  speciesIds: row.species_ids ?? [],
  speciesNames: row.species_names ?? [],
  productId: row.product_id ?? null,
  productName: row.product_name ?? null,
  productUnit: row.product_unit ?? null,
  stockQty: row.stock_qty ?? null,
  seriesDoses: row.series_doses,
  seriesIntervalDays: row.series_interval_days ?? null,
  boosterIntervalDays: row.booster_interval_days ?? null,
  minAgeWeeks: row.min_age_weeks ?? null,
  isActive: row.is_active,
  sortOrder: row.sort_order,
});

export const toDiagnosisTerm = (row: DiagnosisTermRow): DiagnosisTerm => ({
  id: row.id,
  name: row.name,
  speciesIds: row.species_ids ?? [],
  speciesNames: row.species_names ?? [],
  isContagious: row.is_contagious,
  isActive: row.is_active,
  sortOrder: row.sort_order,
});

export const toMedicalRules = (row: MedicalRulesRow): MedicalRules => ({
  examServiceId: row.exam_service_id ?? null,
  examServiceName: row.exam_service_name ?? null,
  remindAheadDays: row.remind_ahead_days,
  contagiousDays: row.contagious_days,
  requireVaccineForBoarding: row.require_vaccine_for_boarding,
});

export const toPetHealthFlags = (flags: Record<string, { contagious: boolean; vaccine_overdue: boolean; allergies?: string | null }>) =>
  Object.fromEntries(
    Object.entries(flags).map(([petId, row]): [string, PetHealthFlags] => [
      petId,
      { contagious: row.contagious, vaccineOverdue: row.vaccine_overdue, allergies: row.allergies ?? null },
    ])
  );

export const toAttachment = (row: AttachmentRow): MedicalAttachment => ({
  id: row.id,
  visitId: row.visit_id,
  kind: row.kind,
  title: row.title,
  filePath: row.file_path,
  mimeType: row.mime_type,
  sizeBytes: row.size_bytes,
  createdByName: row.created_by_name ?? null,
  createdAt: row.created_at,
});
