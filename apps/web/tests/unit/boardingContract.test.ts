import { describe, expect, it } from "vitest";
import {
  billableStaysSchema,
  checkoutPreviewSchema,
  quoteSchema,
  stayInput,
  stayPageSchema,
  typeAvailabilitySchema,
} from "@bongcun/core/boarding";
import { toBillableStay, toBoardingStay, toCheckoutPreview, toQuote, toTypeAvailability } from "@bongcun/supabase/boarding";

const stay = {
  id: "s1", code: "LT-1", branch_id: "b1", status: "booked", customer_id: "c1", customer_name: "An", customer_phone: "090",
  planned_in_at: "2026-10-18T02:00:00Z", planned_out_at: "2026-10-20T02:00:00Z", checked_in_at: null, checked_out_at: null,
  source: "counter", kind: "boarding", visit_id: null, visit_code: null, emergency_phone: null, note: null, cancel_reason: null,
  est_total: 200000,
  pets: [{
    id: "sp1", line_no: 1, pet_id: "p1", pet_name: "Bông", pet_photo_url: null, status: "active", kennel_type_id: "t1",
    kennel_type_name: "Room", kennel_id: "k1", kennel_code: "K1", nights_from: "2026-10-18", nights_to: "2026-10-20",
    charged_nights: 2, is_extra_pet: false, est_night_price: 100000, night_price: null, weight_kg: null, vaccine_checked: false,
    vaccine_note: null, belongings: null, belongings_returned: false, feeding: null, medication: null, has_notes: true,
  }],
};

describe("boarding contract", () => {
  it("maps a stay page; the list carries no care logs or charges", () => {
    const page = stayPageSchema.parse({ rows: [stay], total: 1 });
    const [mapped] = page.rows!.map(toBoardingStay);
    expect(mapped).toMatchObject({ code: "LT-1", visitId: null, careLogs: [], charges: [], pets: [{ kennelCode: "K1", nightPrice: null }] });
  });

  it("fails when a stay has an unknown status", () => {
    expect(stayPageSchema.safeParse({ rows: [{ ...stay, status: "lost" }], total: 1 }).success).toBe(false);
  });

  it("maps a quote and its warnings", () => {
    const quote = toQuote(quoteSchema.parse({
      id: "x", code: "y", nights: 2, total: 200000,
      items: [{
        line_no: 1, pet_id: "p1", pet_name: "Bông", kennel_type_id: "t1", kennel_type_name: "Room", kennel_id: "k1",
        kennel_code: "K1", is_extra_pet: false, night_price: 100000, amount: 200000, warnings: ["behavior"],
      }],
    }));
    expect(quote.items[0]?.warnings).toEqual(["behavior"]);
    expect(quoteSchema.safeParse({ nights: 1, total: 1, items: [{ warnings: ["bite"] }] }).success).toBe(false);
  });

  it("maps availability, the checkout preview and billable stays", () => {
    expect(toTypeAvailability(typeAvailabilitySchema.parse([{ kennel_type_id: "t", name: "Room", total: 2, free: 1, night_price: null }])![0]!))
      .toEqual({ kennelTypeId: "t", name: "Room", total: 2, free: 1, nightPrice: null });
    const preview = toCheckoutPreview(checkoutPreviewSchema.parse({
      at: "2026-10-20T02:00:00Z", total: 200000,
      items: [{ stay_pet_id: "sp1", pet_name: "Bông", kind: "night", name: "Night", qty: 2, unit_price: 100000, amount: 200000 }],
      belongings: [{ stay_pet_id: "sp1", pet_name: "Bông", belongings: "Bed", returned: false }],
    }));
    expect(preview.items[0]).toMatchObject({ kind: "night", unitPrice: 100000 });
    const [billable] = billableStaysSchema.parse([{
      stay_id: "s1", code: "LT-1", total: 5, charges: [{ id: "c", kind: "night", name: "Night", qty: 1, unit_price: 5, amount: 5, pet_name: null, pet_photo_url: null }],
    }])!.map(toBillableStay);
    expect(billable?.charges[0]).toMatchObject({ petName: null, amount: 5 });
  });

  it("needs at least one pet to book", () => {
    const uuid = "11111111-1111-4111-8111-111111111111";
    const base = { customerId: uuid, plannedInAt: "a", plannedOutAt: "b", source: "counter", emergencyPhone: "", note: "" };
    expect(stayInput.safeParse({ ...base, pets: [] }).success).toBe(false);
    expect(stayInput.safeParse({ ...base, pets: [{ petId: uuid, kennelTypeId: uuid }] }).success).toBe(true);
  });
});
