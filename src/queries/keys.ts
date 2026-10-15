// Every query key lives here so invalidation never needs to import a hook
// module (avoids import cycles) and keys stay consistent.
import type { PetListFilter } from "@/repositories/pets";
import type { PageParams } from "@/repositories/shared";
import type { PetServiceFilter } from "@/repositories/petServices";
import type { StockDocumentFilter, StockFilter, SupplierFilter } from "@/repositories/inventory";
import type { InvoiceFilter } from "@/repositories/pos";
import type { CatalogFilter } from "@/repositories/productCategories";
import type { ProductFilter } from "@/repositories/products";
import type {
  AdjustmentFilter,
  Bucket,
  ReportFilter,
  ShiftReconFilter,
  StaffFilter,
  TopItemFilter,
} from "@/repositories/reports";
import type { AppointmentFilter } from "@/repositories/spa";
import type { KennelFilter, KennelTypeFilter, StayFilter } from "@/types/boarding";
import type { UserListFilter } from "@/repositories/users";

export const speciesKeys = {
  all: ["species"] as const,
  options: (includeArchived: boolean) => [...speciesKeys.all, "options", includeArchived] as const,
  summaries: () => [...speciesKeys.all, "summaries"] as const,
  detail: (id: string) => [...speciesKeys.all, "detail", id] as const,
};

export const weightBracketKeys = {
  all: ["weight-brackets"] as const,
  list: (speciesId: string | null) => [...weightBracketKeys.all, "list", speciesId] as const,
};

export const petProfileKeys = {
  all: ["pet-profiles"] as const,
  list: (page: PageParams, filter: PetListFilter) =>
    [...petProfileKeys.all, "list", page, filter] as const,
  detail: (id: string) => [...petProfileKeys.all, "detail", id] as const,
};

export const customerKeys = {
  all: ["customers"] as const,
  search: (text: string) => [...customerKeys.all, "search", text] as const,
};

export const branchKeys = {
  all: ["branches"] as const,
  list: () => [...branchKeys.all, "list"] as const,
};

export const petServiceKeys = {
  all: ["pet-services"] as const,
  list: (page: PageParams, filter: PetServiceFilter) =>
    [...petServiceKeys.all, "list", page, filter] as const,
  options: () => [...petServiceKeys.all, "options"] as const,
  detail: (id: string) => [...petServiceKeys.all, "detail", id] as const,
  ofSpecies: (speciesIds: string[]) =>
    [...petServiceKeys.all, "of-species", [...speciesIds].sort()] as const,
};

export const servicePriceKeys = {
  all: ["service-prices"] as const,
  list: (speciesId: string, serviceId: string | null, branchId: string | null) =>
    [...servicePriceKeys.all, "list", speciesId, serviceId, branchId] as const,
};

export const petComboKeys = {
  all: ["pet-combos"] as const,
  list: (page: PageParams, includeArchived = false, search = "") =>
    [...petComboKeys.all, "list", page, includeArchived, search] as const,
};

export const permissionKeys = {
  all: ["permissions"] as const,
  list: () => [...permissionKeys.all, "list"] as const,
};

export const roleKeys = {
  all: ["roles"] as const,
  list: () => [...roleKeys.all, "list"] as const,
};

export const userKeys = {
  all: ["users"] as const,
  list: (page: PageParams, filter: UserListFilter) =>
    [...userKeys.all, "list", page, filter] as const,
  count: (filter: UserListFilter) => [...userKeys.all, "count", filter] as const,
};

export const orderKeys = {
  all: ["orders"] as const,
  byUsers: (userIds: string[]) => [...orderKeys.all, "by-users", [...userIds].sort()] as const,
};

export const staffKeys = {
  all: ["staff"] as const,
  list: () => [...staffKeys.all, "list"] as const,
};

export const productKeys = {
  all: ["products"] as const,
  groups: (page: PageParams, filter: ProductFilter) => [...productKeys.all, "groups", page, filter] as const,
  group: (id: string) => [...productKeys.all, "group", id] as const,
  sellableGroup: (id: string) => [...productKeys.all, "sellable-group", id] as const,
  attributes: () => [...productKeys.all, "attributes"] as const,
  sellable: (text: string, categoryIds: readonly string[] = []) =>
    [...productKeys.all, "sellable", text, [...categoryIds].sort()] as const,
  sellablePaged: (text: string) => [...productKeys.all, "sellable-paged", text] as const,
};

