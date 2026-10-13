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

export type ItemKind = "all" | "product" | "service";
export type ItemSort = "revenue" | "qty" | "profit";

export type TopItemFilter = ReportFilter & {
  kind: ItemKind;
  search?: string;
  sort: ItemSort;
};

export type TopItem = {
  /** "product", "service" or "combo". */
  itemType: string;
  itemId: string;
  name: string;
  sku: string | null;
  unit: string | null;
  qtySold: number;
  qtyReturned: number;
  invoiceCount: number;
  netRevenue: number;
  refunds: number;
  /** Null for services and combos: they have no cost. */
  cost: number | null;
  grossProfit: number | null;
  /** Share of all sales in the range, in percent. */
  share: number;
};

export type StaffRole = "cashier" | "spa";

export type StaffFilter = ReportFilter & { role: StaffRole; search?: string };

export type StaffRevenue = {
  /** Null on the spa list = tickets with no staff member assigned. */
  staffId: string | null;
  name: string | null;
  netSales: number;
  /** Cashier columns. */
  invoiceCount: number;
  refunds: number;
  cancelledCount: number;
  avgTicket: number;
  /** Spa columns. */
  ticketCount: number;
  petCount: number;
  /** Percent of all spa revenue (spa list only). */
  share: number;
};
