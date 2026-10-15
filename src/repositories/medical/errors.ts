// The hints the medical RPCs attach to a refusal.
export const MEDICAL_ERROR_HINTS = [
  "duplicate_name",
  "bad_input",
  "bad_protocol",
  "bad_rules",
  "not_found",
] as const;
export type MedicalErrorHint = (typeof MEDICAL_ERROR_HINTS)[number];

export const medicalErrorHint = (error: unknown): MedicalErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return MEDICAL_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** The record an error is about, when the database names one. */
export const medicalErrorDetail = (error: unknown): string => (error as { details?: string } | null)?.details ?? "";
