import { describe, expect, it } from "vitest";
import { updateOrderInput, updateOrderResultSchema, type WardOrder } from "@bongcun/core/medical";
import { changedFields } from "@/features/admin/medical/ward/orderHistoryText";
import { editDraftFromOrder, hasOrderChanges, toUpdateInput } from "@/features/admin/medical/ward/orderEditDraft";

const order: WardOrder = {
  id: "o1", kind: "product", productId: "p1", serviceId: null, name: "Amoxicillin", dose: "1 tablet", qtyPerDose: 1,
  times: ["08:00", "20:00"], startOn: "2026-10-01", endOn: "2026-10-05", note: "", edited: 0, missed: 0,
};

describe("order edit contract", () => {
  it("accepts a partial edit and rejects bad hours or an end before the start", () => {
    expect(updateOrderInput.safeParse({ times: ["07:30"] }).success).toBe(true);
    expect(updateOrderInput.safeParse({ times: ["7:30"] }).success).toBe(false);
    expect(updateOrderInput.safeParse({ times: [] }).success).toBe(false);
    expect(updateOrderInput.safeParse({ startOn: "2026-10-05", endOn: "2026-10-01" }).success).toBe(false);
  });

  it("reads the answer of update_inpatient_order", () => {
    expect(updateOrderResultSchema.safeParse({ id: "x", doses_added: 1, doses_removed: 2 }).success).toBe(true);
    expect(updateOrderResultSchema.safeParse({ id: "x" }).success).toBe(false);
  });
});

describe("order edit draft", () => {
  it("sends only what changed", () => {
    const draft = { ...editDraftFromOrder(order), qtyPerDose: 2, times: ["20:00", "08:00"] };
    expect(toUpdateInput(order, draft)).toEqual({ qtyPerDose: 2 });
  });

  it("sends the reason but does not count it as a change", () => {
    const input = toUpdateInput(order, { ...editDraftFromOrder(order), reason: "vet advice" });
    expect(input).toEqual({ reason: "vet advice" });
    expect(hasOrderChanges(input)).toBe(false);
  });
});

describe("order history text", () => {
  it("lists the fields that differ", () => {
    expect(changedFields({ dose: "1", times: ["08:00"] }, { dose: "2", times: ["08:00"] })).toEqual([{ field: "dose", before: "1", after: "2" }]);
  });
});
