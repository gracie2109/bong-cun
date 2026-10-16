// The hints the medical RPCs attach to a refusal.
export const MEDICAL_ERROR_HINTS = [
  "duplicate_name",
  "bad_input",
  "bad_protocol",
  "bad_rules",
  "not_found",
  "signed",
  "bad_recheck",
  "bad_vet",
  "inpatient_unavailable",
  "no_assessment",
  "no_customer",
  "no_outcome",
  "no_pet",
  "not_due",
  "not_editable",
  "not_in_progress",
  "not_scheduled",
  "not_waiting",
  "pet_busy",
  "pet_deceased",
  "taken",
  "has_items",
  "paid",
  "no_service",
  "not_available",
  "species_not_allowed",
  "no_weight",
  "no_price",
  "bad_unit",
  "no_vaccine",
  "no_lot",
  "future_date",
  "inpatient_active",
  "no_kennel",
  "need_isolation",
  "kennel_taken",
  "already_admitted",
  "already_done",
  "replace_order",
  "order_stopped",
] as const;
export type MedicalErrorHint = (typeof MEDICAL_ERROR_HINTS)[number];

export const medicalErrorHint = (error: unknown): MedicalErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return MEDICAL_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** The record an error is about, when the database names one. */
export const medicalErrorDetail = (error: unknown): string => (error as { details?: string } | null)?.details ?? "";
