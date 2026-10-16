import type { KennelState, KennelStatus, StayStatus } from "@bongcun/core/boarding";

export { dateTime, money } from "@/features/admin/pos/format";
export { addDays, dateKeyOf, timeOf, todayKey, toIso } from "@/features/admin/schedule/format";

/** Badge colours of the physical state of a kennel. */
export const KENNEL_STATUS_TONE: Record<KennelStatus, string> = {
  ready: "bg-emerald-100 text-emerald-800",
  cleaning: "bg-amber-100 text-amber-800",
  maintenance: "bg-slate-200 text-slate-700",
};

/** Badge colours of a stay's status. */
export const STAY_TONE: Record<StayStatus, string> = {
  booked: "bg-sky-100 text-sky-800",
  checked_in: "bg-emerald-100 text-emerald-800",
  checked_out: "bg-amber-100 text-amber-800",
  paid: "bg-slate-200 text-slate-700",
  cancelled: "bg-red-100 text-red-700",
  no_show: "bg-red-100 text-red-700",
};

/** Card colours of a kennel on the day board. */
export const KENNEL_STATE_TONE: Record<KennelState, string> = {
  free: "border-emerald-200 bg-emerald-50/60",
  arriving: "border-sky-200 bg-sky-50",
  occupied: "border-primary/30 bg-primary/5",
  departing: "border-amber-300 bg-amber-50",
  overdue: "border-red-300 bg-red-50",
  cleaning: "border-yellow-300 bg-yellow-50",
  maintenance: "border-slate-300 bg-slate-100",
};

export const KENNEL_STATE_DOT: Record<KennelState, string> = {
  free: "bg-emerald-500",
  arriving: "bg-sky-500",
  occupied: "bg-primary",
  departing: "bg-amber-500",
  overdue: "bg-red-500",
  cleaning: "bg-yellow-500",
  maintenance: "bg-slate-400",
};

/** Whole nights between two yyyy-MM-dd dates; a same-day stay shows as 1. */
export const nightsBetween = (from: string, to: string): number => {
  const days = Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86_400_000);
  return Math.max(days, 1);
};
