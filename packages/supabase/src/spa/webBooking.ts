// Booking spa visits from the website: rules, free slots, a quote and the booking itself.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import type { BookingInput, BookingItem, BookingResult, BookingRules, SpaSlot, WebQuote } from "@bongcun/core/spa";
import { bookedAppointmentSchema, webQuoteSchema, webRulesSchema, webSlotsSchema } from "@bongcun/core/spa";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toBookingRules, toSpaSlots, toWebQuote } from "./mappers";

type Client = SupabaseClient<Database>;

const itemsJson = (items: BookingItem[]) => items.map((item) => ({ pet_id: item.petId, type: item.kind, id: item.id }));

export const getSpaWebRules = async (client: Client): Promise<BookingRules> =>
  toBookingRules(parseRpc("spa_web_rules", webRulesSchema, unwrap(await client.rpc("spa_web_rules"))));

/** Start times on one business day (yyyy-mm-dd) for a block of `minutes`. */
export const listSpaWebSlots = async (client: Client, branchId: string, date: string, minutes: number): Promise<SpaSlot[]> =>
  toSpaSlots(
    parseRpc(
      "spa_web_slots",
      webSlotsSchema,
      unwrap(await client.rpc("spa_web_slots", { p_branch: branchId, p_date: date, p_minutes: minutes }))
    )
  );

export const quoteSpaWeb = async (client: Client, branchId: string, items: BookingItem[]): Promise<WebQuote> =>
  toWebQuote(
    parseRpc(
      "spa_web_quote",
      webQuoteSchema,
      unwrap(await client.rpc("spa_web_quote", { p_branch: branchId, p_items: itemsJson(items) }))
    )
  );

export const bookMyAppointment = async (client: Client, input: BookingInput): Promise<BookingResult> =>
  parseRpc(
    "book_my_appointment",
    bookedAppointmentSchema,
    unwrap(
      await client.rpc("book_my_appointment", {
        p: { branch_id: input.branchId, start_at: input.startAt, note: input.note.trim(), items: itemsJson(input.items) },
      })
    )
  );

/** Error hints raised by the booking RPCs, for readable messages. */
export const BOOKING_ERROR_HINTS = [
  "no_customer",
  "empty",
  "no_pet",
  "unavailable",
  "wrong_species",
  "bad_time",
  "too_soon",
  "too_far",
  "too_many",
  "closed",
  "outside_hours",
  "slot_full",
  "pet_busy",
] as const;
export type BookingErrorHint = (typeof BOOKING_ERROR_HINTS)[number];

export const bookingErrorHint = (error: unknown): BookingErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return BOOKING_ERROR_HINTS.find((item) => item === hint) ?? null;
};
