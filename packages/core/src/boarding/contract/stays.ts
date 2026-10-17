// Contract of the stay functions (book, quote, check in, check out, charges). Input schemas are
// camel-case and say what a caller sends; result schemas describe the `jsonb` the database answers
// with. The Supabase adapter maps names, so screens never see `snake_case`.
import { z } from "zod";

const uuid = z.string().uuid();

export const stayStatusSchema = z.enum(["booked", "checked_in", "checked_out", "paid", "cancelled", "no_show"]);
export const staySourceSchema = z.enum(["counter", "phone", "web"]);
export const stayKindSchema = z.enum(["boarding", "inpatient"]);
export const careKindSchema = z.enum(["meal", "walk", "potty", "medication", "note"]);
export const mealEatenSchema = z.enum(["all", "some", "none"]);
export const chargeKindSchema = z.enum(["night", "late", "extra"]);

// ---------------------------------------------------------------- inputs
/** One pet of a booking. */
export const stayPetInput = z.object({
  petId: uuid,
  kennelTypeId: uuid,
  /** Leave out to let the database pick a free kennel of the type. */
  kennelId: uuid.nullish(),
  /** 1-based line of an earlier pet whose kennel this one shares. */
  shareWith: z.number().int().positive().nullish(),
  feeding: z.string().optional(),
  medication: z.string().optional(),
  belongings: z.string().optional(),
});
export type StayPetInput = z.infer<typeof stayPetInput>;

/** `save_boarding_stay` (books, or replaces a booked stay) and `boarding_quote`. */
export const stayInput = z.object({
  customerId: uuid,
  /** ISO instants. */
  plannedInAt: z.string(),
  plannedOutAt: z.string(),
  source: z.enum(["counter", "phone"]),
  emergencyPhone: z.string(),
  note: z.string(),
  pets: z.array(stayPetInput).min(1),
});
export type StayInput = z.infer<typeof stayInput>;

export const checkInPetInput = z.object({
  stayPetId: uuid,
  weightKg: z.number().positive(),
  vaccineChecked: z.boolean(),
  vaccineNote: z.string(),
  belongings: z.string(),
  feeding: z.string(),
  medication: z.string(),
});
export type CheckInPetInput = z.infer<typeof checkInPetInput>;

export const checkInInput = z.object({ id: uuid, pets: z.array(checkInPetInput), emergencyPhone: z.string() });
export const extendStayInput = z.object({ id: uuid, plannedOutAt: z.string() });
export const checkOutInput = z.object({ id: uuid, returnedPetIds: z.array(uuid) });
export const cancelStayInput = z.object({ id: uuid, reason: z.string().optional() });
export const moveBoardingPetInput = z.object({ stayPetId: uuid, kennelId: uuid });
export const addBoardingExtraInput = z.object({ stayPetId: uuid, serviceId: uuid, qty: z.number().positive() });

// ---------------------------------------------------------------- results
/** `save_boarding_stay` and `check_in_boarding` answer `{ id, code }`. */
export const savedStaySchema = z.object({ id: z.string(), code: z.string() });

export const stayPetRowSchema = z.object({
  id: z.string(),
  line_no: z.number(),
  pet_id: z.string(),
  pet_name: z.string(),
  pet_photo_url: z.string().nullish(),
  status: z.enum(["active", "cancelled"]),
  kennel_type_id: z.string(),
  kennel_type_name: z.string(),
  kennel_id: z.string(),
  kennel_code: z.string(),
  nights_from: z.string(),
  nights_to: z.string(),
  charged_nights: z.number(),
  is_extra_pet: z.boolean(),
  est_night_price: z.number(),
  night_price: z.number().nullish(),
  weight_kg: z.number().nullish(),
  vaccine_checked: z.boolean(),
  vaccine_note: z.string().nullish(),
  belongings: z.string().nullish(),
  belongings_returned: z.boolean(),
  feeding: z.string().nullish(),
  medication: z.string().nullish(),
  has_notes: z.boolean(),
});

export const careLogRowSchema = z.object({
  id: z.string(),
  stay_pet_id: z.string(),
  pet_name: z.string(),
  kind: careKindSchema,
  meal_eaten: mealEatenSchema.nullish(),
  content: z.string().nullish(),
  visible_to_customer: z.boolean(),
  logged_at: z.string(),
  created_by_name: z.string().nullish(),
  can_delete: z.boolean(),
});
export type CareLogRow = z.infer<typeof careLogRowSchema>;

