export type TabId = "home" | "products" | "spa" | "cart" | "account";

export type AppTab = { id: TabId; routeName: string; labelKey: string };

/** The bottom tab bar, left to right. Each tab opens `routeName`. */
export const APP_TABS: AppTab[] = [
  { id: "home", routeName: "home", labelKey: "native.tabs.home" },
  { id: "products", routeName: "products", labelKey: "native.tabs.products" },
  { id: "spa", routeName: "spa", labelKey: "native.tabs.spa" },
  { id: "cart", routeName: "cart", labelKey: "native.tabs.cart" },
  { id: "account", routeName: "account", labelKey: "native.tabs.account" },
];

const ROUTES_BY_TAB: Record<TabId, string[]> = {
  home: ["home"],
  products: ["products", "product-detail"],
  spa: ["spa", "spa-book"],
  cart: ["cart", "checkout"],
  account: ["order-detail", "login", "register", "forgot-password"],
};

/** The tab that should look selected for a route, or null for pages outside the five (about, contact...). */
export const tabForRoute = (routeName: string | null | undefined): TabId | null => {
  if (!routeName) return null;
  if (routeName.startsWith("account")) return "account";
  const entry = (Object.entries(ROUTES_BY_TAB) as [TabId, string[]][]).find(([, names]) => names.includes(routeName));
  return entry ? entry[0] : null;
};
