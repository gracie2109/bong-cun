import { IMPORT_BATCH_SIZE, IMPORT_CALL_LIMIT } from "@bongcun/core/data-io";

/**
 * Splits rows into calls of about `size` rows. Rows with the same `keyOf` value always travel
 * together (a product group is saved as a whole); keys keep the order in which they first appear.
 */
export const batchRows = <R>(rows: readonly R[], size = IMPORT_BATCH_SIZE, keyOf?: (row: R) => string): R[][] => {
  const limit = Math.min(size, IMPORT_CALL_LIMIT);
  if (!keyOf) {
    const batches: R[][] = [];
    for (let i = 0; i < rows.length; i += limit) batches.push(rows.slice(i, i + limit));
    return batches;
  }
  const groups = new Map<string, R[]>();
  for (const row of rows) {
    const key = keyOf(row);
    groups.set(key, [...(groups.get(key) ?? []), row]);
  }
  const batches: R[][] = [];
  let current: R[] = [];
  for (const group of groups.values()) {
    if (current.length > 0 && current.length + group.length > limit) {
      batches.push(current);
      current = [];
    }
    current = [...current, ...group];
  }
  if (current.length > 0) batches.push(current);
  return batches;
};
