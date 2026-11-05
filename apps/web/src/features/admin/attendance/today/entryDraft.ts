import { fromLocalInput, toLocalInput } from "@/features/admin/attendance/shared/attendanceFormat";
import type { AddEntryInput, AttendanceRow, EditEntryInput } from "@bongcun/core/attendance";

export type EntryDraft = { checkIn: string; checkOut: string; reason: string };

export const emptyDraft = (): EntryDraft => ({ checkIn: "", checkOut: "", reason: "" });

/** The form for an existing entry, or (to record a missed one) the shift's own hours as a start. */
export const draftFromRow = (row: AttendanceRow): EntryDraft => ({
  checkIn: row.checkInAt ? toLocalInput(row.checkInAt) : row.startAt ? toLocalInput(row.startAt) : "",
  checkOut: row.checkOutAt ? toLocalInput(row.checkOutAt) : row.entryId === null && row.endAt ? toLocalInput(row.endAt) : "",
  reason: "",
});

export type DraftError = "reason_required" | "times_required" | "out_before_in";

export const draftError = (draft: EntryDraft): DraftError | null => {
  if (!draft.checkIn) return "times_required";
  if (draft.checkOut && draft.checkOut < draft.checkIn) return "out_before_in";
  if (!draft.reason.trim()) return "reason_required";
  return null;
};

export const toEditInput = (id: string, assignmentId: string | null, draft: EntryDraft): EditEntryInput => ({
  id,
  checkInAt: fromLocalInput(draft.checkIn),
  checkOutAt: draft.checkOut ? fromLocalInput(draft.checkOut) : null,
  assignmentId,
  reason: draft.reason.trim(),
});

export const toAddInput = (branchId: string, userId: string, assignmentId: string | null, draft: EntryDraft): AddEntryInput => ({
  branchId,
  userId,
  checkInAt: fromLocalInput(draft.checkIn),
  checkOutAt: draft.checkOut ? fromLocalInput(draft.checkOut) : null,
  assignmentId,
  reason: draft.reason.trim(),
});
