import type { DashboardDef } from "./kit/types";
import ActionItemsWidget from "./widgets/actionItems/ActionItemsWidget.vue";
import BoardingTodayWidget from "./widgets/boarding/BoardingTodayWidget.vue";
import MedicalTodayWidget from "./widgets/medical/MedicalTodayWidget.vue";
import OnlineOrdersWidget from "./widgets/onlineOrders/OnlineOrdersWidget.vue";
import SalesPeriodWidget from "./widgets/sales/SalesPeriodWidget.vue";
import SalesTodayWidget from "./widgets/sales/SalesTodayWidget.vue";
import SpaTodayWidget from "./widgets/spa/SpaTodayWidget.vue";
import RevenueTrendWidget from "./widgets/trend/RevenueTrendWidget.vue";
import TopProductsWidget from "./widgets/topItems/TopProductsWidget.vue";

/** Dashboards are defined here, by purpose. Who sees what is decided per widget (see dashboardRules.ts). */
export const DASHBOARDS: readonly DashboardDef[] = [
  {
    key: "today",
    titleKey: "dashboard.views.today",
    scopes: ["branch"],
    widgets: [
      { key: "actions", component: ActionItemsWidget, permissions: ["shop_orders", "inventory", "medical", "boarding"], scopes: ["branch"], span: 2 },
      { key: "salesToday", component: SalesTodayWidget, permissions: ["reports"], scopes: ["branch"], span: 2 },
      { key: "spaToday", component: SpaTodayWidget, permissions: ["schedule"], scopes: ["branch"] },
      { key: "boardingToday", component: BoardingTodayWidget, permissions: ["boarding"], scopes: ["branch"] },
      { key: "medicalToday", component: MedicalTodayWidget, permissions: ["medical"], scopes: ["branch"] },
    ],
  },
  {
    key: "business",
    titleKey: "dashboard.views.business",
    scopes: ["branch", "all"],
    requires: "reports",
    widgets: [
      { key: "salesPeriod", component: SalesPeriodWidget, permissions: ["reports"], scopes: ["branch", "all"], span: 2 },
      { key: "trend", component: RevenueTrendWidget, permissions: ["reports"], scopes: ["branch", "all"], span: 2 },
      { key: "topProducts", component: TopProductsWidget, permissions: ["reports"], scopes: ["branch", "all"] },
      { key: "onlineOrders", component: OnlineOrdersWidget, permissions: ["shop_orders"], scopes: ["branch", "all"] },
    ],
  },
];
