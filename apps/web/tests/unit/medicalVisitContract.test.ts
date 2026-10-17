import { describe, expect, it } from "vitest";
import {
  billableVisitsSchema,
  checkInInput,
  itemInput,
  prescriptionSchema,
  queueSchema,
  recordInput,
  visitDetailSchema,
  visitPageSchema,
} from "@bongcun/core/medical";
import { toBillableVisit, toDetail, toMedicalVisit, toPrescription, toQueue } from "@bongcun/supabase/medical";

const visit = {
  id: "v1", code: "KB-1", branch_id: "b", status: "waiting", priority: "normal", queue_no: 1, scheduled_at: null, checked_in_at: "2026-10-18T01:00:00Z",
  started_at: null, signed_at: null, created_at: "2026-10-18T01:00:00Z", pet_id: "p", pet_name: "Bông", pet_photo_url: null, species_name: "Dog",
  customer_id: "c", customer_name: "An", customer_phone: "090", reason: null, vet_id: null, vet_name: null, weight_kg: null, outcome: null,
  recheck_on: null, follow_up_of: null, diagnoses_text: null, est_total: 0,
};
const uuid = "11111111-1111-4111-8111-111111111111";

describe("medical visit contract", () => {
  it("maps the queue; queue-only flags default to false", () => {
    const queue = toQueue(queueSchema.parse({ date: "2026-10-18", counts: { scheduled: 0, waiting: 1, in_progress: 0, done: 0 }, rows: [visit] }));
    expect(queue.counts.inProgress).toBe(0);
    expect(queue.rows[0]).toMatchObject({ hasAllergy: false, contagious: false, queueNo: 1, outcome: null });
  });

  it("fails when a visit has an unknown status or outcome", () => {
    expect(visitPageSchema.safeParse({ rows: [{ ...visit, status: "lost" }], total: 1 }).success).toBe(false);
    expect(visitPageSchema.safeParse({ rows: [{ ...visit, outcome: "moved" }], total: 1 }).success).toBe(false);
  });

  it("maps a detail with its record, lines and addenda", () => {
    const detail = toDetail(visitDetailSchema.parse({
      ...visit, source: "counter", branch_name: "B1", pet: { id: "p", name: "Bông", species_name: "Dog", status: "active" },
      items: [{ id: "i", kind: "external", name: "Syrup", qty: 1, unit_price: 0, amount: 0, take_home: true, auto_added: false, created_at: "2026-10-18T01:00:00Z" }],
      diagnoses: [{ id: "d", name: "Cough", is_contagious: false }], addenda: [],
    }));
    expect(detail).toMatchObject({ branchName: "B1", pet: { breed: null, speciesName: "Dog" }, items: [{ kind: "external", dose: null }] });
    expect(toMedicalVisit(visit as never).estTotal).toBe(0);
  });

  it("maps the prescription and the billable visits", () => {
    const rx = toPrescription(prescriptionSchema.parse({
      code: "KB-1", date: "2026-10-18", pet_name: "Bông", customer_name: "An", customer_phone: "090", signed: true,
      items: [{ name: "Syrup", qty: 1, external: true }],
    }));
    expect(rx).toMatchObject({ branchName: "", diagnoses: [], items: [{ unitName: null, external: true }] });
    const [billable] = billableVisitsSchema.parse([{
      visit_id: "v", code: "KB-1", pet_name: "Bông", total: 5, items: [{ id: "i", kind: "service", name: "Exam", qty: 1, unit_price: 5, amount: 5 }],
    }])!.map(toBillableVisit);
    expect(billable?.items[0]).toMatchObject({ unitName: null, amount: 5 });
  });

  it("checks the inputs a screen sends", () => {
    expect(checkInInput.safeParse({ branchId: uuid, customerId: uuid, petId: uuid, reason: "", priority: "urgent", vetId: null, weightKg: null, temperatureC: null }).success).toBe(true);
    expect(checkInInput.safeParse({ branchId: uuid, customerId: uuid, petId: uuid, reason: "", priority: "high", vetId: null, weightKg: null, temperatureC: null }).success).toBe(false);
    expect(itemInput.safeParse({ kind: "external", name: "Syrup", qty: 0, takeHome: false, dose: "", frequency: "", days: null, route: "", instructions: "" }).success).toBe(false);
    expect(recordInput.safeParse({ outcome: "moved" }).success).toBe(false);
  });
});
