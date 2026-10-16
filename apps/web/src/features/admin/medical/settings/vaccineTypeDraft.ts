import type { VaccineKind, VaccineType, VaccineTypeInput } from "@bongcun/core/medical";

/** The stock item picked for a vaccine type. */
export type PickedProduct = { id: string; name: string; unit: string | null };

/** What the user typed for a vaccine type; numbers stay text while they are edited. */
export type VaccineTypeDraft = {
  name: string;
  kind: VaccineKind;
  speciesIds: string[];
  product: PickedProduct | null;
  seriesDoses: string;
  seriesIntervalDays: string;
  boosterIntervalDays: string;
  minAgeWeeks: string;
  isActive: boolean;
  sortOrder: string;
};

const text = (value: number | null | undefined): string => (value === null || value === undefined ? "" : String(value));

/** A number from a text box; null when empty or not a number. */
const toNumber = (value: string): number | null => {
  if (value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
};

export const emptyVaccineTypeDraft = (): VaccineTypeDraft => ({
  name: "",
  kind: "vaccine",
  speciesIds: [],
  product: null,
  seriesDoses: "1",
  seriesIntervalDays: "",
  boosterIntervalDays: "365",
  minAgeWeeks: "",
  isActive: true,
  sortOrder: "0",
});

export const draftFromVaccineType = (type: VaccineType): VaccineTypeDraft => ({
  name: type.name,
  kind: type.kind,
  speciesIds: [...type.speciesIds],
  product: type.productId ? { id: type.productId, name: type.productName ?? "", unit: type.productUnit } : null,
  seriesDoses: String(type.seriesDoses),
  seriesIntervalDays: text(type.seriesIntervalDays),
  boosterIntervalDays: text(type.boosterIntervalDays),
  minAgeWeeks: text(type.minAgeWeeks),
  isActive: type.isActive,
  sortOrder: String(type.sortOrder),
});

/** Why the draft cannot be saved yet, or null when it can. */
export const vaccineTypeDraftError = (draft: VaccineTypeDraft): "name" | "doses" | "gap" | "booster" | "age" | null => {
  if (!draft.name.trim()) return "name";
  const doses = toNumber(draft.seriesDoses);
  if (doses === null || !Number.isInteger(doses) || doses < 1 || doses > 10) return "doses";
  const gap = toNumber(draft.seriesIntervalDays);
  if (doses > 1 && (gap === null || gap < 1)) return "gap";
  const booster = toNumber(draft.boosterIntervalDays);
  if (draft.boosterIntervalDays.trim() !== "" && (booster === null || booster < 1)) return "booster";
  const age = toNumber(draft.minAgeWeeks);
  if (draft.minAgeWeeks.trim() !== "" && (age === null || age < 0)) return "age";
  return null;
};

export const vaccineTypeInputFromDraft = (draft: VaccineTypeDraft): VaccineTypeInput => {
  const doses = toNumber(draft.seriesDoses) ?? 1;
  return {
    name: draft.name.trim(),
    kind: draft.kind,
    speciesIds: draft.speciesIds,
    productId: draft.product?.id ?? null,
    seriesDoses: doses,
    seriesIntervalDays: doses > 1 ? toNumber(draft.seriesIntervalDays) : null,
    boosterIntervalDays: toNumber(draft.boosterIntervalDays),
    minAgeWeeks: toNumber(draft.minAgeWeeks),
    isActive: draft.isActive,
    sortOrder: toNumber(draft.sortOrder) ?? 0,
  };
};
