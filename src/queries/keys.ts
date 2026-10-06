// Every query key lives here so invalidation never needs to import a hook
// module (avoids import cycles) and keys stay consistent.
import type { PageParams } from "@/repositories/shared";

export const petKeys = {
  all: ["pets"] as const,
  list: (page: PageParams) => [...petKeys.all, "list", page] as const,
  options: () => [...petKeys.all, "options"] as const,
  detail: (id: string) => [...petKeys.all, "detail", id] as const,
};

export const petServiceKeys = {
  all: ["pet-services"] as const,
  list: (page: PageParams) => [...petServiceKeys.all, "list", page] as const,
  options: () => [...petServiceKeys.all, "options"] as const,
  detail: (id: string) => [...petServiceKeys.all, "detail", id] as const,
  ofPets: (petIds: string[]) => [...petServiceKeys.all, "of-pets", [...petIds].sort()] as const,
};

export const servicePriceKeys = {
  all: ["service-prices"] as const,
  list: (petId: string, serviceId?: string) =>
    [...servicePriceKeys.all, "list", petId, serviceId ?? null] as const,
};

export const petComboKeys = {
  all: ["pet-combos"] as const,
  list: (page: PageParams) => [...petComboKeys.all, "list", page] as const,
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
  list: (page: PageParams, role?: string) => [...userKeys.all, "list", page, role ?? null] as const,
};

export const orderKeys = {
  all: ["orders"] as const,
  list: (page: PageParams, phoneNumber?: string) =>
    [...orderKeys.all, "list", page, phoneNumber ?? null] as const,
  detail: (id: string) => [...orderKeys.all, "detail", id] as const,
};
