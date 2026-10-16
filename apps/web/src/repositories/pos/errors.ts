/** Error hints raised by the POS and stock functions, for readable messages. */
export const POS_ERROR_HINTS = [
  "no_open_shift",
  "ticket_not_billable",
  "charge_not_billable",
  "medical_item_not_billable",
  "discount_limit",
  "underpaid",
  "overpaid",
  "shift_closed",
  "out_of_stock",
  "has_returns",
  "return_too_much",
  "return_products_only",
  "reason_required",
  "unit_not_available",
] as const;
export type PosErrorHint = (typeof POS_ERROR_HINTS)[number];

export const posErrorHint = (error: unknown): PosErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return POS_ERROR_HINTS.find((item) => item === hint) ?? null;
};

/** The product an error is about (out of stock, return too much), when the database names one. */
export const errorDetail = (error: unknown): string => (error as { details?: string } | null)?.details ?? "";
