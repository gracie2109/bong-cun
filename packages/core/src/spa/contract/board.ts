// Contract of the spa day board, opening hours and the tickets ready for the POS.
import { z } from "zod";
import { appointmentStatusSchema, ticketStatusSchema } from "./appointments";

const uuid = z.string().uuid();
const named = z.object({ id: z.string(), name: z.string() });

/** `spa_day_board` answers one day of the branch. */
export const dayBoardSchema = z.object({
  date: z.string(),
  is_closed: z.boolean(),
  /** HH:MM */
  open_time: z.string(),
  close_time: z.string(),
  staff: z.array(named),
  resources: z.array(named),
  items: z.array(
    z.object({
      id: z.string(),
      appointment_id: z.string(),
      code: z.string(),
      source: z.string(),
      appointment_status: appointmentStatusSchema,
      status: ticketStatusSchema,
      name: z.string(),
      start_at: z.string(),
      end_at: z.string(),
      staff_id: z.string().nullish(),
      resource_id: z.string().nullish(),
      pet_name: z.string().nullish(),
      pet_photo_url: z.string().nullish(),
      customer_name: z.string().nullish(),
    })
  ),
});

/** `spa_week_hours` answers seven days, Monday = 1. */
export const weekHoursSchema = z.array(
  z.object({ weekday: z.number(), open_time: z.string(), close_time: z.string(), is_closed: z.boolean() })
);

/** `billable_appointment_items`: finished tickets of a customer that can be paid at the counter. */
export const billableTicketsSchema = z.array(
  z.object({
    id: z.string(),
    code: z.string(),
    name: z.string(),
    item_type: z.enum(["service", "combo"]),
    pet_id: z.string().nullish(),
    pet_name: z.string().nullish(),
    pet_photo_url: z.string().nullish(),
    unit_price: z.number().nullish(),
  })
);

export const dayHoursInput = z.object({
  weekday: z.number().int().min(1).max(7),
  openTime: z.string(),
  closeTime: z.string(),
  isClosed: z.boolean(),
});
export const saveWeekHoursInput = z.object({ branchId: uuid, hours: z.array(dayHoursInput).length(7) });
export const spaResourceInput = z.object({
  branchId: uuid,
  name: z.string().min(1),
  isActive: z.boolean().optional(),
  sortOrder: z.number().int().optional(),
});
export type DayHours = z.infer<typeof dayHoursInput>;
