import type { DashboardDef } from "./kit/types";

/**
 * Dashboards are defined here, by purpose, with the layout a person sees until they save their own
 * (grid cells: 4 columns, see widgetTypes/meta.ts for the sizes). Who sees what is decided per widget
 * (see dashboardRules.ts).
 */
export const DASHBOARDS: readonly DashboardDef[] = [
  {
    key: "today",
    titleKey: "dashboard.views.today",
    scopes: ["branch"],
    defaultItems: [
      { type: "actions", x: 0, y: 0, w: 2, h: 4 },
      { type: "salesToday", x: 2, y: 0, w: 2, h: 4 },
      { type: "spaToday", x: 0, y: 4, w: 2, h: 3 },
      { type: "boardingToday", x: 2, y: 4, w: 2, h: 3 },
      { type: "medicalToday", x: 0, y: 7, w: 2, h: 3 },
    ],
  },
  {
    key: "business",
    titleKey: "dashboard.views.business",
    scopes: ["branch", "all"],
    requires: "reports",
    defaultItems: [
      { type: "salesPeriod", x: 0, y: 0, w: 4, h: 3 },
      { type: "trend", x: 0, y: 3, w: 4, h: 4 },
      { type: "topProducts", x: 0, y: 7, w: 2, h: 4 },
      { type: "onlineOrders", x: 2, y: 7, w: 2, h: 3 },
    ],
  },
];
