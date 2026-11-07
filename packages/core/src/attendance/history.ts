import type { HistoryAction, HistoryRow } from "./historyTypes";

export type FieldDiff = { field: string; from: unknown; to: unknown };

/** The fields that differ between the before and after of one history line, in the given order. */
export const diffRows = (before: HistoryRow["before"], after: HistoryRow["after"], fields: readonly string[]): FieldDiff[] => {
  const left = (Array.isArray(before) ? {} : before) ?? {};
  const right = (Array.isArray(after) ? {} : after) ?? {};
  return fields
    .filter((field) => JSON.stringify(left[field]) !== JSON.stringify(right[field]))
    .map((field) => ({ field, from: left[field] ?? null, to: right[field] ?? null }));
};

/** Columns that only carry bookkeeping and are not worth showing in a diff. */
const HIDDEN_FIELDS = new Set(["id", "created_at", "created_by", "updated_at", "updated_by", "branch_id", "user_id", "user_name"]);

/** What to show for a line: the changed fields for an update, else every field of the row that exists. */
export const visibleFields = (row: Pick<HistoryRow, "action" | "before" | "after" | "changedFields">): string[] => {
  if (row.action === "update") return row.changedFields.filter((field) => !HIDDEN_FIELDS.has(field));
  const source = (row.after && !Array.isArray(row.after) ? row.after : row.before && !Array.isArray(row.before) ? row.before : {}) as Record<string, unknown>;
  return Object.keys(source).filter((field) => !HIDDEN_FIELDS.has(field));
};

/** The i18n key suffix of an action: attendance.history.actions.<key>. */
export const actionKey = (action: HistoryAction): HistoryAction => action;

/** Tone for the action pill. */
export const actionTone = (action: HistoryAction): "good" | "bad" | "warn" | "neutral" => {
  switch (action) {
    case "insert":
    case "approve":
    case "publish":
    case "auto_publish":
      return "good";
    case "delete":
    case "reject":
    case "cancel":
      return "bad";
    case "update":
    case "replace":
    case "declare_none":
      return "warn";
    default:
      return "neutral";
  }
};
