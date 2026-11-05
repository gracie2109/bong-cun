import type { GridCode } from "@bongcun/core/attendance";

/** Codes in the order the legend lists them. */
export const GRID_CODES: Exclude<GridCode, "">[] = ["X", "X+", "M", "S", "P", "Ô", "K", "N", "V", "?"];

export const CODE_TONE: Record<GridCode, string> = {
  "": "text-muted-foreground",
  X: "bg-emerald-50 text-emerald-800",
  "X+": "bg-teal-50 text-teal-800",
  M: "bg-amber-50 text-amber-900",
  S: "bg-amber-50 text-amber-900",
  P: "bg-sky-50 text-sky-800",
  "Ô": "bg-sky-50 text-sky-800",
  K: "bg-slate-100 text-slate-700",
  N: "bg-sky-50 text-sky-800",
  V: "bg-red-50 text-red-800",
  "?": "bg-red-50 text-red-800",
};