export const stayChargeRowSchema = z.object({
  id: z.string(),
  stay_pet_id: z.string().nullish(),
  pet_name: z.string().nullish(),
  kind: chargeKindSchema,
  name: z.string(),
  qty: z.number(),
  unit_price: z.number(),
  amount: z.number(),
  invoice_line_id: z.string().nullish(),
});
export type StayChargeRow = z.infer<typeof stayChargeRowSchema>;

/** A stay as `boarding_stay_json` builds it; `get_boarding_stay` adds the care logs and charges. */
export const stayRowSchema = z.object({
  id: z.string(),
  code: z.string(),
  branch_id: z.string(),
  status: stayStatusSchema,
  customer_id: z.string(),
  customer_name: z.string(),
  customer_phone: z.string(),
  planned_in_at: z.string(),
  planned_out_at: z.string(),
  checked_in_at: z.string().nullish(),
  checked_out_at: z.string().nullish(),
  source: staySourceSchema,
  kind: stayKindSchema,
  visit_id: z.string().nullish(),
  visit_code: z.string().nullish(),
  emergency_phone: z.string().nullish(),
  note: z.string().nullish(),
  cancel_reason: z.string().nullish(),
  est_total: z.number(),
  pets: z.array(stayPetRowSchema).nullish(),
  care_logs: z.array(careLogRowSchema).nullish(),
  charges: z.array(stayChargeRowSchema).nullish(),
});
export type StayRow = z.infer<typeof stayRowSchema>;

/** `list_boarding_stays` answers one page: `{ rows, total }`. */
export const stayPageSchema = z.object({ rows: z.array(stayRowSchema).nullish(), total: z.number() });

export const quoteWarningSchema = z.enum(["overweight", "behavior"]);

export const quoteItemRowSchema = z.object({
  line_no: z.number(),
  pet_id: z.string(),
  pet_name: z.string(),
  kennel_type_id: z.string(),
  kennel_type_name: z.string(),
  kennel_id: z.string(),
  kennel_code: z.string(),
  is_extra_pet: z.boolean(),
  night_price: z.number(),
  amount: z.number(),
  warnings: z.array(quoteWarningSchema).nullish(),
});

/** `boarding_quote`: the price and kennels a booking would get. */
export const quoteSchema = z.object({ nights: z.number(), total: z.number(), items: z.array(quoteItemRowSchema).nullish() });
export type QuoteRow = z.infer<typeof quoteSchema>;

/** `boarding_availability`: one row per kennel type. */
export const typeAvailabilityRowSchema = z.object({
  kennel_type_id: z.string(),
  name: z.string(),
  total: z.number(),
  free: z.number(),
  night_price: z.number().nullish(),
});
export const typeAvailabilitySchema = z.array(typeAvailabilityRowSchema).nullish();
export type TypeAvailabilityRow = z.infer<typeof typeAvailabilityRowSchema>;

/** `check_out_boarding` answers what is owed. */
export const checkedOutStaySchema = z.object({ id: z.string(), code: z.string(), total: z.number() });

export const checkoutLineRowSchema = z.object({
  stay_pet_id: z.string().nullish(),
  pet_name: z.string().nullish(),
  kind: chargeKindSchema,
  name: z.string(),
  qty: z.number(),
  unit_price: z.number(),
  amount: z.number(),
});

/** `boarding_checkout_preview`: the bill if the stay left now. */
export const checkoutPreviewSchema = z.object({
  at: z.string(),
  items: z.array(checkoutLineRowSchema).nullish(),
  total: z.number(),
  belongings: z
    .array(z.object({ stay_pet_id: z.string(), pet_name: z.string(), belongings: z.string(), returned: z.boolean() }))
    .nullish(),
});
export type CheckoutPreviewRow = z.infer<typeof checkoutPreviewSchema>;

/** `billable_boarding_charges`: checked-out stays with charges not yet on an invoice. */
export const billableChargeRowSchema = z.object({
  id: z.string(),
  kind: chargeKindSchema.nullish(),
  name: z.string(),
  qty: z.number(),
  unit_price: z.number(),
  amount: z.number(),
  pet_name: z.string().nullish(),
  pet_photo_url: z.string().nullish(),
});
export const billableStayRowSchema = z.object({
  stay_id: z.string(),
  code: z.string(),
  total: z.number(),
  charges: z.array(billableChargeRowSchema),
});
export const billableStaysSchema = z.array(billableStayRowSchema).nullish();
export type BillableStayRow = z.infer<typeof billableStayRowSchema>;
