import type { CheckInPetInput, KennelType, StayPet } from "@/types/boarding";

/** One pet of the check-in form; the weight is typed text until it is sent. */
export type CheckInPetDraft = {
  stayPetId: string;
  petName: string;
  kennelTypeId: string;
  weight: string;
  vaccineChecked: boolean;
  vaccineNote: string;
  belongings: string;
  feeding: string;
  medication: string;
};

export const checkInDraftOf = (pet: StayPet): CheckInPetDraft => ({
  stayPetId: pet.id,
  petName: pet.petName,
  kennelTypeId: pet.kennelTypeId,
  weight: pet.weightKg === null ? "" : String(pet.weightKg),
  vaccineChecked: pet.vaccineChecked,
  vaccineNote: pet.vaccineNote ?? "",
  belongings: pet.belongings ?? "",
  feeding: pet.feeding ?? "",
  medication: pet.medication ?? "",
});

export const weightOf = (draft: CheckInPetDraft): number => {
  const value = Number(draft.weight.replace(",", "."));
  return Number.isFinite(value) && value > 0 ? value : 0;
};

export const isCheckInComplete = (drafts: CheckInPetDraft[]): boolean =>
  drafts.length > 0 && drafts.every((draft) => weightOf(draft) > 0);

/** Heavier than the kennel type allows: a warning, never a block (the scale may be off). */
export const isOverweight = (draft: CheckInPetDraft, types: KennelType[]): boolean => {
  const max = types.find((type) => type.id === draft.kennelTypeId)?.maxWeightKg ?? null;
  return max !== null && weightOf(draft) > max;
};

export const toCheckInInput = (draft: CheckInPetDraft): CheckInPetInput => ({
  stayPetId: draft.stayPetId,
  weightKg: weightOf(draft),
  vaccineChecked: draft.vaccineChecked,
  vaccineNote: draft.vaccineNote,
  belongings: draft.belongings,
  feeding: draft.feeding,
  medication: draft.medication,
});
