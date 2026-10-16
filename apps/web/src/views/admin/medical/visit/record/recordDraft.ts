import type { MedicalVisitDetail, RecordInput, VisitOutcome } from "@bongcun/core/medical";

/** The record as the form holds it: numbers stay text until saved. */
export type RecordDraft = {
  weight: string;
  temperature: string;
  heartRate: string;
  respRate: string;
  vitalsNote: string;
  subjective: string;
  objective: string;
  assessment: string;
  plan: string;
  ownerInstructions: string;
  outcome: VisitOutcome | "";
  recheckOn: string;
  diagnoses: { termId: string | null; name: string; isContagious: boolean; note: string }[];
};

const text = (value: number | null): string => (value === null ? "" : String(value));

export const draftFromVisit = (visit: MedicalVisitDetail): RecordDraft => ({
  weight: text(visit.weightKg),
  temperature: text(visit.temperatureC),
  heartRate: text(visit.heartRate),
  respRate: text(visit.respRate),
  vitalsNote: visit.vitalsNote ?? "",
  subjective: visit.subjective ?? "",
  objective: visit.objective ?? "",
  assessment: visit.assessment ?? "",
  plan: visit.plan ?? "",
  ownerInstructions: visit.ownerInstructions ?? "",
  outcome: visit.outcome ?? "",
  recheckOn: visit.recheckOn ?? "",
  diagnoses: visit.diagnoses.map((item) => ({
    termId: item.termId,
    name: item.name,
    isContagious: item.isContagious,
    note: item.note ?? "",
  })),
});

const numberOrNull = (value: string): number | null => {
  const parsed = Number(value.replace(",", "."));
  return value.trim() !== "" && Number.isFinite(parsed) && parsed > 0 ? parsed : null;
};

export const toRecordInput = (draft: RecordDraft): RecordInput => ({
  weightKg: numberOrNull(draft.weight),
  temperatureC: numberOrNull(draft.temperature),
  heartRate: numberOrNull(draft.heartRate),
  respRate: numberOrNull(draft.respRate),
  vitalsNote: draft.vitalsNote,
  subjective: draft.subjective,
  objective: draft.objective,
  assessment: draft.assessment,
  plan: draft.plan,
  ownerInstructions: draft.ownerInstructions,
  outcome: draft.outcome || null,
  recheckOn: draft.outcome === "recheck" ? draft.recheckOn : "",
  diagnoses: draft.diagnoses,
});

/** The vet can sign when there is an outcome and a diagnosis or an assessment (the database checks too). */
export const canSignDraft = (draft: RecordDraft): boolean =>
  !!draft.outcome && (draft.diagnoses.length > 0 || draft.assessment.trim() !== "");
