import { getCurrentDateTime, valueUpdater } from "@/lib/utils";
import { endOfDay, endOfMonth, endOfYear, startOfDay, startOfMonth, startOfYear, subMonths } from "date-fns";

export const CURRENT_DATE = getCurrentDateTime();

export const COLLECTION = {
  PRODUCTS: "products",
  USERS: "users",
  PROVIDERS: "service-provider",
  PETS: "pets",
  PETS_SERVICES: "pet-services",
  PET_SERVICES_PRICE: "pet-service-price",
  PET_SERVICES_COMBO: "pet-service-combo",
  ROLE: "roles",
  PERMISSIONS: "permissions",
  ORDER_SERVICES: 'order-services',
  ORDER_SERVICES_SERVICE: 'order-services-service',
  BANNERS: 'banners',
  REGISTER_BOOKING: "register-booking"
};

export const DEFINE_PRODUCT_CATEGORIES = [
  {
    value: "food_n_beverage",
    vi_name: "Đồ ăn & Đồ uống",
    en_name: "Food & beverage",
  },
  {
    value: "other",
    vi_name: "Vật tư",
    en_name: "Other",
  },
];

export const PAGE_LAYOUT = {
  ADMIN: "admin",
  CLIENT: "client",
  NO_LAYOUT: "empty",
  AUTH: "auth",
} as const;

export const PAGE_THEME = {
  LIGHT: "light",
  DARK: "dark",
  SYSTEM: "system",
} as const;

export const DEFAULT_ROLE = {
  CUSTOMER: "customer",
  ADMIN: "admin",
  SUPER_ADMIN: "superAdmin",
  CASHIER: "cashier",
} as const;

export const LOCAL_STORAGE_KEY = {
  LAYOUT: "layout",
  THEME: "theme",
  SIDEBAR_OPEN: "sidebarOpen",
  VISIBLE_COLUMN: "visibleColumn",
  SETTING_KEY: "settingKey",
};

export const HEADER_ADVANCE_FUNCTION = {
  FILTER: "filter",
  RESET: "reset",
  EXPORT: "export",
  IMPORT: "import",
  ADD_NEW: "addNew",
  SETTING_COLUMN: "settingColumn",
  RANGE_DATE: 'rangeDate'
} as const;

export const PROVIDER_KEYS = {
  IS_COLLAPSE: "isCollapsed",
};

export const GLOBAL_FUNCTION_TYPE = {
  DELETE: "Delete",
  EDIT: "Edit",
};

export const INITIAL_PAGE_INDEX = 1;
export const INITIAL_PAGE_SIZE = 5;

export const PAGE_SIZES = [5, 25, 50, 100, 200, 500];
export const DEFINE_PET_ICONS: { [key: string]: string } = {
  bird: "lucide:bird",
  bone: "lucide:bone",
  bug: "lucide:bug",
  bugOff: "lucide:bug-off",
  cat: "lucide:cat",
  dog: "lucide:dog",
  bugPlay: "lucide:bug-play",
  egg: "lucide:egg",
  fish: "lucide:fish",
  fishOff: "lucide:fish-off",
  fishSymbol: "lucide:fish-symbol",
  origami: "lucide:origami",
  pawPrint: "lucide:paw-print",
  rabbit: "lucide:rabbit",
  rat: "lucide:rat",
  shell: "lucide:shell",
  squirrel: "lucide:squirrel",
  turtle: "lucide:turtle",
  worm: "lucide:worm",
};

export const baseMethods = [
  {
    id: "CREATE",
    value: "CREATE",
  },
  {
    id: "VIEW",
    value: "VIEW",
  },
  {
    id: "DELETE",
    value: "DELETE",
  },
  {
    id: "UPDATE",
    value: "UPDATE",
  },
  {
    id: "IMPORT",
    value: "IMPORT",
  },
  {
    id: "EXPORT",
    value: "EXPORT",
  },
  {
    id: "SETTING",
    value: "SETTING",
  },
  {
    id: "ALL",
    value: "ALL",
  },
] as const;

export const BASE_GENDER = [
  {
    value: "MALE",
    name: {
      vi: "Nam",
      en: "Male",
    },
  },
  {
    value: "FEMALE",
    name: {
      vi: "Nữ",
      en: "Female",
    },
  },
  {
    value: "OTHER",
    name: {
      vi: "Khác",
      en: "Other",
    },
  },
];


export const TIME_OPTIONS = [
  {
    label: "Today",
    value: [startOfDay(new Date()), endOfDay(new Date())],
  },
  { label: "This month", value: [startOfMonth(new Date()), endOfMonth(new Date())] },
  {
    label: "Last month",
    value: [startOfMonth(subMonths(new Date(), 1)), endOfMonth(subMonths(new Date(), 1))],
  },
  { label: "This year", value: [startOfYear(new Date()), endOfYear(new Date())] },
]

export const TIME_FORMAT = 'MM/dd/yyyy hh:mm:ss'