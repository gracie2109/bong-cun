// The hints the location RPCs attach to a refusal.
export const LOCATION_ERROR_HINTS = ["location_not_found", "location_search_too_short", "location_inactive", "invalid_input"] as const;
export type LocationErrorHint = (typeof LOCATION_ERROR_HINTS)[number];

export const locationErrorHint = (error: unknown): LocationErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return LOCATION_ERROR_HINTS.find((item) => item === hint) ?? null;
};
