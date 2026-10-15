// The hints the boarding RPCs attach to a refusal.
export const BOARDING_ERROR_HINTS = [
  "duplicate_name",
  "duplicate_code",
  "no_price",
  "bad_input",
  "bad_rules",
  "not_found",
] as const;
export type BoardingErrorHint = (typeof BOARDING_ERROR_HINTS)[number];

export const boardingErrorHint = (error: unknown): BoardingErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return BOARDING_ERROR_HINTS.find((item) => item === hint) ?? null;
};
