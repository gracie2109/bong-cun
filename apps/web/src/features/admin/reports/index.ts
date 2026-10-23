// Public surface of admin/reports: what other features may import. Everything else stays private.
export { useReportOverview, useRevenueSeries, useTopItems } from "./queries/reports";
export type { ChartPoint, ChartSeries } from "./shared/chartScale";
export { bucketLabel, formatDay, formatShortDay, presetRange, todayInVietnam, type DateRange } from "./shared/dateRange";
export { compactMoney, money } from "./shared/format";
export { default as KpiCard } from "./shared/KpiCard.vue";
export { default as StackedBarChart } from "./shared/StackedBarChart.vue";
export { useReportBranches } from "./shared/useReportBranches";
