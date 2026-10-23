import type { ReportOverview } from "@bongcun/supabase/reports";

export type SalesPeriod = "today" | "last7" | "thisMonth";
export const SALES_PERIODS: readonly SalesPeriod[] = ["today", "last7", "thisMonth"];

export type SegmentRow = { key: "shop" | "spa" | "boarding" | "medical"; value: number };

/** The four lines of business as the report tab shows them (no figure is derived here). */
export const segmentRows = (overview: ReportOverview): SegmentRow[] => [
  { key: "shop", value: overview.segments.shop },
  { key: "spa", value: overview.segments.spa },
  { key: "boarding", value: overview.segments.boarding },
  { key: "medical", value: overview.segments.medical },
];
