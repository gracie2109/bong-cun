import type { GiveVaccineInput } from "@/types/vaccination";

export type GiveDraft = {
  typeId: string;
  lotId: string;
  /** Text until saved; empty = let the database count. */
  doseNo: string;
  nextDueOn: string;
  /** True once the vet changed the date, so a new choice of type does not overwrite it. */
  dueEdited: boolean;
};

export const emptyGiveDraft = (): GiveDraft => ({ typeId: "", lotId: "", doseNo: "", nextDueOn: "", dueEdited: false });

export const toGiveInput = (draft: GiveDraft): GiveVaccineInput => ({
  vaccineTypeId: draft.typeId,
  lotId: draft.lotId || null,
  doseNo: draft.doseNo.trim() ? Number(draft.doseNo) : null,
  nextDueOn: draft.nextDueOn || null,
});
