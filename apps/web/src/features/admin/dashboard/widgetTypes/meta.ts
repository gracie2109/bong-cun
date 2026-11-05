import type { WidgetSize, WidgetTypeMeta } from "./types";

const size = (w: number, h: number): WidgetSize => ({ w, h });

/** The fixed widget types of the dashboards. Sizes are grid cells (4 columns, 1 row = 88px). */
export const WIDGET_META = {
  actions: {
    key: "actions", permissions: ["shop_orders", "inventory", "medical", "boarding"], scopes: ["branch"],
    defaultSize: size(2, 4), minSize: size(2, 3), maxSize: size(4, 6),
  },
  salesToday: {
    key: "salesToday", permissions: ["reports"], scopes: ["branch"],
    defaultSize: size(2, 4), minSize: size(2, 3), maxSize: size(4, 4),
  },
  spaToday: {
    key: "spaToday", permissions: ["schedule"], scopes: ["branch"],
    defaultSize: size(2, 3), minSize: size(1, 3), maxSize: size(4, 5),
  },
  boardingToday: {
    key: "boardingToday", permissions: ["boarding"], scopes: ["branch"],
    defaultSize: size(2, 3), minSize: size(1, 3), maxSize: size(4, 5),
  },
  medicalToday: {
    key: "medicalToday", permissions: ["medical"], scopes: ["branch"],
    defaultSize: size(2, 3), minSize: size(1, 3), maxSize: size(4, 5),
  },
  staffToday: {
    key: "staffToday", permissions: ["attendance"], scopes: ["branch"],
    defaultSize: size(2, 3), minSize: size(1, 3), maxSize: size(4, 5),
  },
  myShifts: {
    key: "myShifts", permissions: [], anyStaff: true, scopes: ["branch"],
    defaultSize: size(2, 3), minSize: size(1, 2), maxSize: size(4, 5),
  },
  salesPeriod: {
    key: "salesPeriod", permissions: ["reports"], scopes: ["branch", "all"],
    defaultSize: size(4, 3), minSize: size(2, 3), maxSize: size(4, 4),
  },
  trend: {
    key: "trend", permissions: ["reports"], scopes: ["branch", "all"],
    defaultSize: size(4, 4), minSize: size(2, 3), maxSize: size(4, 6),
  },
  topProducts: {
    key: "topProducts", permissions: ["reports"], scopes: ["branch", "all"],
    defaultSize: size(2, 4), minSize: size(2, 3), maxSize: size(4, 8),
  },
  onlineOrders: {
    key: "onlineOrders", permissions: ["shop_orders"], scopes: ["branch", "all"],
    defaultSize: size(2, 3), minSize: size(1, 2), maxSize: size(4, 4),
  },
  kpi: {
    key: "kpi", permissions: [], scopes: [], byMetric: true, multiple: true,
    defaultSize: size(1, 2), minSize: size(1, 2), maxSize: size(2, 2),
  },
  barChart: {
    key: "barChart", permissions: [], scopes: [], byMetric: true, multiple: true,
    defaultSize: size(2, 4), minSize: size(2, 3), maxSize: size(4, 6),
  },
  list: {
    key: "list", permissions: [], scopes: [], byMetric: true, multiple: true,
    defaultSize: size(2, 4), minSize: size(1, 3), maxSize: size(4, 8),
  },
} as const satisfies Record<string, WidgetTypeMeta>;

export type WidgetTypeKey = keyof typeof WIDGET_META;

export const isWidgetType = (key: string): key is WidgetTypeKey => Object.hasOwn(WIDGET_META, key);

/** The meta of a type key, or null for a key this build does not know (a removed widget). */
export const metaOf = (key: string): WidgetTypeMeta | null => (isWidgetType(key) ? WIDGET_META[key] : null);
