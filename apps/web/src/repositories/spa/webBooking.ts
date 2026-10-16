// Booking spa visits from the website: rules, free slots, a quote and the booking itself.
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/types/database.types";
import {
  DEFAULT_BOOKING_RULES,
  type BookingInput,
  type BookingItem,
  type BookingResult,
  type BookingRules,
  type BookingKind,
  type SpaSlot,
  type WebQuote,
} from "@/types/spaWeb";
import { unwrap } from "../shared";

type Client = SupabaseClient<Database>;

type RulesJson = Partial<{
  min_lead_minutes: number;
  max_days: number;
  max_open: number;
  cancel_before_minutes: number;
  step_minutes: number;
  max_block_minutes: number;
}>;

type QuoteJson = {
  items: { pet_id: string; type: string; id: string; name: string; minutes: number; price: number | null }[];
  total_minutes: number;
  total_price: number;
  has_unpriced: boolean;
};

const toKind = (value: string): BookingKind => (value === "combo" ? "combo" : "service");

const itemsJson = (items: BookingItem[]) => items.map((item) => ({ pet_id: item.petId, type: item.kind, id: item.id }));

export const getSpaWebRules = async (client: Client): Promise<BookingRules> => {
  const json = unwrap(await client.rpc("spa_web_rules")) as RulesJson;
  return {
    minLeadMinutes: json.min_lead_minutes ?? DEFAULT_BOOKING_RULES.minLeadMinutes,
    maxDays: json.max_days ?? DEFAULT_BOOKING_RULES.maxDays,
    maxOpen: json.max_open ?? DEFAULT_BOOKING_RULES.maxOpen,
    cancelBeforeMinutes: json.cancel_before_minutes ?? DEFAULT_BOOKING_RULES.cancelBeforeMinutes,
    stepMinutes: json.step_minutes ?? DEFAULT_BOOKING_RULES.stepMinutes,
    maxBlockMinutes: json.max_block_minutes ?? DEFAULT_BOOKING_RULES.maxBlockMinutes,
  };
};

/** Start times on one business day (yyyy-mm-dd) for a block of `minutes`. */
export const listSpaWebSlots = async (client: Client, branchId: string, date: string, minutes: number): Promise<SpaSlot[]> =>
  (
    unwrap(await client.rpc("spa_web_slots", { p_branch: branchId, p_date: date, p_minutes: minutes })) as {
      start_at: string;
      free: boolean;
    }[]
  ).map((row) => ({ startAt: row.start_at, free: row.free }));

export const quoteSpaWeb = async (client: Client, branchId: string, items: BookingItem[]): Promise<WebQuote> => {
  const json = unwrap(await client.rpc("spa_web_quote", { p_branch: branchId, p_items: itemsJson(items) })) as QuoteJson;
  return {
    lines: json.items.map((line) => ({
      petId: line.pet_id,
      kind: toKind(line.type),
      id: line.id,
      name: line.name,
      minutes: line.minutes,
      price: line.price === null ? null : Number(line.price),
    })),
    totalMinutes: json.total_minutes,
    totalPrice: Number(json.total_price),
    hasUnpriced: json.has_unpriced,
  };
};

export const bookMyAppointment = async (client: Client, input: BookingInput): Promise<BookingResult> =>
  unwrap(
    await client.rpc("book_my_appointment", {
      p: { branch_id: input.branchId, start_at: input.startAt, note: input.note.trim(), items: itemsJson(input.items) },
    })
  ) as BookingResult;

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
