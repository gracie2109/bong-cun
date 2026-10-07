import type { LinkProp } from "@/types";

export type AdminNavSection = { title: string; items: LinkProp[] };

/** Admin sidebar. Titles are i18n keys under `adminNav`; `name` is the route name. */
export const ADMIN_NAV_SECTIONS: AdminNavSection[] = [
  {
    title: "adminNav.overview",
    items: [{ title: "adminNav.dashboard", icon: "lucide:layout-dashboard", name: "dashboard" }],
  },
  {
    title: "adminNav.sales",
    items: [
      { title: "adminNav.pos", icon: "lucide:shopping-cart", name: "pos" },
      { title: "adminNav.invoices", icon: "lucide:receipt", name: "invoices" },
      { title: "adminNav.cashShifts", icon: "lucide:wallet", name: "cashShifts" },
      { title: "adminNav.products", icon: "lucide:package", name: "adminProducts" },
    ],
  },
  {
    title: "adminNav.inventory",
    items: [
      { title: "adminNav.stock", icon: "lucide:boxes", name: "inventoryStock" },
      { title: "adminNav.stockDocuments", icon: "lucide:clipboard-list", name: "stockDocuments" },
      { title: "adminNav.suppliers", icon: "lucide:truck", name: "suppliers" },
    ],
  },
  {
    title: "adminNav.scheduling",
    items: [{ title: "adminNav.schedule", icon: "lucide:calendar-days", name: "listOrderSchedule" }],
  },
  {
    title: "adminNav.customersPets",
    items: [
      { title: "adminNav.customers", icon: "lucide:users", name: "users" },
      { title: "adminNav.pets", icon: "lucide:paw-print", name: "pets" },
    ],
  },
  {
    title: "adminNav.servicesPrices",
    items: [
      { title: "adminNav.species", icon: "lucide:dog", name: "petSpecies" },
      { title: "adminNav.services", icon: "lucide:scissors", name: "petService" },
      { title: "adminNav.prices", icon: "lucide:banknote", name: "petPrices" },
      { title: "adminNav.combos", icon: "lucide:layers-2", name: "petServiceCombo" },
    ],
  },
  {
    title: "adminNav.system",
    items: [
      { title: "adminNav.roles", icon: "lucide:shield-check", name: "settings" },
      { title: "adminNav.permissions", icon: "lucide:key-round", name: "permissions" },
      { title: "adminNav.matrix", icon: "lucide:grid-3x3", name: "permissionMatrix" },
    ],
  },
];

export const PROFILE_KEYS = {
  GENERAL: "general",
  ADDRESS: 'address',
  TRANSACTION: 'transactions'

}
export const navigation = {
  profileNav: [
    {
      path: "general",
      key: PROFILE_KEYS.GENERAL,
      label: "general",
      icon: "",
    },
    {
      path: "address",
      key:  PROFILE_KEYS.ADDRESS,
      icon: "",
      label: "address",
    },
    {
      path: "transactions",
      key: PROFILE_KEYS.TRANSACTION,
      label: "transactions",
      icon: "",
    },
  ],
  clientNav: [
    {
      text: "Home",
      name: "home",
    },
    {
      text: "About Us",
      name: "about-us",
    },
    {
      text: "Contact",
      name: "contact",
    },
    {
      text: "Products",
      name: "products",
      type: "multi",
    },
    {
      text: "Coupons",
      name: "coupons",
    },
  ],
};
