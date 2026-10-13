import type { ImportReport, ImportRow } from "./importTypes";
import { BATCH_SIZE } from "./importTemplate";

/** The database accepts this many rows in one call. */
const MAX_BATCH = 500;

const groupKey = (row: ImportRow) => row.group.trim().toLowerCase();

/**
 * Splits rows into calls of about `size` rows. The rows of one group always travel together, because
 * a group is saved as a whole; groups keep the order in which they first appear.
 */
export const batchByGroup = (rows: readonly ImportRow[], size = BATCH_SIZE): ImportRow[][] => {
  const groups = new Map<string, ImportRow[]>();
  for (const row of rows) groups.set(groupKey(row), [...(groups.get(groupKey(row)) ?? []), row]);

  const batches: ImportRow[][] = [];
  let current: ImportRow[] = [];
  for (const group of groups.values()) {
    if (current.length > 0 && current.length + group.length > Math.min(size, MAX_BATCH)) {
      batches.push(current);
      current = [];
    }
    current = [...current, ...group];
  }
  if (current.length > 0) batches.push(current);
  return batches;
};

export const emptyReport = (): ImportReport => ({
  ok: true,
  created_groups: 0,
  updated_groups: 0,
  created_variants: 0,
  updated_variants: 0,
  new_categories: [],
  new_brands: [],
  rows: [],
});

/** Adds the answer for one batch to the running total. */
export const mergeReports = (total: ImportReport, part: ImportReport): ImportReport => ({
  ok: total.ok && part.ok,
  created_groups: total.created_groups + part.created_groups,
  updated_groups: total.updated_groups + part.updated_groups,
  created_variants: total.created_variants + part.created_variants,
  updated_variants: total.updated_variants + part.updated_variants,
  new_categories: [...new Set([...total.new_categories, ...part.new_categories])],
  new_brands: [...new Set([...total.new_brands, ...part.new_brands])],
  rows: [...total.rows, ...part.rows],
});
