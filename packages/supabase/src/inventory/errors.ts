// -------------------------------------------------------------------- errors
/** Error hints raised by the inventory functions, for readable messages. */
export const INVENTORY_ERROR_HINTS = [
  "lot_short",
  "needs_manager",
  "not_draft",
  "no_lines",
  "posted_not_receipt",
  "reason_required",
  "untracked_product",
  "unit_not_available",
] as const;
export type InventoryErrorHint = (typeof INVENTORY_ERROR_HINTS)[number];

export const inventoryErrorHint = (error: unknown): InventoryErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return INVENTORY_ERROR_HINTS.find((item) => item === hint) ?? null;
};
