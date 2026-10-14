import type { LinkProp } from "@/types";
import type { AccountNavItem } from "@/types/account";

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
      { title: "adminNav.productCategories", icon: "lucide:folder-tree", name: "productCategories" },
      { title: "adminNav.productBrands", icon: "lucide:badge-check", name: "productBrands" },
    ],
  },
  {
    title: "adminNav.shopOnline",
    items: [
      { title: "adminNav.shopOrders", icon: "lucide:shopping-bag", name: "shopOrders" },
      { title: "adminNav.shopOrderSettings", icon: "lucide:settings-2", name: "shopOrderSettings" },
    ],
  },
  {
    title: "adminNav.reports",
    items: [
      { title: "adminNav.reportsOverview", icon: "lucide:chart-column", name: "reportsOverview" },
      { title: "adminNav.reportsItems", icon: "lucide:package-search", name: "reportsItems" },
      { title: "adminNav.reportsStaff", icon: "lucide:users", name: "reportsStaff" },
      { title: "adminNav.reportsAdjustments", icon: "lucide:undo-2", name: "reportsAdjustments" },
      { title: "adminNav.reportsShifts", icon: "lucide:scale", name: "reportsShifts" },
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
    items: [
      { title: "adminNav.spaBoard", icon: "lucide:calendar-days", name: "spaBoard" },
      { title: "adminNav.spaAppointments", icon: "lucide:list-checks", name: "spaAppointments" },
    ],
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

export const navigation = {
  /** Public header/footer links. `title` is an i18n key under `client.nav`. */
  clientNav: [
    { title: "client.nav.home", name: "home" },
    { title: "client.nav.products", name: "products" },
    { title: "client.nav.spa", name: "spa" },
    { title: "client.nav.about", name: "about-us" },
    { title: "client.nav.contact", name: "contact" },
  ],
};

/** Side menu of the account area. Later steps add pets and appointments. `label` is an i18n key under `client.account.nav`. */
export const ACCOUNT_NAV: AccountNavItem[] = [
  { label: "client.account.nav.overview", name: "account", icon: "LayoutDashboard" },
  { label: "client.account.nav.profile", name: "account-profile", icon: "User" },
  { label: "client.account.nav.pets", name: "account-pets", icon: "PawPrint" },
  { label: "client.account.nav.appointments", name: "account-appointments", icon: "CalendarClock" },
  { label: "client.account.nav.addresses", name: "account-addresses", icon: "MapPin" },
  { label: "client.account.nav.orders", name: "account-orders", icon: "Package" },
];
