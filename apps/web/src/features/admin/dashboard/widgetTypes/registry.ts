import ActionItemsWidget from "../widgets/actionItems/ActionItemsWidget.vue";
import BoardingTodayWidget from "../widgets/boarding/BoardingTodayWidget.vue";
import MedicalTodayWidget from "../widgets/medical/MedicalTodayWidget.vue";
import OnlineOrdersWidget from "../widgets/onlineOrders/OnlineOrdersWidget.vue";
import SalesPeriodWidget from "../widgets/sales/SalesPeriodWidget.vue";
import SalesTodayWidget from "../widgets/sales/SalesTodayWidget.vue";
import SpaTodayWidget from "../widgets/spa/SpaTodayWidget.vue";
import TopProductsWidget from "../widgets/topItems/TopProductsWidget.vue";
import MetricWidget from "../widgets/metric/MetricWidget.vue";
import RevenueTrendWidget from "../widgets/trend/RevenueTrendWidget.vue";
import { WIDGET_META, isWidgetType, type WidgetTypeKey } from "./meta";
import type { WidgetTypeDef } from "./types";

const COMPONENTS = {
  actions: ActionItemsWidget,
  salesToday: SalesTodayWidget,
  spaToday: SpaTodayWidget,
  boardingToday: BoardingTodayWidget,
  medicalToday: MedicalTodayWidget,
  salesPeriod: SalesPeriodWidget,
  trend: RevenueTrendWidget,
  topProducts: TopProductsWidget,
  onlineOrders: OnlineOrdersWidget,
  kpi: MetricWidget,
  barChart: MetricWidget,
  list: MetricWidget,
} as const satisfies Record<WidgetTypeKey, WidgetTypeDef["component"]>;

/** A widget type with its component, or null for a key this build does not know. */
export const widgetType = (key: string): WidgetTypeDef | null =>
  isWidgetType(key) ? { ...WIDGET_META[key], component: COMPONENTS[key] } : null;
