import { SHIFT_COLORS, shiftLengthMinutes, toMinutes } from "@bongcun/core/attendance";
import type { ShiftColor, ShiftTemplate, ShiftTemplateInput } from "@bongcun/core/attendance";

/** What is typed in the template form; numbers stay text while they are edited. */
export type TemplateDraft = {
  name: string;
  startTime: string;
  endTime: string;
  breakMinutes: string;
  color: ShiftColor;
};

export const emptyTemplateDraft = (): TemplateDraft => ({ name: "", startTime: "08:00", endTime: "14:00", breakMinutes: "0", color: "teal" });

export const draftFromTemplate = (template: ShiftTemplate): TemplateDraft => ({
  name: template.name,
  startTime: template.startTime,
  endTime: template.endTime,
  breakMinutes: String(template.breakMinutes),
  color: template.color,
});

const breakOf = (draft: TemplateDraft): number => Number(draft.breakMinutes.trim() === "" ? 0 : draft.breakMinutes);

/** The i18n key (under `attendance.templates.errors`) of the first problem, or null when the form is valid. */
export const templateDraftError = (draft: TemplateDraft): string | null => {
  const name = draft.name.trim();
  if (name.length < 1 || name.length > 40) return "name";
  if (Number.isNaN(toMinutes(draft.startTime)) || Number.isNaN(toMinutes(draft.endTime))) return "times";
  if (draft.startTime === draft.endTime) return "same";
  const length = shiftLengthMinutes(draft.startTime, draft.endTime);
  if (length > 960) return "long";
  const rest = breakOf(draft);
  if (!Number.isInteger(rest) || rest < 0 || rest >= length) return "break";
  return SHIFT_COLORS.includes(draft.color) ? null : "color";
};

export const templateInputFromDraft = (draft: TemplateDraft, id?: string): ShiftTemplateInput => ({
  id,
  name: draft.name.trim(),
  startTime: draft.startTime,
  endTime: draft.endTime,
  breakMinutes: breakOf(draft),
  color: draft.color,
});
