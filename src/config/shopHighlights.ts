import type { Component } from "vue";
import { BadgeCheck, CalendarClock, Headset, Truck } from "lucide-vue-next";

/**
 * The shop's promises under the home hero. Each one matches something the shop really does
 * (lot and expiry tracking, delivery or pickup, online spa booking, opening hours); edit the
 * wording in the locale files under `client.home.highlights`.
 */
export const SHOP_HIGHLIGHTS: { key: string; icon: Component }[] = [
  { key: "genuine", icon: BadgeCheck },
  { key: "delivery", icon: Truck },
  { key: "booking", icon: CalendarClock },
  { key: "support", icon: Headset },
];
