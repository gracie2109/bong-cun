import type { ShiftColor } from "@bongcun/core/attendance";

/** Full class names, so Tailwind sees them: a chip is the colour of its shift template. */
export const SHIFT_COLOR_CLASS: Record<ShiftColor, { chip: string; dot: string }> = {
  teal: { chip: "border-teal-200 bg-teal-50 text-teal-800", dot: "bg-teal-500" },
  sky: { chip: "border-sky-200 bg-sky-50 text-sky-800", dot: "bg-sky-500" },
  amber: { chip: "border-amber-200 bg-amber-50 text-amber-800", dot: "bg-amber-500" },
  rose: { chip: "border-rose-200 bg-rose-50 text-rose-800", dot: "bg-rose-500" },
  violet: { chip: "border-violet-200 bg-violet-50 text-violet-800", dot: "bg-violet-500" },
  slate: { chip: "border-slate-200 bg-slate-50 text-slate-700", dot: "bg-slate-400" },
};
