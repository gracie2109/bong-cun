import { describe, expect, it } from "vitest";
import { publicCatalogSchema, webQuoteSchema, webRulesSchema, DEFAULT_BOOKING_RULES } from "@bongcun/core/spa";
import { toBookingRules, toSpaCatalog, toWebQuote } from "@bongcun/supabase/spa";

describe("online spa contract", () => {
  it("falls back to the default rules for a missing key", () => {
    expect(toBookingRules(webRulesSchema.parse({ max_days: 7 }))).toEqual({ ...DEFAULT_BOOKING_RULES, maxDays: 7 });
  });

  it("maps a quote and keeps an unpriced line null", () => {
    const quote = toWebQuote(
      webQuoteSchema.parse({
        items: [{ pet_id: "p", type: "combo", id: "c", name: "Combo", minutes: 60, price: null }],
        total_minutes: 60, total_price: 0, has_unpriced: true,
      })
    );
    expect(quote.lines[0]).toMatchObject({ kind: "combo", price: null });
    expect(quote.hasUnpriced).toBe(true);
  });

  it("fails when the catalog misses a list", () => {
    expect(publicCatalogSchema.safeParse({ species: [], services: [] }).success).toBe(false);
  });

  it("maps catalog nulls to the defaults screens expect", () => {
    const catalog = toSpaCatalog(
      publicCatalogSchema.parse({
        species: [],
        services: [{ id: "s", name: "Wash", description: null, type: "all", duration_minutes: null, general_price: 5, species_ids: [], prices: [] }],
        combos: [],
      })
    );
    expect(catalog.services[0]).toMatchObject({ description: "", type: "all", durationMinutes: null, generalPrice: 5 });
  });
});
