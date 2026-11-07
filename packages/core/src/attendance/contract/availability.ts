// Weekly availability: what a person told the manager about the days and hours they can work.
import { z } from "zod";

const uuid = z.string().uuid();
const time = z.string().regex(/^\d{2}:\d{2}$/);

export const availabilityKindSchema = z.enum(["unavailable", "preferred"]);
export type AvailabilityKind = z.infer<typeof availabilityKindSchema>;

/** One row as a person edits it. Both times empty = the whole day; end before start crosses midnight. */
export const availabilityItemInput = z.object({
  /** 1 = Monday ... 7 = Sunday (ISO). */
  weekday: z.number().int().min(1).max(7),
  kind: availabilityKindSchema,
  startTime: time.nullable(),
  endTime: time.nullable(),
  note: z.string().max(200).nullable(),
});
export type AvailabilityItem = z.infer<typeof availabilityItemInput>;

export const MAX_AVAILABILITY_ITEMS = 21;

// ---------------------------------------------------------------- results
export const availabilityRowSchema = z.object({
  id: uuid.optional(),
  weekday: z.number().int().min(1).max(7),
  kind: availabilityKindSchema,
  start_time: time.nullish(),
  end_time: time.nullish(),
  note: z.string().nullish(),
});
export const availabilityListSchema = z.array(availabilityRowSchema);
export type AvailabilityRow = z.infer<typeof availabilityRowSchema>;
