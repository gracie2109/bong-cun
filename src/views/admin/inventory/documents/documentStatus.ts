import type { DocStatus } from "@/repositories/inventory";

/** Badge colors of a stock document's status. */
export const DOC_STATUS_TONE: Record<DocStatus, string> = {
  draft: "bg-amber-50 text-amber-700",
  posted: "bg-primary/10 text-primary",
  cancelled: "bg-red-50 text-red-600",
};
