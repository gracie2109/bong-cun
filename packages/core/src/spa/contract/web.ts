// Contract of the online spa booking functions and the public price list. A reader on the
// server-rendered shop pages fails loudly (the RPC name and the key) when a shape changes.
import { z } from "zod";

const uuid = z.string().uuid();

export const bookingKindSchema = z.enum(["service", "combo"]);
export type BookingKind = z.infer<typeof bookingKindSchema>;

// ---------------------------------------------------------------- inputs
/** What the booking RPCs take: one entry per ticket. */
export const bookingItemInput = z.object({ petId: uuid, kind: bookingKindSchema, id: uuid });
export type BookingItem = z.infer<typeof bookingItemInput>;

/** `book_my_appointment`: the signed-in customer books one visit. */
export const bookingInputSchema = z.object({
  branchId: uuid,
  startAt: z.string(),
  note: z.string(),
  items: z.array(bookingItemInput).min(1),
});
export type BookingInput = z.infer<typeof bookingInputSchema>;

// ---------------------------------------------------------------- results
/** `spa_web_rules`: the rules are the server's; a missing key falls back to the default. */
export const webRulesSchema = z.object({
  min_lead_minutes: z.number().nullish(),
  max_days: z.number().nullish(),
  max_open: z.number().nullish(),
  cancel_before_minutes: z.number().nullish(),
  step_minutes: z.number().nullish(),
  max_block_minutes: z.number().nullish(),
});

/** `spa_web_slots`: start times of one day and whether a table is free for the whole block. */
export const webSlotsSchema = z.array(z.object({ start_at: z.string(), free: z.boolean() }));

/** `spa_web_quote`: the visit's length and the estimated price. */
export const webQuoteSchema = z.object({
  items: z.array(
    z.object({
      pet_id: z.string(),
      type: bookingKindSchema,
      id: z.string(),
      name: z.string(),
      minutes: z.number(),
      price: z.number().nullish(),
    })
  ),
  total_minutes: z.number(),
  total_price: z.number(),
  has_unpriced: z.boolean(),
});

/** `book_my_appointment` answers `{ id, code }`. */
export const bookedAppointmentSchema = z.object({ id: z.string(), code: z.string() });

/** `spa_public_catalog`: the price list anyone can read. */
export const publicCatalogSchema = z.object({
  species: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      brackets: z.array(
        z.object({ id: z.string(), label: z.string(), min_kg: z.number(), max_kg: z.number().nullish() })
      ),
    })
  ),
  services: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      description: z.string().nullish(),
      type: z.string(),
      duration_minutes: z.number().nullish(),
      general_price: z.number().nullish(),
      species_ids: z.array(z.string()),
      prices: z.array(z.object({ species_id: z.string(), bracket_id: z.string(), price: z.number() })),
    })
  ),
  combos: z.array(
    z.object({
      id: z.string(),
      name: z.string(),
      description: z.string().nullish(),
      price: z.number().nullish(),
      origin_price: z.number().nullish(),
      duration_minutes: z.number().nullish(),
      mark: z.string().nullish(),
      species_ids: z.array(z.string()),
      service_names: z.array(z.string()),
    })
  ),
});
export type PublicCatalogJson = z.infer<typeof publicCatalogSchema>;
