// The metrics a dashboard widget can show. Data only: which existing report or board feeds each one,
// who may see it and which parameters it accepts. There is no free-form query anywhere.
import type { MetricDef } from "./types";

const SEGMENTS = ["all", "shop", "spa", "boarding", "medical"] as const;

const overview = (
  key: string,
  pick: string,
  extra: Partial<MetricDef> = {}
): MetricDef => ({
  key, group: "revenue", labelKey: `dashboard.metric.${key}`, shape: "number", format: "money", permission: "reports",
  scopes: ["branch", "all"], usesRange: true, defaultRange: "today", views: ["kpi"], source: "overview", pick,
  route: "reportsOverview", ...extra,
});

const stock = (key: string, pick: string, extra: Partial<MetricDef> = {}): MetricDef => ({
  key, group: "stock", labelKey: `dashboard.metric.${key}`, shape: "number", format: "count", permission: "inventory",
  scopes: ["branch"], usesRange: false, views: ["kpi"], source: "stock", pick, riseIsBad: true, ...extra,
});

export const METRIC_LIST: readonly MetricDef[] = [
  overview("revenue.net", "net", { params: { segment: SEGMENTS } }),
  overview("revenue.invoiceCount", "invoiceCount", { format: "count" }),
  overview("revenue.avgTicket", "avgTicket"),
  overview("revenue.refunds", "refunds", { riseIsBad: true }),
  overview("revenue.pendingCod", "pendingCod"),
  overview("revenue.grossProfit", "grossProfit"),
  {
    ...overview("revenue.series", "net", { params: { segment: SEGMENTS }, defaultRange: "last7" }),
    shape: "series", views: ["barChart", "lineChart"], source: "series",
  },
  {
    ...overview("revenue.topItems", "revenue", {
      params: { kind: ["product", "service", "all"], sort: ["revenue", "qty", "profit"], limit: [5, 10] },
      defaultRange: "thisMonth", route: "reportsItems",
    }),
    shape: "list", views: ["list"], source: "topItems",
  },
  stock("stock.low", "low", { route: "inventoryStock" }),
  stock("stock.out", "out", { route: "inventoryStock" }),
  stock("stock.expiring", "expiring", { params: { days: [60, 30, 90] }, route: "inventoryStock" }),
  stock("stock.expired", "expired", { route: "inventoryStock" }),
  {
    key: "orders.pending", group: "orders", labelKey: "dashboard.metric.orders.pending", shape: "number", format: "count",
    permission: "shop_orders", scopes: ["branch"], usesRange: false, views: ["kpi"], source: "orders", pick: "pending",
    route: "shopOrders",
  },
  {
    key: "spa.today", group: "spa", labelKey: "dashboard.metric.spa.today", shape: "number", format: "count",
    permission: "schedule", scopes: ["branch"], usesRange: false, views: ["kpi"], source: "spa", pick: "tickets",
    params: { status: ["total", "waiting", "inProgress", "done"] }, route: "spaBoard",
  },
  {
    key: "boarding.today", group: "boarding", labelKey: "dashboard.metric.boarding.today", shape: "number", format: "count",
    permission: "boarding", scopes: ["branch"], usesRange: false, views: ["kpi"], source: "boarding", pick: "board",
    params: { count: ["occupied", "arriving", "departing", "overdue"], unit: ["kennels", "pets"] }, route: "boardingBoard",
  },
  {
    key: "medical.queue", group: "medical", labelKey: "dashboard.metric.medical.queue", shape: "number", format: "count",
    permission: "medical", scopes: ["branch"], usesRange: false, views: ["kpi"], source: "medical", pick: "queue",
    params: { status: ["waiting", "inProgress", "done"] }, route: "medicalQueue",
  },
  {
    key: "medical.vaccineOverdue", group: "medical", labelKey: "dashboard.metric.medical.vaccineOverdue", shape: "number",
    format: "count", permission: "medical", scopes: ["branch"], usesRange: false, views: ["kpi"], source: "medical",
    pick: "vaccineOverdue", riseIsBad: true, route: "medicalReminders",
  },
];

export const METRICS: Readonly<Record<string, MetricDef>> = Object.fromEntries(METRIC_LIST.map((metric) => [metric.key, metric]));

export const metricOf = (key: string): MetricDef | null => (Object.hasOwn(METRICS, key) ? (METRICS[key] as MetricDef) : null);
