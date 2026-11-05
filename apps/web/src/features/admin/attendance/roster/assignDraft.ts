import { timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import { shiftLengthMinutes, toMinutes } from "@bongcun/core/attendance";
import type { AssignShiftInput, RosterAssignment, ShiftTemplate, UpdateShiftInput } from "@bongcun/core/attendance";

/** What is typed in the shift form. `templateId` null means custom hours. */
export type AssignDraft = { templateId: string | null; startTime: string; endTime: string; breakMinutes: string; note: string };

export const emptyAssignDraft = (template?: ShiftTemplate): AssignDraft =>
  template
    ? { templateId: template.id, startTime: template.startTime, endTime: template.endTime, breakMinutes: String(template.breakMinutes), note: "" }
    : { templateId: null, startTime: "08:00", endTime: "17:00", breakMinutes: "0", note: "" };

export const draftFromAssignment = (item: RosterAssignment): AssignDraft => ({
  templateId: item.templateId,
  startTime: timeOf(item.startAt),
  endTime: timeOf(item.endAt),
  breakMinutes: String(item.breakMinutes),
  note: item.note ?? "",
});

/** The same hours as a template, so choosing it fills the fields. */
export const applyTemplate = (draft: AssignDraft, template: ShiftTemplate | null): AssignDraft =>
  template
    ? { ...draft, templateId: template.id, startTime: template.startTime, endTime: template.endTime, breakMinutes: String(template.breakMinutes) }
    : { ...draft, templateId: null };

const breakOf = (draft: AssignDraft): number => Number(draft.breakMinutes.trim() === "" ? 0 : draft.breakMinutes);

/** The i18n key (under `attendance.roster.errors`) of the first problem, or null when the form is valid. */
export const assignDraftError = (draft: AssignDraft): string | null => {
  if (Number.isNaN(toMinutes(draft.startTime)) || Number.isNaN(toMinutes(draft.endTime))) return "times";
  if (draft.startTime === draft.endTime) return "same";
  const length = shiftLengthMinutes(draft.startTime, draft.endTime);
  if (length > 960) return "long";
  const rest = breakOf(draft);
  return !Number.isInteger(rest) || rest < 0 || rest >= length ? "break" : null;
};

export const assignInputFromDraft = (draft: AssignDraft, base: { branchId: string; userId: string; workDate: string }): AssignShiftInput => ({
  ...base,
  templateId: draft.templateId,
  startTime: draft.templateId ? null : draft.startTime,
  endTime: draft.templateId ? null : draft.endTime,
  breakMinutes: breakOf(draft),
  note: draft.note.trim() || null,
});

export const updateInputFromDraft = (draft: AssignDraft, id: string): UpdateShiftInput => ({
  id,
  templateId: draft.templateId,
  startTime: draft.startTime,
  endTime: draft.endTime,
  breakMinutes: breakOf(draft),
  note: draft.note.trim() || null,
});
