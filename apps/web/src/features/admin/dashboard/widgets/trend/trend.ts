import type { SeriesPoint } from "@bongcun/supabase/reports";
import type { ChartPoint } from "@/features/admin/reports";

export type TrendDays = 7 | 30;
export const TREND_DAYS: readonly TrendDays[] = [7, 30];

/** Last `days` days up to and including today, as a report range. */
export const trendRange = (today: string, days: TrendDays): { from: string; to: string } => {
  const end = new Date(`${today}T00:00:00Z`);
  const start = new Date(end.getTime() - (days - 1) * 86_400_000);
  return { from: start.toISOString().slice(0, 10), to: today };
};

export const isTrendEmpty = (points: readonly SeriesPoint[]): boolean =>
  points.every((point) => point.netRevenue === 0 && point.invoiceCount === 0);

/** One bar per day, stacked by line of business. */
export const toChartPoints = (
  points: readonly SeriesPoint[],
  label: (iso: string) => string,
  title: (iso: string) => string
): ChartPoint[] =>
  points.map((point) => ({
    key: point.bucket,
    label: label(point.bucket),
    title: title(point.bucket),
    values: [point.shop, point.spa, point.boarding, point.medical],
  }));
