import type { PetCombo } from "@/repositories/petCombos";

/** Values of `status` stored on a combo. */
export const STATUS_SELLING = 1;
export const STATUS_STOPPED = 2;

/** Promotion marks a combo can carry; the default one shows no badge. */
export const COMBO_MARKS = ["1", "2", "3", "4"];
export const DEFAULT_MARK = "4";

export type ComboStatus = "selling" | "stopped" | "expired";

/** A selling combo whose promotion window has ended counts as expired. */
export const comboStatus = (combo: PetCombo): ComboStatus => {
  if (combo.status !== STATUS_SELLING) return "stopped";
  const end = combo.markTime[1];
  return end && new Date(end).getTime() < Date.now() ? "expired" : "selling";
};

export const COMBO_STATUS_CLASS: Record<ComboStatus, string> = {
  selling: "bg-green-100 text-green-700",
  stopped: "bg-muted text-muted-foreground",
  expired: "bg-amber-100 text-amber-700",
};