export const branchPriceKeys = {
  all: ["branch-prices"] as const,
  at: (branchId: string, productIds: string[]) => [...branchPriceKeys.all, "at", branchId, [...productIds].sort()] as const,
  byProduct: (productIds: string[]) => [...branchPriceKeys.all, "by-product", [...productIds].sort()] as const,
};

export const productCategoryKeys = {
  all: ["product-categories"] as const,
  list: (page: PageParams, filter: CatalogFilter) => [...productCategoryKeys.all, "list", page, filter] as const,
  options: (search: string, rootsOnly: boolean) => [...productCategoryKeys.all, "options", search, rootsOnly] as const,
};

export const productBrandKeys = {
  all: ["product-brands"] as const,
  list: (page: PageParams, filter: CatalogFilter) => [...productBrandKeys.all, "list", page, filter] as const,
  options: (search: string) => [...productBrandKeys.all, "options", search] as const,
};

export const posKeys = {
  all: ["pos"] as const,
  myShift: (branchId: string, userId: string) => [...posKeys.all, "my-shift", branchId, userId] as const,
  shifts: (branchId: string, page: PageParams, search = "") =>
    [...posKeys.all, "shifts", branchId, page, search] as const,
  shiftSummary: (shiftId: string) => [...posKeys.all, "shift-summary", shiftId] as const,
  invoices: (page: PageParams, filter: InvoiceFilter) => [...posKeys.all, "invoices", page, filter] as const,
  invoice: (id: string) => [...posKeys.all, "invoice", id] as const,
  invoiceReturns: (invoiceId: string) => [...posKeys.all, "invoice-returns", invoiceId] as const,
  combos: () => [...posKeys.all, "combos"] as const,
  customerPets: (customerId: string) => [...posKeys.all, "customer-pets", customerId] as const,
  servicePrice: (speciesId: string, serviceId: string, weightKg: number, branchId: string) =>
    [...posKeys.all, "service-price", speciesId, serviceId, weightKg, branchId] as const,
};

// Sales, cancellations and returns change the figures, so POS mutations invalidate these too.
export const reportKeys = {
  all: ["reports"] as const,
  overview: (filter: ReportFilter) => [...reportKeys.all, "overview", filter] as const,
  series: (filter: ReportFilter, bucket: Bucket) => [...reportKeys.all, "series", filter, bucket] as const,
  items: (page: PageParams, filter: TopItemFilter) => [...reportKeys.all, "items", page, filter] as const,
  staff: (page: PageParams, filter: StaffFilter) => [...reportKeys.all, "staff", page, filter] as const,
  adjustments: (page: PageParams, filter: AdjustmentFilter) =>
    [...reportKeys.all, "adjustments", page, filter] as const,
  shifts: (page: PageParams, filter: ShiftReconFilter) => [...reportKeys.all, "shifts", page, filter] as const,
  branches: () => [...reportKeys.all, "branches"] as const,
};

// Sales change stock, so POS mutations invalidate these too.
export const inventoryKeys = {
  all: ["inventory"] as const,
  summary: (page: PageParams, filter: StockFilter) => [...inventoryKeys.all, "summary", page, filter] as const,
  alerts: (branchId: string, expiryDays: number) => [...inventoryKeys.all, "alerts", branchId, expiryDays] as const,
  sellable: (branchId: string, productIds: string[]) =>
    [...inventoryKeys.all, "sellable", branchId, [...productIds].sort()] as const,
  lots: (branchId: string, productId: string, includeEmpty: boolean) =>
    [...inventoryKeys.all, "lots", branchId, productId, includeEmpty] as const,
  movements: (branchId: string, productId: string) => [...inventoryKeys.all, "movements", branchId, productId] as const,
  documents: (page: PageParams, filter: StockDocumentFilter) => [...inventoryKeys.all, "documents", page, filter] as const,
  document: (id: string) => [...inventoryKeys.all, "document", id] as const,
};

export const supplierKeys = {
  all: ["suppliers"] as const,
  list: (page: PageParams, filter: SupplierFilter) => [...supplierKeys.all, "list", page, filter] as const,
  options: (search: string) => [...supplierKeys.all, "options", search] as const,
};

