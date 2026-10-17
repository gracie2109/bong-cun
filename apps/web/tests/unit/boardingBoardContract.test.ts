import { describe, expect, it } from "vitest";
import {
  boardSchema,
  boardingRulesRowSchema,
  kennelInput,
  kennelPageSchema,
  kennelTypeInput,
  kennelTypePageSchema,
  publicCatalogSchema,
  timelineSchema,
} from "@bongcun/core/boarding";
import { toBoardingRules, toDayBoard, toKennel, toKennelType, toPublicCatalog, toTimeline } from "@bongcun/supabase/boarding";

const pet = {
  stay_id: "s", stay_code: "LT-1", stay_status: "checked_in", stay_pet_id: "sp", pet_id: "p", pet_name: "Bông", pet_photo_url: null,
  customer_name: "An", planned_in_at: "a", planned_out_at: "b", has_notes: false, overdue: false, kind: "inpatient", visit_id: "v", visit_code: "KB-1",
};

describe("boarding board contract", () => {
  it("maps the day board, including the inpatient kind and count", () => {
    const board = toDayBoard(boardSchema.parse({
      date: "2026-10-18",
      counts: { arriving: 0, departing: 0, occupied: 1, overdue: 0, free: 0, inpatient: 1 },
      kennels: [{ id: "k", code: "K1", name: null, kennel_type_id: "t", kennel_type_name: "Room", purpose: "medical", status: "ready", state: "occupied", conflict: false, pets: [pet], arriving: [] }],
    }));
    expect(board.counts.inpatient).toBe(1);
    expect(board.kennels[0]?.pets[0]).toMatchObject({ kind: "inpatient", visitCode: "KB-1", petPhotoUrl: null });
  });

  it("fails when a kennel has an unknown state", () => {
    const bad = { date: "d", counts: { arriving: 0, departing: 0, occupied: 0, overdue: 0, free: 0, inpatient: 0 }, kennels: [{ state: "lost" }] };
    expect(boardSchema.safeParse(bad).success).toBe(false);
  });

  it("maps the calendar, kennels, kennel types, rules and the public catalog", () => {
    expect(toTimeline(timelineSchema.parse({ from: "2026-10-18", days: 7, kennels: [] }))).toEqual({ from: "2026-10-18", days: 7, kennels: [] });
    const [kennel] = kennelPageSchema.parse({ rows: [{ id: "k", branch_id: "b", kennel_type_id: "t", kennel_type_name: "Room", code: "K1", name: null, status: "ready", is_active: true, sort_order: 0 }], total: 1 }).rows!.map(toKennel);
    expect(kennel).toMatchObject({ code: "K1", name: null });
    const [type] = kennelTypePageSchema.parse({ rows: [{ id: "t", name: "Room", max_pets: 1, purpose: "boarding", is_active: true, is_public: true, sort_order: 0, has_branch_price: false, kennel_count: 2, night_price: 100000 }], total: 1 }).rows!.map(toKennelType);
    expect(type).toMatchObject({ speciesIds: [], branchPrices: [], nightPrice: 100000, sharedNightPrice: null });
    expect(toBoardingRules(boardingRulesRowSchema.parse({ check_in_from: "08:00", check_out_by: "12:00", late_half_until: "18:00", max_nights: 30, day_stay_nights: 1 })).maxNights).toBe(30);
    expect(toPublicCatalog(publicCatalogSchema.parse({ branch: { id: "b", name: "B", phone: null }, rules: null, kennel_types: [] })).branch?.phone).toBe("");
  });

  it("needs a code for a kennel and a name for a kennel type", () => {
    const uuid = "11111111-1111-4111-8111-111111111111";
    expect(kennelInput.safeParse({ branchId: uuid, kennelTypeId: uuid, code: "", name: null, isActive: true, sortOrder: 0 }).success).toBe(false);
    expect(kennelTypeInput.safeParse({ name: "", description: null, photoUrl: null, speciesIds: [], maxWeightKg: null, maxPets: 1, isActive: true, isPublic: true, sortOrder: 0, sharedNightPrice: 1, sharedExtraPetNightPrice: null, branchPrices: [] }).success).toBe(false);
  });
});
