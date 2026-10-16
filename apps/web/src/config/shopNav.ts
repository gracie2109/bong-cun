import type { Component } from "vue";
import { Home, Info, MessageCircle, Scissors, ShoppingBasket } from "lucide-vue-next";
import { navigation } from "@/lib/navigations";

export type ShopNavItem = { name: string; title: string; icon: Component };

const ICONS: Record<string, Component> = {
  home: Home,
  products: ShoppingBasket,
  spa: Scissors,
  "about-us": Info,
  contact: MessageCircle,
};

/** The public header and drawer menu: the client nav with an icon for each entry. */
export const SHOP_NAV: ShopNavItem[] = navigation.clientNav.map((link) => ({
  name: link.name,
  title: link.title,
  icon: ICONS[link.name] ?? Home,
}));

/** Route names that count as "inside" a nav entry, so the entry stays highlighted on its sub-pages. */
export const NAV_MATCH: Record<string, string[]> = {
  products: ["products", "product-detail"],
  spa: ["spa", "spa-book"],
};
