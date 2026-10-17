// Online booking and public price list answers -> domain types. Pure: no client, no Vue.
import {
  DEFAULT_BOOKING_RULES,
  type BookingRules,
  type PublicCatalogJson,
  type SpaCatalog,
  type SpaSlot,
  type WebQuote,
} from "@bongcun/core/spa";
import type { z } from "zod";
import type { webQuoteSchema, webRulesSchema, webSlotsSchema } from "@bongcun/core/spa";

export const toBookingRules = (json: z.infer<typeof webRulesSchema>): BookingRules => ({
  minLeadMinutes: json.min_lead_minutes ?? DEFAULT_BOOKING_RULES.minLeadMinutes,
  maxDays: json.max_days ?? DEFAULT_BOOKING_RULES.maxDays,
  maxOpen: json.max_open ?? DEFAULT_BOOKING_RULES.maxOpen,
  cancelBeforeMinutes: json.cancel_before_minutes ?? DEFAULT_BOOKING_RULES.cancelBeforeMinutes,
  stepMinutes: json.step_minutes ?? DEFAULT_BOOKING_RULES.stepMinutes,
  maxBlockMinutes: json.max_block_minutes ?? DEFAULT_BOOKING_RULES.maxBlockMinutes,
});

export const toSpaSlots = (rows: z.infer<typeof webSlotsSchema>): SpaSlot[] =>
  rows.map((row) => ({ startAt: row.start_at, free: row.free }));

export const toWebQuote = (json: z.infer<typeof webQuoteSchema>): WebQuote => ({
  lines: json.items.map((line) => ({
    petId: line.pet_id,
    kind: line.type,
    id: line.id,
    name: line.name,
    minutes: line.minutes,
    price: line.price ?? null,
  })),
  totalMinutes: json.total_minutes,
  totalPrice: json.total_price,
  hasUnpriced: json.has_unpriced,
});

export const toSpaCatalog = (json: PublicCatalogJson): SpaCatalog => ({
  species: json.species.map((item) => ({
    id: item.id,
    name: item.name,
    brackets: item.brackets.map((b) => ({ id: b.id, label: b.label, minKg: b.min_kg, maxKg: b.max_kg ?? null })),
  })),
  services: json.services.map((item) => ({
    id: item.id,
    name: item.name,
    description: item.description ?? "",
    type: item.type === "by_weight" ? "by_weight" : "all",
    durationMinutes: item.duration_minutes ?? null,
    generalPrice: item.general_price ?? null,
    speciesIds: item.species_ids,
    prices: item.prices.map((p) => ({ speciesId: p.species_id, bracketId: p.bracket_id, price: p.price })),
  })),
  combos: json.combos.map((item) => ({
    id: item.id,
    name: item.name,
    description: item.description ?? "",
    price: item.price ?? null,
    originPrice: item.origin_price ?? null,
    durationMinutes: item.duration_minutes ?? null,
    mark: item.mark ?? "4",
    speciesIds: item.species_ids,
    serviceNames: item.service_names,
  })),
});
