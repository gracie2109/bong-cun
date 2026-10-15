import type { CheckInInput, MedicalVisit, ScheduleInput } from "@/types/medicalVisit";
import { addDays, toIso, todayKey } from "../format";

/** Select value for "no vet yet". */
export const NO_VET = "none";

export type CheckInMode = "now" | "book";

export type CheckInDraft = {
  mode: CheckInMode;
  petId: string;
  reason: string;
  urgent: boolean;
  vetId: string;
  /** Typed numbers stay text until saved. */
  weight: string;
  temperature: string;
  date: string;
  time: string;
};

export const emptyCheckInDraft = (): CheckInDraft => ({
  mode: "now",
  petId: "",
  reason: "",
  urgent: false,
  vetId: NO_VET,
  weight: "",
  temperature: "",
  date: addDays(todayKey(), 1),
  time: "09:00",
});

/** The draft of a booked visit that is arriving. */
export const draftFromVisit = (visit: MedicalVisit): CheckInDraft => ({
  ...emptyCheckInDraft(),
  petId: visit.petId,
  reason: visit.reason ?? "",
  urgent: visit.priority === "urgent",
  vetId: visit.vetId ?? NO_VET,
  weight: visit.weightKg ? String(visit.weightKg) : "",
});

const numberOrNull = (text: string): number | null => {
  const value = Number(text.replace(",", "."));
  return text.trim() !== "" && Number.isFinite(value) && value > 0 ? value : null;
};

const vetOf = (draft: CheckInDraft): string | null => (draft.vetId === NO_VET ? null : draft.vetId);

export const isCheckInDraftComplete = (draft: CheckInDraft): boolean =>
  !!draft.petId && (draft.mode === "now" || (!!draft.date && !!draft.time));

export const toCheckInInput = (branchId: string, customerId: string, draft: CheckInDraft, visitId?: string): CheckInInput => ({
  branchId,
  customerId,
  petId: draft.petId,
  reason: draft.reason.trim(),
  priority: draft.urgent ? "urgent" : "normal",
  vetId: vetOf(draft),
  weightKg: numberOrNull(draft.weight),
  temperatureC: numberOrNull(draft.temperature),
  visitId,
});

export const toScheduleInput = (branchId: string, customerId: string, draft: CheckInDraft): ScheduleInput => ({
  branchId,
  customerId,
  petId: draft.petId,
  scheduledAt: toIso(draft.date, draft.time),
  reason: draft.reason.trim(),
  vetId: vetOf(draft),
});
