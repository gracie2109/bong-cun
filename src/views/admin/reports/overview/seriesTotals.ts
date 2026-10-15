import type { SeriesPoint } from "@/repositories/reports";

export type SeriesTotals = Omit<SeriesPoint, "bucket">;

const EMPTY: SeriesTotals = {
  invoiceCount: 0,
  gross: 0,
  discount: 0,
  netSales: 0,
  refunds: 0,
  netRevenue: 0,
  shop: 0,
  spa: 0,
  boarding: 0,
  cash: 0,
  transfer: 0,
  card: 0,
};

/** The sum of every bucket; it equals the KPI figures of the whole range. */
export const sumSeries = (points: readonly SeriesPoint[]): SeriesTotals =>
  points.reduce<SeriesTotals>(
    (total, point) => ({
      invoiceCount: total.invoiceCount + point.invoiceCount,
      gross: total.gross + point.gross,
      discount: total.discount + point.discount,
      netSales: total.netSales + point.netSales,
      refunds: total.refunds + point.refunds,
      netRevenue: total.netRevenue + point.netRevenue,
      shop: total.shop + point.shop,
      spa: total.spa + point.spa,
      boarding: total.boarding + point.boarding,
      cash: total.cash + point.cash,
      transfer: total.transfer + point.transfer,
      card: total.card + point.card,
    }),
    { ...EMPTY }
  );
