import type { HistoryRow } from "@bongcun/core/attendance";
import { timeOf } from "@/features/admin/attendance/shared/attendanceFormat";

const ISO_INSTANT = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/;

/** A value of a history diff as text: instants as HH:mm, empty as a dash. */
export const formatHistoryValue = (value: unknown): string => {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "boolean") return value ? "✓" : "✗";
  if (typeof value === "string" && ISO_INSTANT.test(value)) return timeOf(value);
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
};

type Snapshot = Record<string, unknown>;
const snapshot = (row: Pick<HistoryRow, "before" | "after">): Snapshot => {
  const side = row.after ?? row.before;
  return side && !Array.isArray(side) ? side : {};
};

/** The shift or request a line is about: its name and work date, when the row carries them. */
export const historySubject = (row: Pick<HistoryRow, "before" | "after">): { name: string | null; date: string | null } => {
  const data = snapshot(row);
  return { name: typeof data.name === "string" ? data.name : null, date: typeof data.work_date === "string" ? data.work_date : null };
};
