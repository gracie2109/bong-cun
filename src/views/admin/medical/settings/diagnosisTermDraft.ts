import type { DiagnosisTerm, DiagnosisTermInput } from "@/types/medical";

/** What the user typed for a diagnosis; the sort order stays text while it is edited. */
export type DiagnosisTermDraft = {
  name: string;
  speciesIds: string[];
  isContagious: boolean;
  isActive: boolean;
  sortOrder: string;
};

export const emptyDiagnosisTermDraft = (): DiagnosisTermDraft => ({
  name: "",
  speciesIds: [],
  isContagious: false,
  isActive: true,
  sortOrder: "0",
});

export const draftFromDiagnosisTerm = (term: DiagnosisTerm): DiagnosisTermDraft => ({
  name: term.name,
  speciesIds: [...term.speciesIds],
  isContagious: term.isContagious,
  isActive: term.isActive,
  sortOrder: String(term.sortOrder),
});

export const diagnosisTermInputFromDraft = (draft: DiagnosisTermDraft): DiagnosisTermInput => ({
  name: draft.name.trim(),
  speciesIds: draft.speciesIds,
  isContagious: draft.isContagious,
  isActive: draft.isActive,
  sortOrder: Number(draft.sortOrder) || 0,
});
