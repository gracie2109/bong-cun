// Row mappers of the report RPCs: snake_case JSON from the database to camelCase numbers.
import type { Json } from "@/types/database.types";
import type { Adjustment, OverviewComparison, ReportOverview, SeriesPoint, ShiftRecon, StaffRevenue, TopItem } from "./types";

export const num = (value: unknown): number => Number(value ?? 0);

type Obj = Record<string, unknown>;

/** A JSON value as an object; anything else reads as an empty one. */
export const asObj = (value: unknown): Obj =>
  value && typeof value === "object" && !Array.isArray(value) ? (value as Obj) : {};

const toComparison = (raw: Obj): OverviewComparison => ({
  netRevenue: num(raw.net_revenue),
  invoiceCount: num(raw.invoice_count),
  avgTicket: num(raw.avg_ticket),
  refunds: num(raw.refunds),
});

export const toOverview = (json: Json | null): ReportOverview => {
  const raw = asObj(json);
  const segments = asObj(raw.segments);
  const payments = asObj(raw.payments);
  return {
    gross: num(raw.gross),
    discount: num(raw.discount),
    netSales: num(raw.net_sales),
    refunds: num(raw.refunds),
    netRevenue: num(raw.net_revenue),
    invoiceCount: num(raw.invoice_count),
    avgTicket: num(raw.avg_ticket),
    cancelledCount: num(raw.cancelled_count),
    cancelledAmount: num(raw.cancelled_amount),
    returnCount: num(raw.return_count),
    segments: {
      shop: num(segments.shop),
      spa: num(segments.spa),
      spaAppointment: num(segments.spa_appointment),
      spaWalkIn: num(segments.spa_walk_in),
    },
    payments: {
      cash: num(payments.cash),
      transfer: num(payments.transfer),
      card: num(payments.card),
      cod: num(payments.cod),
      refundCash: num(payments.refund_cash),
      refundTransfer: num(payments.refund_transfer),
    },
    grossProfit: num(raw.gross_profit),
    missingCostLines: num(raw.missing_cost_lines),
    previous: toComparison(asObj(raw.previous)),
  };
};

type SeriesRow = {
  bucket: string;
  invoice_count: number;
  gross: number;
  discount: number;
  net_sales: number;
  refunds: number;
  net_revenue: number;
  shop: number;
  spa: number;
  cash: number;
  transfer: number;
  card: number;
};

export const toSeriesPoint = (row: SeriesRow): SeriesPoint => ({
  bucket: row.bucket,
  invoiceCount: num(row.invoice_count),
  gross: num(row.gross),
  discount: num(row.discount),
  netSales: num(row.net_sales),
  refunds: num(row.refunds),
  netRevenue: num(row.net_revenue),
  shop: num(row.shop),
  spa: num(row.spa),
  cash: num(row.cash),
  transfer: num(row.transfer),
  card: num(row.card),
});

type TopItemRow = {
  item_type: string;
  item_id: string;
  name: string;
  sku: string | null;
  unit: string | null;
  qty_sold: number;
  qty_returned: number;
  invoice_count: number;
  net_revenue: number;
  refunds: number;
  cost: number | null;
  gross_profit: number | null;
  share: number;
};

const nullableNum = (value: number | null): number | null => (value === null ? null : num(value));

export const toTopItem = (row: TopItemRow): TopItem => ({
  itemType: row.item_type,
  itemId: row.item_id,
  name: row.name,
  sku: row.sku,
  unit: row.unit,
  qtySold: num(row.qty_sold),
  qtyReturned: num(row.qty_returned),
  invoiceCount: num(row.invoice_count),
  netRevenue: num(row.net_revenue),
  refunds: num(row.refunds),
  cost: nullableNum(row.cost),
  grossProfit: nullableNum(row.gross_profit),
  share: num(row.share),
});

type StaffRow = {
  staff_id: string | null;
  name: string | null;
  invoice_count: number | null;
  ticket_count: number | null;
  pet_count: number | null;
  net_sales: number;
  refunds: number | null;
  cancelled_count: number | null;
  avg_ticket: number | null;
  share: number | null;
};

export const toStaffRevenue = (row: StaffRow): StaffRevenue => ({
  staffId: row.staff_id,
  name: row.name,
  netSales: num(row.net_sales),
  invoiceCount: num(row.invoice_count),
  refunds: num(row.refunds),
  cancelledCount: num(row.cancelled_count),
  avgTicket: num(row.avg_ticket),
  ticketCount: num(row.ticket_count),
  petCount: num(row.pet_count),
  share: num(row.share),
});

type AdjustmentRow = {
  kind: string;
  id: string;
  branch_id: string;
  code: string;
  invoice_id: string;
  invoice_code: string;
  at: string;
  amount: number;
  method: string | null;
  reason: string | null;
  by_name: string | null;
  item_summary: string | null;
};

export const toAdjustment = (row: AdjustmentRow): Adjustment => ({
  kind: row.kind === "cancel" ? "cancel" : "return",
  id: row.id,
  branchId: row.branch_id,
  code: row.code,
  invoiceId: row.invoice_id,
  invoiceCode: row.invoice_code,
  at: row.at,
  amount: num(row.amount),
  method: row.method,
  reason: row.reason,
  byName: row.by_name,
  itemSummary: row.item_summary,
});

type ShiftRow = {
  id: string;
  code: string;
  branch_code: string;
  status: string;
  opened_by_name: string | null;
  opened_at: string;
  closed_by_name: string | null;
  closed_at: string | null;
  opening_cash: number;
  invoice_count: number;
  sales_total: number;
  cash_in: number;
  transfer_in: number;
  card_in: number;
  refund_cash: number;
  expected_cash: number | null;
  counted_cash: number | null;
  difference: number | null;
};

export const toShiftRecon = (row: ShiftRow): ShiftRecon => ({
  id: row.id,
  code: row.code,
  branchCode: row.branch_code,
  status: row.status === "closed" ? "closed" : "open",
  openedByName: row.opened_by_name,
  openedAt: row.opened_at,
  closedByName: row.closed_by_name,
  closedAt: row.closed_at,
  openingCash: num(row.opening_cash),
  invoiceCount: num(row.invoice_count),
  salesTotal: num(row.sales_total),
  cashIn: num(row.cash_in),
  transferIn: num(row.transfer_in),
  cardIn: num(row.card_in),
  refundCash: num(row.refund_cash),
  expectedCash: nullableNum(row.expected_cash),
  countedCash: nullableNum(row.counted_cash),
  difference: nullableNum(row.difference),
});
