import type { CustomerPet } from "@/repositories/pos";
import type { BoardingRules, BoardingStay, KennelType, StayInput } from "@/types/boarding";
import { addDays, dateKeyOf, timeOf, toIso, todayKey } from "../format";

/** Choice values of the selects that also have a "none" entry. */
export const AUTO = "auto";
export const NONE = "none";

export type PetDraft = {
  key: number;
  petId: string;
  kennelTypeId: string;
  /** A kennel id, or AUTO to let the database pick a free one. */
  kennelId: string;
  /** The 1-based line of an earlier pet to share its kennel with, or NONE. */
  shareWith: string;
  feeding: string;
  medication: string;
  belongings: string;
};

export type StayDraft = {
  inDate: string;
  inTime: string;
  outDate: string;
  outTime: string;
  source: "counter" | "phone";
  emergencyPhone: string;
  note: string;
  pets: PetDraft[];
};

let nextKey = 1;

export const newPetDraft = (patch: Partial<PetDraft> = {}): PetDraft => ({
  key: nextKey++,
  petId: "",
  kennelTypeId: "",
  kennelId: AUTO,
  shareWith: NONE,
  feeding: "",
  medication: "",
  belongings: "",
  ...patch,
});

/** Where a click on the board started the booking. */
export type StayPrefill = { date?: string; kennelId?: string; kennelTypeId?: string };

const DEFAULT_IN_TIME = "09:00";
const DEFAULT_OUT_TIME = "11:00";

export const emptyStayDraft = (rules: BoardingRules | undefined, prefill?: StayPrefill): StayDraft => {
  const inDate = prefill?.date ?? todayKey();
  return {
    inDate,
    inTime: rules?.checkInFrom && rules.checkInFrom > DEFAULT_IN_TIME ? rules.checkInFrom : DEFAULT_IN_TIME,
    outDate: addDays(inDate, 1),
    outTime: rules?.checkOutBy ?? DEFAULT_OUT_TIME,
    source: "counter",
    emergencyPhone: "",
    note: "",
    pets: [newPetDraft({ kennelTypeId: prefill?.kennelTypeId ?? "", kennelId: prefill?.kennelId ?? AUTO })],
  };
};

/** The form of an existing booked stay. */
export const draftFromStay = (stay: BoardingStay): StayDraft => {
  const active = stay.pets.filter((pet) => pet.status === "active");
  return {
    inDate: dateKeyOf(stay.plannedInAt),
    inTime: timeOf(stay.plannedInAt),
    outDate: dateKeyOf(stay.plannedOutAt),
    outTime: timeOf(stay.plannedOutAt),
    source: stay.source === "phone" ? "phone" : "counter",
    emergencyPhone: stay.emergencyPhone ?? "",
    note: stay.note ?? "",
    pets: active.map((pet, index) => {
      // A pet in the kennel of an earlier line shares it.
      const owner = active.findIndex((other) => other.kennelId === pet.kennelId);
      return newPetDraft({
        petId: pet.petId,
        kennelTypeId: pet.kennelTypeId,
        kennelId: pet.kennelId,
        shareWith: owner >= 0 && owner < index ? String(owner + 1) : NONE,
        feeding: pet.feeding ?? "",
        medication: pet.medication ?? "",
        belongings: pet.belongings ?? "",
      });
    }),
  };
};

/** Types that take a pet's species. */
export const typesForPet = (types: KennelType[], pet: CustomerPet | undefined): KennelType[] =>
  types.filter((type) => !pet || type.speciesIds.length === 0 || type.speciesIds.includes(pet.speciesId));

export const isPetDraftComplete = (pet: PetDraft): boolean => !!pet.petId && !!pet.kennelTypeId;

/** Whether the dates and every pet are filled in enough to ask the database for a quote. */
export const isStayDraftComplete = (draft: StayDraft): boolean =>
  !!draft.inDate && !!draft.inTime && !!draft.outDate && !!draft.outTime &&
  toIso(draft.outDate, draft.outTime) > toIso(draft.inDate, draft.inTime) &&
  draft.pets.length > 0 && draft.pets.every(isPetDraftComplete) &&
  new Set(draft.pets.map((pet) => pet.petId)).size === draft.pets.length;

export const toStayInput = (customerId: string, draft: StayDraft): StayInput => ({
  customerId,
  plannedInAt: toIso(draft.inDate, draft.inTime),
  plannedOutAt: toIso(draft.outDate, draft.outTime),
  source: draft.source,
  emergencyPhone: draft.emergencyPhone,
  note: draft.note,
  pets: draft.pets.map((pet) => ({
    petId: pet.petId,
    kennelTypeId: pet.kennelTypeId,
    kennelId: pet.kennelId === AUTO ? null : pet.kennelId,
    shareWith: pet.shareWith === NONE ? null : Number(pet.shareWith),
    feeding: pet.feeding,
    medication: pet.medication,
    belongings: pet.belongings,
  })),
});