export const spaKeys = {
  publicCatalog: (branchId: string | null) => ["spa", "public-catalog", branchId] as const,
  webRules: () => ["spa", "web-rules"] as const,
  webSlots: (branchId: string, date: string, minutes: number) => ["spa", "web-slots", branchId, date, minutes] as const,
  webQuote: (branchId: string, items: unknown) => ["spa", "web-quote", branchId, items] as const,
  all: ["spa"] as const,
  resources: (branchId: string) => [...spaKeys.all, "resources", branchId] as const,
  hours: (branchId: string) => [...spaKeys.all, "hours", branchId] as const,
  staff: (branchId: string) => [...spaKeys.all, "staff", branchId] as const,
  appointments: (branchId: string, page: PageParams, filter: AppointmentFilter) =>
    [...spaKeys.all, "appointments", branchId, page, filter] as const,
  billable: (branchId: string, customerId: string) => [...spaKeys.all, "billable", branchId, customerId] as const,
  appointment: (id: string) => [...spaKeys.all, "appointment", id] as const,
  board: (branchId: string, date: string) => [...spaKeys.all, "board", branchId, date] as const,
};

export const boardingKeys = {
  all: ["boarding"] as const,
  kennelTypes: (branchId: string, page: PageParams, filter: KennelTypeFilter) =>
    [...boardingKeys.all, "kennel-types", branchId, page, filter] as const,
  kennels: (branchId: string, page: PageParams, filter: KennelFilter) =>
    [...boardingKeys.all, "kennels", branchId, page, filter] as const,
  rules: (branchId: string) => [...boardingKeys.all, "rules", branchId] as const,
  stays: (branchId: string, page: PageParams, filter: StayFilter) =>
    [...boardingKeys.all, "stays", branchId, page, filter] as const,
  stay: (id: string) => [...boardingKeys.all, "stay", id] as const,
  board: (branchId: string, date: string) => [...boardingKeys.all, "board", branchId, date] as const,
  availability: (branchId: string, from: string, to: string) =>
    [...boardingKeys.all, "availability", branchId, from, to] as const,
  quote: (branchId: string, stayId: string, input: unknown) => [...boardingKeys.all, "quote", branchId, stayId, input] as const,
};

export const shopKeys = {
  all: ["shop"] as const,
  settings: () => [...shopKeys.all, "settings"] as const,
  publicSettings: () => [...shopKeys.all, "public-settings"] as const,
  addresses: () => [...shopKeys.all, "addresses"] as const,
  cart: (lineKeys: string[]) => [...shopKeys.all, "cart", lineKeys] as const,
  orders: () => [...shopKeys.all, "orders"] as const,
  orderList: (status: string | null, page: number, pageSize: number) =>
    [...shopKeys.orders(), "list", status, page, pageSize] as const,
  order: (code: string) => [...shopKeys.orders(), "detail", code] as const,
  staffOrders: () => [...shopKeys.all, "staff-orders"] as const,
  staffOrderList: (page: unknown, filter: unknown) => [...shopKeys.staffOrders(), "list", page, filter] as const,
  staffOrder: (id: string) => [...shopKeys.staffOrders(), "detail", id] as const,
};

export const shopCatalogKeys = {
  all: ["shop-catalog"] as const,
  list: (filters: unknown, pageSize: number) => [...shopCatalogKeys.all, "list", filters, pageSize] as const,
  related: (groupId: string) => [...shopCatalogKeys.all, "related", groupId] as const,
  availability: (productIds: string[]) => [...shopCatalogKeys.all, "availability", [...productIds].sort()] as const,
};

export const accountKeys = {
  all: ["account"] as const,
  profile: () => [...accountKeys.all, "profile"] as const,
  pets: () => [...accountKeys.all, "pets"] as const,
  appointments: () => [...accountKeys.all, "appointments"] as const,
  appointmentList: (scope: string, page: number, pageSize: number) =>
    [...accountKeys.all, "appointments", scope, page, pageSize] as const,
};

export const ghnLocationKeys = {
  all: ["ghn-locations"] as const,
  provinces: () => [...ghnLocationKeys.all, "provinces"] as const,
  districts: (provinceId: number) => [...ghnLocationKeys.all, "districts", provinceId] as const,
  wards: (districtId: number) => [...ghnLocationKeys.all, "wards", districtId] as const,
};
