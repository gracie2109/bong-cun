import type { Component } from "vue";
import { Banknote, BedDouble, CalendarClock, Package, ShoppingBag, Stethoscope } from "lucide-vue-next";
import type { MetricGroup } from "../../metrics/types";

export const GROUP_ICONS: Record<MetricGroup, Component> = {
  revenue: Banknote,
  stock: Package,
  orders: ShoppingBag,
  spa: CalendarClock,
  boarding: BedDouble,
  medical: Stethoscope,
};
