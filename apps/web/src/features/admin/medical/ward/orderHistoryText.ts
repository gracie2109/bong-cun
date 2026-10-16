import type { OrderSnapshot } from "@bongcun/core/medical";

const FIELDS = ["dose", "qtyPerDose", "times", "startOn", "endOn", "note"] as const satisfies readonly (keyof OrderSnapshot)[];
export type OrderField = (typeof FIELDS)[number];

const show = (value: unknown): string => {
  if (Array.isArray(value)) return value.join(", ");
  return value == null || value === "" ? "—" : String(value);
};

/** The fields that differ between two snapshots as `field: before → after` parts. */
export const changedFields = (
  before: Partial<OrderSnapshot> | null,
  after: Partial<OrderSnapshot> | null
): { field: OrderField; before: string; after: string }[] =>
  FIELDS.filter((field) => show(before?.[field]) !== show(after?.[field])).map((field) => ({
    field,
    before: show(before?.[field]),
    after: show(after?.[field]),
  }));
