// Every query key lives here so invalidation never needs to import a hook
// module (avoids import cycles) and keys stay consistent.
import type { PetListFilter } from "@/repositories/pets";
import type { PageParams } from "@/repositories/shared";
import type { PetServiceFilter } from "@/repositories/petServices";
import type { StockDocumentFilter, StockFilter, SupplierFilter } from "@/repositories/inventory";
import type { InvoiceFilter } from "@/repositories/pos";
import type { ProductFilter } from "@/repositories/products";
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
  list: (page: PageParams, includeArchived = false) =>
    [...petComboKeys.all, "list", page, includeArchived] as const,
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
  list: (page: PageParams, phoneNumber?: string) =>
    [...orderKeys.all, "list", page, phoneNumber ?? null] as const,
  detail: (id: string) => [...orderKeys.all, "detail", id] as const,
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
  attributes: () => [...productKeys.all, "attributes"] as const,
  sellable: (text: string) => [...productKeys.all, "sellable", text] as const,
};

export const posKeys = {
  all: ["pos"] as const,
  myShift: (branchId: string, userId: string) => [...posKeys.all, "my-shift", branchId, userId] as const,
  shifts: (branchId: string, page: PageParams) => [...posKeys.all, "shifts", branchId, page] as const,
  shiftSummary: (shiftId: string) => [...posKeys.all, "shift-summary", shiftId] as const,
  invoices: (page: PageParams, filter: InvoiceFilter) => [...posKeys.all, "invoices", page, filter] as const,
  invoice: (id: string) => [...posKeys.all, "invoice", id] as const,
  invoiceReturns: (invoiceId: string) => [...posKeys.all, "invoice-returns", invoiceId] as const,
  combos: () => [...posKeys.all, "combos"] as const,
  customerPets: (customerId: string) => [...posKeys.all, "customer-pets", customerId] as const,
  servicePrice: (speciesId: string, serviceId: string, weightKg: number, branchId: string) =>
    [...posKeys.all, "service-price", speciesId, serviceId, weightKg, branchId] as const,
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
  options: () => [...supplierKeys.all, "options"] as const,
};
