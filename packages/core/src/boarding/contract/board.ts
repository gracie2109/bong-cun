// Contract of the hotel board, calendar, kennel, care-log and settings functions. Inputs are
// camel-case; result schemas describe the `jsonb` the database answers with.
import { z } from "zod";
import { careKindSchema, mealEatenSchema, stayKindSchema, stayStatusSchema } from "./stays";

const uuid = z.string().uuid();

export const kennelStatusSchema = z.enum(["ready", "cleaning", "maintenance"]);
export const kennelPurposeSchema = z.enum(["boarding", "medical", "isolation"]);
export const kennelStateSchema = z.enum(["free", "arriving", "occupied", "departing", "overdue", "cleaning", "maintenance"]);

// ---------------------------------------------------------------- inputs
/** `add_care_log`. */
export const careLogInput = z.object({
  kind: careKindSchema,
  mealEaten: mealEatenSchema.optional(),
  content: z.string(),
  visibleToCustomer: z.boolean(),
});
export type CareLogInput = z.infer<typeof careLogInput>;

/** `save_kennel` (creates, or replaces when an id is passed). */
export const kennelInput = z.object({
  branchId: uuid,
  kennelTypeId: uuid,
  code: z.string().min(1),
  name: z.string().nullable(),
  isActive: z.boolean(),
  sortOrder: z.number().int(),
});
export type KennelInput = z.infer<typeof kennelInput>;

export const setKennelStatusInput = z.object({ id: uuid, status: kennelStatusSchema });

export const branchKennelPriceInput = z.object({
  branchId: uuid,
  nightPrice: z.number().min(0),
  extraPetNightPrice: z.number().min(0).nullable(),
});

/** `save_kennel_type`. */
export const kennelTypeInput = z.object({
  name: z.string().min(1),
  description: z.string().nullable(),
  photoUrl: z.string().nullable(),
  speciesIds: z.array(uuid),
  maxWeightKg: z.number().positive().nullable(),
  maxPets: z.number().int().positive(),
  isActive: z.boolean(),
  isPublic: z.boolean(),
  sortOrder: z.number().int(),
  sharedNightPrice: z.number().min(0),
  sharedExtraPetNightPrice: z.number().min(0).nullable(),
  branchPrices: z.array(branchKennelPriceInput),
});
export type KennelTypeInput = z.infer<typeof kennelTypeInput>;

/** `save_boarding_settings`. Times are "HH:mm". */
export const boardingRulesInput = z.object({
  checkInFrom: z.string(),
  checkOutBy: z.string(),
  lateHalfUntil: z.string(),
  maxNights: z.number().int().positive(),
  /** Nights charged for a pet dropped and collected on the same day (0.5 or 1). */
  dayStayNights: z.number().positive(),
});
export type BoardingRules = z.infer<typeof boardingRulesInput>;

// ---------------------------------------------------------------- results
export const boardPetRowSchema = z.object({
  stay_id: z.string(),
  stay_code: z.string(),
  stay_status: stayStatusSchema,
  stay_pet_id: z.string(),
  pet_id: z.string(),
  pet_name: z.string(),
  pet_photo_url: z.string().nullish(),
  customer_name: z.string(),
  planned_in_at: z.string(),
  planned_out_at: z.string(),
  has_notes: z.boolean(),
  overdue: z.boolean(),
  kind: stayKindSchema,
  visit_id: z.string().nullish(),
  visit_code: z.string().nullish(),
});

export const boardKennelRowSchema = z.object({
  id: z.string(),
  code: z.string(),
  name: z.string().nullish(),
  kennel_type_id: z.string(),
  kennel_type_name: z.string(),
  purpose: kennelPurposeSchema,
  status: kennelStatusSchema,
  state: kennelStateSchema,
  conflict: z.boolean(),
  pets: z.array(boardPetRowSchema).nullish(),
  arriving: z.array(boardPetRowSchema).nullish(),
});

