import type { BranchKennelPrice, KennelType, KennelTypeInput } from "@/types/boarding";

/** What the user typed for one branch's own price; numbers stay text while they are edited. */
export type BranchPriceDraft = { enabled: boolean; nightPrice: string; extraPetNightPrice: string };

export type KennelTypeDraft = {
  name: string;
  description: string;
  speciesIds: string[];
  maxWeightKg: string;
  maxPets: string;
  sharedNightPrice: string;
  sharedExtraPetNightPrice: string;
  isActive: boolean;
  isPublic: boolean;
  sortOrder: string;
  /** Keyed by branch id. */
  branchPrices: Record<string, BranchPriceDraft>;
};

const text = (value: number | null | undefined): string => (value === null || value === undefined ? "" : String(value));

/** A number from a text box; null when empty or not a number. */
export const toNumber = (value: string): number | null => {
  if (value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

export const emptyKennelTypeDraft = (): KennelTypeDraft => ({
  name: "",
  description: "",
  speciesIds: [],
  maxWeightKg: "",
  maxPets: "1",
  sharedNightPrice: "",
  sharedExtraPetNightPrice: "",
  isActive: true,
  isPublic: true,
  sortOrder: "0",
  branchPrices: {},
});

export const draftFromKennelType = (type: KennelType): KennelTypeDraft => ({
  name: type.name,
  description: type.description ?? "",
  speciesIds: [...type.speciesIds],
  maxWeightKg: text(type.maxWeightKg),
  maxPets: String(type.maxPets),
  sharedNightPrice: text(type.sharedNightPrice),
  sharedExtraPetNightPrice: text(type.sharedExtraPetNightPrice),
  isActive: type.isActive,
  isPublic: type.isPublic,
  sortOrder: String(type.sortOrder),
  branchPrices: Object.fromEntries(
    type.branchPrices.map((price: BranchKennelPrice) => [
      price.branchId,
      { enabled: true, nightPrice: text(price.nightPrice), extraPetNightPrice: text(price.extraPetNightPrice) },
    ])
  ),
});

/** Why the draft cannot be saved yet, or null when it can. */
export const kennelTypeDraftError = (draft: KennelTypeDraft): "name" | "price" | "pets" | null => {
  if (!draft.name.trim()) return "name";
  const price = toNumber(draft.sharedNightPrice);
  if (price === null || price < 0) return "price";
  const pets = toNumber(draft.maxPets);
  if (pets === null || pets < 1 || !Number.isInteger(pets)) return "pets";
  const overrides = Object.values(draft.branchPrices).filter((item) => item.enabled);
  if (overrides.some((item) => (toNumber(item.nightPrice) ?? -1) < 0)) return "price";
  return null;
};

export const kennelTypeInputFromDraft = (draft: KennelTypeDraft, photoUrl: string | null): KennelTypeInput => ({
  name: draft.name.trim(),
  description: draft.description.trim() || null,
  photoUrl,
  speciesIds: draft.speciesIds,
  maxWeightKg: toNumber(draft.maxWeightKg),
  maxPets: toNumber(draft.maxPets) ?? 1,
  isActive: draft.isActive,
  isPublic: draft.isPublic,
  sortOrder: toNumber(draft.sortOrder) ?? 0,
  sharedNightPrice: toNumber(draft.sharedNightPrice) ?? 0,
  sharedExtraPetNightPrice: toNumber(draft.sharedExtraPetNightPrice),
  branchPrices: Object.entries(draft.branchPrices)
    .filter(([, price]) => price.enabled)
    .map(([branchId, price]) => ({
      branchId,
      nightPrice: toNumber(price.nightPrice) ?? 0,
      extraPetNightPrice: toNumber(price.extraPetNightPrice),
    })),
});
