// Row mappers of the report RPCs: snake_case JSON from the database to camelCase numbers.
import type { Json } from "@/types/database.types";
import type { OverviewComparison, ReportOverview, SeriesPoint } from "./types";

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
