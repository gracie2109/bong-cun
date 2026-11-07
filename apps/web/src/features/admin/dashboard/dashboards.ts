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
      { type: "staffToday", x: 2, y: 7, w: 2, h: 3 },
      { type: "myShifts", x: 0, y: 10, w: 2, h: 3 },
      { type: "shiftRequests", x: 2, y: 10, w: 2, h: 2 },
    ],
    roleDefaults: [
      {
        // Vet / clinic staff: the exam queue first, full width.
        key: "clinic", any: ["medical"], lacks: ["reports"],
        items: [
          { type: "medicalToday", x: 0, y: 0, w: 4, h: 3 },
          { type: "actions", x: 0, y: 3, w: 2, h: 4 },
          { type: "boardingToday", x: 2, y: 3, w: 2, h: 3 },
          { type: "myShifts", x: 2, y: 6, w: 2, h: 3 },
        ],
      },
      {
        // Spa staff: today's spa tickets first, full width.
        key: "spa", any: ["schedule"], lacks: ["reports", "medical"],
        items: [
          { type: "spaToday", x: 0, y: 0, w: 4, h: 3 },
          { type: "boardingToday", x: 0, y: 3, w: 2, h: 3 },
          { type: "myShifts", x: 2, y: 3, w: 2, h: 3 },
          { type: "actions", x: 0, y: 6, w: 4, h: 4 },
        ],
      },
      {
        // Counter, stock and boarding staff: what needs doing, then their own shifts.
        key: "front", any: ["shop_orders", "inventory", "boarding", "attendance"], lacks: ["reports", "medical", "schedule"],
        items: [
          { type: "actions", x: 0, y: 0, w: 2, h: 4 },
          { type: "myShifts", x: 2, y: 0, w: 2, h: 3 },
          { type: "boardingToday", x: 2, y: 3, w: 2, h: 3 },
          { type: "staffToday", x: 0, y: 4, w: 2, h: 3 },
        ],
      },
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
