import type { RouteLocationRaw } from "vue-router";

export type ActionRowKey =
  | "pendingOrders"
  | "stockLow"
  | "stockOut"
  | "stockExpiring"
  | "stockExpired"
  | "vaccineOverdue"
  | "vaccineDue"
  | "boardingOverdue";

/** One thing that needs attention. `count` is null while it loads or when its source failed. */
export type ActionRow = {
  key: ActionRowKey;
  count: number | null;
  failed: boolean;
  to: RouteLocationRaw;
};

export const ROUTES: Record<ActionRowKey, string> = {
  pendingOrders: "shopOrders",
  stockLow: "inventoryStock",
  stockOut: "inventoryStock",
  stockExpiring: "inventoryStock",
  stockExpired: "inventoryStock",
  vaccineOverdue: "medicalReminders",
  vaccineDue: "medicalReminders",
  boardingOverdue: "boardingBoard",
};

/** Rows with something to do come first; the order inside each group is kept. */
export const sortRows = (rows: readonly ActionRow[]): ActionRow[] => [
  ...rows.filter((row) => (row.count ?? 0) > 0),
  ...rows.filter((row) => (row.count ?? 0) === 0),
];

/** True once every source has answered and none has anything to do. */
export const allClear = (rows: readonly ActionRow[]): boolean =>
  rows.length > 0 && rows.every((row) => !row.failed && row.count === 0);
