import type { ItemDirections, ItemInput } from "@bongcun/core/medical";

/** What the vet fills in to add a medicine (from stock or bought elsewhere). */
export type DrugDraft = ItemDirections & {
  source: "stock" | "external";
  productId: string;
  productName: string;
  /** Name of a medicine bought elsewhere. */
  externalName: string;
  qty: string;
  allergyChecked: boolean;
};

export const emptyDrugDraft = (): DrugDraft => ({
  source: "stock",
  productId: "",
  productName: "",
  externalName: "",
  qty: "1",
  takeHome: false,
  dose: "",
  frequency: "",
  days: null,
  route: "",
  instructions: "",
  allergyChecked: false,
});

const qtyOf = (draft: DrugDraft): number => {
  const value = Number(draft.qty.replace(",", "."));
  return Number.isFinite(value) ? value : 0;
};

export const isDrugDraftComplete = (draft: DrugDraft, petHasAllergy: boolean): boolean => {
  if (qtyOf(draft) <= 0) return false;
  if (draft.source === "external") return draft.externalName.trim() !== "";
  return draft.productId !== "" && (!petHasAllergy || draft.allergyChecked);
};

export const toDrugInput = (draft: DrugDraft): ItemInput => ({
  kind: draft.source === "external" ? "external" : "product",
  productId: draft.source === "stock" ? draft.productId : undefined,
  name: draft.source === "external" ? draft.externalName.trim() : undefined,
  qty: qtyOf(draft),
  takeHome: draft.source === "external" ? true : draft.takeHome,
  dose: draft.dose,
  frequency: draft.frequency,
  days: draft.days,
  route: draft.route,
  instructions: draft.instructions,
});
