// Contract of the spa appointment functions (book, list, check in, ticket progress). Input schemas
// are camel-case and say what a caller sends; result schemas describe the `jsonb` the database
// answers with. The Supabase adapter maps names, so screens never see `snake_case`.
import { z } from "zod";

const uuid = z.string().uuid();

export const appointmentStatusSchema = z.enum(["booked", "checked_in", "in_progress", "done", "paid", "cancelled", "no_show"]);
export const ticketStatusSchema = z.enum(["waiting", "in_progress", "done", "cancelled"]);
export const appointmentSourceSchema = z.enum(["counter", "phone", "legacy", "web"]);

// ---------------------------------------------------------------- inputs
export const ticketInput = z.object({
  petId: uuid,
  type: z.enum(["service", "combo"]),
  /** Service or combo id. */
  id: uuid,
  /** ISO timestamp, on a quarter hour. */
  startAt: z.string(),
  staffId: uuid.nullish(),
  resourceId: uuid.nullish(),
  /** Only to estimate a by-weight price; the real weight is taken at check-in. */
  weightKg: z.number().positive().nullish(),
});
export type TicketInput = z.infer<typeof ticketInput>;

/** `save_appointment`: books (no id) or replaces a booked appointment. */
export const appointmentInput = z.object({
  branchId: uuid,
  customerId: uuid,
  note: z.string().optional(),
  source: z.enum(["counter", "phone"]).optional(),
  tickets: z.array(ticketInput).min(1),
});
export type AppointmentInput = z.infer<typeof appointmentInput>;

export const petWeightInput = z.object({ petId: uuid, weightKg: z.number().positive() });
export type PetWeight = z.infer<typeof petWeightInput>;

export const checkInInput = z.object({ id: uuid, weights: z.array(petWeightInput) });
export const cancelAppointmentInput = z.object({ id: uuid, reason: z.string().optional() });
export const setTicketStatusInput = z.object({ ticketId: uuid, status: ticketStatusSchema });

// ---------------------------------------------------------------- results
/** `save_appointment` answers `{ id, code }`. */
export const savedAppointmentSchema = z.object({ id: z.string(), code: z.string() });

export const appointmentTicketRowSchema = z.object({
  id: z.string(),
  name: z.string(),
  item_type: z.enum(["service", "combo"]),
  service_id: z.string().nullish(),
  combo_id: z.string().nullish(),
  status: ticketStatusSchema,
  pet_id: z.string().nullish(),
  pet_name: z.string().nullish(),
  pet_photo_url: z.string().nullish(),
  staff_id: z.string().nullish(),
  staff_name: z.string().nullish(),
  resource_id: z.string().nullish(),
  resource_name: z.string().nullish(),
  start_at: z.string(),
  end_at: z.string(),
  est_price: z.number().nullish(),
  weight_kg: z.number().nullish(),
  unit_price: z.number().nullish(),
  billed: z.boolean().nullish(),
});

/** One appointment as `get_appointment` and the rows of `list_appointments` return it. */
export const appointmentRowSchema = z.object({
  id: z.string(),
  code: z.string(),
  source: appointmentSourceSchema,
  status: appointmentStatusSchema,
  start_at: z.string(),
  end_at: z.string(),
  customer_id: z.string(),
  customer_name: z.string().nullish(),
  customer_phone: z.string().nullish(),
  note: z.string().nullish(),
  checked_in_at: z.string().nullish(),
  items: z.array(appointmentTicketRowSchema).nullish(),
});
export type AppointmentRow = z.infer<typeof appointmentRowSchema>;

/** `list_appointments` answers one page: `{ rows, total }`. */
export const appointmentPageSchema = z.object({ rows: z.array(appointmentRowSchema).nullish(), total: z.number() });
