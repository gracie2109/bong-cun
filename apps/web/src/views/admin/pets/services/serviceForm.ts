import type { ServiceCategory } from "@bongcun/core/medical";

export type ServicePricing = "by_weight" | "all";

/** Longest duration of a service, in minutes (one day less a minute). */
export const MAX_DURATION_MINUTES = 1439;
export const DEFAULT_DURATION_MINUTES = 60;

/** Unit values stored on a service: priced per visit or per day. */
export const DEFAULT_UNIT = "unit1";
export const SERVICE_UNITS = [
  { value: "unit1", label: "petCare.services.form.unitTime" },
  { value: "unit2", label: "petCare.services.form.unitDay" },
] as const;

/** The groups a service belongs to; the spa lists only show "spa". */
export const DEFAULT_CATEGORY: ServiceCategory = "spa";
export const SERVICE_CATEGORY_OPTIONS = [
  { value: "spa", label: "petCare.services.category.spa" },
  { value: "medical", label: "petCare.services.category.medical" },
  { value: "other", label: "petCare.services.category.other" },
] as const;

export const SERVICE_PRICING = [
  { value: "by_weight", title: "petCare.services.typeByWeight", desc: "petCare.services.form.byWeightDesc" },
  { value: "all", title: "petCare.services.typeAll", desc: "petCare.services.form.fixedDesc" },
] as const;
