import type { VaccineKind } from "@/types/medical";

export { dateTime, money } from "@/views/admin/pos/format";
export { addDays, dateKeyOf, timeOf, todayKey, toIso } from "@/views/admin/schedule/format";

/** Badge colours of the kind of a vaccine type. */
export const VACCINE_KIND_TONE: Record<VaccineKind, string> = {
  vaccine: "bg-sky-100 text-sky-800",
  deworm: "bg-amber-100 text-amber-800",
  other: "bg-slate-200 text-slate-700",
};
