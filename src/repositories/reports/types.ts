// Types of the revenue reports. Pure TS: no Vue.

/** The filter every report tab shares. `branchId` null = every branch the caller may see. */
export type ReportFilter = {
  branchId: string | null;
  /** First day, yyyy-MM-dd (Vietnam time). */
  from: string;
  /** Last day, yyyy-MM-dd, included. */
  to: string;
};

export type Bucket = "day" | "week" | "month";

/** The longest range a report accepts (the database refuses more). */
export const MAX_REPORT_DAYS = 366;

/** The most rows one export fetches. */
export const EXPORT_LIMIT = 5000;

export type OverviewComparison = {
  netRevenue: number;
  invoiceCount: number;
  avgTicket: number;
  refunds: number;
};

export type ReportOverview = {
  gross: number;
  discount: number;
  netSales: number;
  refunds: number;
  netRevenue: number;
  invoiceCount: number;
  avgTicket: number;
  cancelledCount: number;
  cancelledAmount: number;
  returnCount: number;
  segments: { shop: number; spa: number; spaAppointment: number; spaWalkIn: number };
  payments: { cash: number; transfer: number; card: number; refundCash: number; refundTransfer: number };
  /** Estimated gross profit of goods (spa has no cost). */
  grossProfit: number;
  missingCostLines: number;
  previous: OverviewComparison;
};

export type SeriesPoint = {
  /** First day of the bucket, yyyy-MM-dd. */
  bucket: string;
  invoiceCount: number;
  gross: number;
  discount: number;
  netSales: number;
  refunds: number;
  netRevenue: number;
  shop: number;
  spa: number;
  cash: number;
  transfer: number;
  card: number;
};