/** `boarding_board`: every kennel with what is in it on a day. */
export const boardSchema = z.object({
  date: z.string(),
  counts: z.object({
    arriving: z.number(),
    departing: z.number(),
    occupied: z.number(),
    overdue: z.number(),
    free: z.number(),
    inpatient: z.number(),
  }),
  kennels: z.array(boardKennelRowSchema).nullish(),
});
export type BoardRow = z.infer<typeof boardSchema>;

export const timelineSegmentRowSchema = z.object({
  stay_id: z.string(),
  stay_code: z.string(),
  stay_status: stayStatusSchema,
  stay_pet_id: z.string(),
  pet_name: z.string(),
  customer_name: z.string(),
  kind: stayKindSchema,
  visit_code: z.string().nullish(),
  from: z.string(),
  to: z.string(),
});

/** `boarding_timeline`: the kennel calendar. */
export const timelineSchema = z.object({
  from: z.string(),
  days: z.number(),
  kennels: z
    .array(
      z.object({
        id: z.string(),
        code: z.string(),
        name: z.string().nullish(),
        kennel_type_id: z.string(),
        kennel_type_name: z.string(),
        status: kennelStatusSchema,
        segments: z.array(timelineSegmentRowSchema).nullish(),
      })
    )
    .nullish(),
});
export type TimelineRow = z.infer<typeof timelineSchema>;

export const kennelRowSchema = z.object({
  id: z.string(),
  branch_id: z.string(),
  kennel_type_id: z.string(),
  kennel_type_name: z.string(),
  code: z.string(),
  name: z.string().nullish(),
  status: kennelStatusSchema,
  is_active: z.boolean(),
  sort_order: z.number(),
});
export type KennelRow = z.infer<typeof kennelRowSchema>;

/** `list_kennels` answers one page: `{ rows, total }`. */
export const kennelPageSchema = z.object({ rows: z.array(kennelRowSchema).nullish(), total: z.number() });

export const branchPriceRowSchema = z.object({
  branch_id: z.string(),
  branch_name: z.string(),
  night_price: z.number(),
  extra_pet_night_price: z.number().nullish(),
});

export const kennelTypeRowSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullish(),
  photo_url: z.string().nullish(),
  species_ids: z.array(z.string()).nullish(),
  species_names: z.array(z.string()).nullish(),
  max_weight_kg: z.number().nullish(),
  max_pets: z.number(),
  purpose: kennelPurposeSchema,
  is_active: z.boolean(),
  is_public: z.boolean(),
  sort_order: z.number(),
  night_price: z.number().nullish(),
  extra_pet_night_price: z.number().nullish(),
  has_branch_price: z.boolean(),
  shared_night_price: z.number().nullish(),
  shared_extra_pet_night_price: z.number().nullish(),
  branch_prices: z.array(branchPriceRowSchema).nullish(),
  kennel_count: z.number(),
});
export type KennelTypeRow = z.infer<typeof kennelTypeRowSchema>;

/** `list_kennel_types` answers one page: `{ rows, total }`. */
export const kennelTypePageSchema = z.object({ rows: z.array(kennelTypeRowSchema).nullish(), total: z.number() });

/** `boarding_settings_get`. */
export const boardingRulesRowSchema = z.object({
  check_in_from: z.string(),
  check_out_by: z.string(),
  late_half_until: z.string(),
  max_nights: z.number(),
  day_stay_nights: z.number(),
});
export type BoardingRulesRow = z.infer<typeof boardingRulesRowSchema>;

/** `boarding_public_catalog`: readable without signing in. */
export const publicCatalogSchema = z.object({
  branch: z.object({ id: z.string(), name: z.string(), phone: z.string().nullish() }).nullish(),
  rules: z.object({ check_in_from: z.string(), check_out_by: z.string(), late_half_until: z.string() }).nullish(),
  kennel_types: z
    .array(
      z.object({
        id: z.string(),
        name: z.string(),
        description: z.string().nullish(),
        photo_url: z.string().nullish(),
        max_weight_kg: z.number().nullish(),
        max_pets: z.number(),
        night_price: z.number(),
        extra_pet_night_price: z.number().nullish(),
        species: z.array(z.string()).nullish(),
      })
    )
    .nullish(),
});
export type PublicCatalogRow = z.infer<typeof publicCatalogSchema>;
