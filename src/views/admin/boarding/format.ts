import type { KennelStatus } from "@/types/boarding";

export { money } from "@/views/admin/pos/format";

/** Badge colours of the physical state of a kennel. */
export const KENNEL_STATUS_TONE: Record<KennelStatus, string> = {
  ready: "bg-emerald-100 text-emerald-800",
  cleaning: "bg-amber-100 text-amber-800",
  maintenance: "bg-slate-200 text-slate-700",
};
