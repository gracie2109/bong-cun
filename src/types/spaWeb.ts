export type BookingKind = "service" | "combo";

/** One thing chosen for one pet. `minutes` and `name` come from the public catalog, for the step summary. */
export type BookingPick = { kind: BookingKind; id: string; name: string; minutes: number };

/** What the booking RPCs take: one entry per ticket. */
export type BookingItem = { petId: string; kind: BookingKind; id: string };

/** A start time of the chosen block and whether a table is free for all of it. */
export type SpaSlot = { startAt: string; free: boolean };

export type QuoteLine = { petId: string; kind: BookingKind; id: string; name: string; minutes: number; price: number | null };

/** The server's quote: total length of the visit and the estimated price (unpriced lines excluded). */
export type WebQuote = { lines: QuoteLine[]; totalMinutes: number; totalPrice: number; hasUnpriced: boolean };

export type BookingRules = {
  minLeadMinutes: number;
  maxDays: number;
  maxOpen: number;
  cancelBeforeMinutes: number;
  stepMinutes: number;
  maxBlockMinutes: number;
};

export const DEFAULT_BOOKING_RULES: BookingRules = {
  minLeadMinutes: 120,
  maxDays: 30,
  maxOpen: 3,
  cancelBeforeMinutes: 120,
  stepMinutes: 15,
  maxBlockMinutes: 600,
};

export type BookingInput = { branchId: string; startAt: string; note: string; items: BookingItem[] };
export type BookingResult = { id: string; code: string };

export const BOOKING_STEPS = ["branch", "pets", "slot", "confirm"] as const;
export type BookingStep = (typeof BOOKING_STEPS)[number];
