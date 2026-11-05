// Public surface of admin/reports: what other features may import. Everything else stays private.
export { useReportOverview, useRevenueSeries, useTopItems } from "./queries/reports";
export type { ChartPoint, ChartSeries, LinePoint } from "./shared/chartScale";
export { bucketLabel, formatDay, formatShortDay, presetRange, rangeDays, rangeProblem, todayInVietnam, type DateRange } from "./shared/dateRange";
export { compactMoney, delta, money, percent, type Delta } from "./shared/format";
export { default as KpiCard } from "./shared/KpiCard.vue";
export { default as StackedBarChart } from "./shared/StackedBarChart.vue";
export { default as LineChart } from "./shared/LineChart.vue";
export { useReportBranches } from "./shared/useReportBranches";
