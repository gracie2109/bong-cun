// The hints the boarding RPCs attach to a refusal.
export const BOARDING_ERROR_HINTS = [
  "duplicate_name",
  "duplicate_code",
  "no_price",
  "bad_input",
  "bad_rules",
  "not_found",
  "no_kennel",
  "kennel_taken",
  "kennel_in_use",
  "kennel_occupied",
  "pet_busy",
  "species_not_allowed",
  "too_many_pets",
  "bad_dates",
  "bad_share",
  "too_long",
  "too_early",
  "in_past",
  "not_editable",
  "not_due",
  "no_customer",
  "no_pet",
  "need_pet",
  "need_weight",
  "kennel_not_ready",
  "too_old",
  "no_service",
  "wrong_type",
  "same_kennel",
  "kennel_full",
] as const;
export type BoardingErrorHint = (typeof BOARDING_ERROR_HINTS)[number];

export const boardingErrorHint = (error: unknown): BoardingErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return BOARDING_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** The kennel type or pet an error is about, when the database names one. */
export const boardingErrorDetail = (error: unknown): string => (error as { details?: string } | null)?.details ?? "";
