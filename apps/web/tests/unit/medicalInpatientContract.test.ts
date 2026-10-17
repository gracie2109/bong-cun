import { describe, expect, it } from "vitest";
import { admitInput, orderHistorySchema, orderInput, wardSchema } from "@bongcun/core/medical";
import { toInpatientKennel, toOrderHistory, toWard } from "@bongcun/supabase/medical";

const uuid = "11111111-1111-4111-8111-111111111111";

describe("medical in-patient contract", () => {
  it("maps a ward row with empty defaults and fails on an unknown purpose", () => {
    const row = { stay_id: "s", stay_code: "LT1", stay_pet_id: "sp", visit_id: "v", visit_code: "V1", pet_id: "p", pet_name: "B", customer_name: "A", customer_phone: "1", kennel_code: "W1", purpose: "medical", since: "2026-10-17T01:00:00Z", planned_out_at: "2026-10-18T01:00:00Z", overdue: false };
    const ward = toWard(wardSchema.parse({ date: "2026-10-17", rows: [row] }));
    expect(ward.rows[0]).toMatchObject({ petPhotoUrl: null, allergies: null, orders: [], doses: [], lastVitals: null });
    expect(wardSchema.safeParse({ date: "2026-10-17", rows: [{ ...row, purpose: "boarding" }] }).success).toBe(false);
  });

  it("maps orders, doses, kennels and the order history", () => {
    const order = { id: "o", kind: "care", name: "Rest", qty_per_dose: 1, start_on: "2026-10-17", end_on: "2026-10-17" };
    const dose = { id: "d", order_id: "o", due_at: "2026-10-17T00:00:00Z" };
    const ward = toWard(wardSchema.parse({ date: "x", rows: [{ stay_id: "s", stay_code: "c", stay_pet_id: "sp", visit_id: "v", visit_code: "c", pet_id: "p", pet_name: "n", customer_name: "a", customer_phone: "1", kennel_code: "k", purpose: "isolation", since: "t", planned_out_at: "t", overdue: true, orders: [order], doses: [dose] }] }));
    expect(ward.rows[0]?.orders[0]).toMatchObject({ dose: "", times: [], note: "", edited: 0, missed: 0, productId: null });
    expect(ward.rows[0]?.doses[0]).toMatchObject({ givenAt: null, qty: null });
    expect(toInpatientKennel({ id: "k", code: "W1", type_name: "Ward", purpose: "medical", free: true })).toMatchObject({ typeName: "Ward" });
    const [change] = toOrderHistory(orderHistorySchema.parse([{ id: "c", action: "update", before: { dose: "1", qty_per_dose: 1 }, after: null, changed_at: "t" }]) ?? []);
    expect(change).toMatchObject({ reason: null, changedByName: null, after: null, before: { dose: "1", qtyPerDose: 1 } });
    expect(orderHistorySchema.safeParse([{ id: "c", action: "delete", changed_at: "t" }]).success).toBe(false);
  });

  it("checks the inputs", () => {
    expect(admitInput.safeParse({ kennelId: uuid, plannedOutAt: null, note: "" }).success).toBe(true);
    expect(admitInput.safeParse({ kennelId: "x", plannedOutAt: null, note: "" }).success).toBe(false);
    expect(orderInput.safeParse({ stayPetId: uuid, kind: "drug", productId: null, serviceId: null, name: "n", dose: "", qtyPerDose: 1, times: [], startOn: "a", endOn: "b", note: "" }).success).toBe(false);
  });
});
