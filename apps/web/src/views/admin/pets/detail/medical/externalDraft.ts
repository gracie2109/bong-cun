import type { ExternalVaccineInput } from "@bongcun/core/medical";
import { todayKey } from "@/views/admin/medical/format";

export type ExternalDraft = {
  typeId: string;
  givenOn: string;
  place: string;
  lotNo: string;
  expiryDate: string;
  doseNo: string;
  nextDueOn: string;
  dueEdited: boolean;
};

export const emptyExternalDraft = (): ExternalDraft => ({
  typeId: "",
  givenOn: todayKey(),
  place: "",
  lotNo: "",
  expiryDate: "",
  doseNo: "",
  nextDueOn: "",
  dueEdited: false,
});

export const toExternalInput = (draft: ExternalDraft): ExternalVaccineInput => ({
  vaccineTypeId: draft.typeId,
  givenOn: draft.givenOn,
  externalPlace: draft.place.trim(),
  lotNo: draft.lotNo.trim(),
  expiryDate: draft.expiryDate,
  doseNo: draft.doseNo.trim() ? Number(draft.doseNo) : null,
  nextDueOn: draft.nextDueOn || null,
});
