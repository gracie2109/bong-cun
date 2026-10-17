import { describe, expect, it } from "vitest";
import {
  attachmentsSchema,
  diagnosisTermPageSchema,
  externalVaccineInput,
  medicalRulesRowSchema,
  petHealthFlagsSchema,
  reminderPageSchema,
  vaccineBookSchema,
  vaccineTypeInput,
  vaccineTypePageSchema,
} from "@bongcun/core/medical";
import {
  toAttachment,
  toDiagnosisTerm,
  toMedicalRules,
  toPetHealthFlags,
  toReminder,
  toVaccineBookEntry,
  toVaccineType,
} from "@bongcun/supabase/medical";

const uuid = "11111111-1111-4111-8111-111111111111";

describe("medical prevention contract", () => {
  it("maps the e-book and fails on an unknown state", () => {
    const row = { vaccine_type_id: "t", name: "Rabies", kind: "vaccine", state: "due_soon", last_given_on: "2026-01-01", doses: [{ id: "d", dose_no: 1, given_on: "2026-01-01", is_external: false }] };
    const [entry] = vaccineBookSchema.parse([row])!.map(toVaccineBookEntry);
    expect(entry).toMatchObject({ nextDueOn: null, doses: [{ lotNo: null, voidedAt: null }] });
    expect(vaccineBookSchema.safeParse([{ ...row, state: "late" }]).success).toBe(false);
  });

  it("maps reminders, vaccine types and diagnosis terms with empty defaults", () => {
    const [reminder] = reminderPageSchema.parse({ rows: [{ kind: "recheck", pet_id: "p", pet_name: "B", customer_id: "c", customer_name: "A", customer_phone: "1", due_on: "2026-10-20" }], total: 1 }).rows!.map(toReminder);
    expect(reminder).toMatchObject({ speciesName: "", vaccineName: null, vaccinationId: null });
    const [type] = vaccineTypePageSchema.parse({ rows: [{ id: "t", name: "Rabies", kind: "vaccine", series_doses: 1, is_active: true, sort_order: 0 }], total: 1 }).rows!.map(toVaccineType);
    expect(type).toMatchObject({ speciesIds: [], stockQty: null, boosterIntervalDays: null });
    const [term] = diagnosisTermPageSchema.parse({ rows: [{ id: "d", name: "Cough", is_contagious: false, is_active: true, sort_order: 0 }], total: 1 }).rows!.map(toDiagnosisTerm);
    expect(term?.speciesNames).toEqual([]);
  });

  it("maps settings, health flags and attachments", () => {
    expect(toMedicalRules(medicalRulesRowSchema.parse({ remind_ahead_days: 7, contagious_days: 30, require_vaccine_for_boarding: false })).examServiceId).toBeNull();
    expect(toPetHealthFlags(petHealthFlagsSchema.parse({ p: { contagious: true, vaccine_overdue: false } })!)).toEqual({
      p: { contagious: true, vaccineOverdue: false, allergies: null },
    });
    const [file] = attachmentsSchema.parse([{ id: "a", visit_id: "v", kind: "lab", title: "T", file_path: "p/v/a.pdf", mime_type: "application/pdf", size_bytes: 5, created_at: "2026-10-18T00:00:00Z" }])!.map(toAttachment);
    expect(file?.createdByName).toBeNull();
    expect(attachmentsSchema.safeParse([{ id: "a", visit_id: "v", kind: "xray", title: "T", file_path: "p", mime_type: "m", size_bytes: 5, created_at: "x" }]).success).toBe(false);
  });

  it("checks the catalog and shot inputs", () => {
    expect(vaccineTypeInput.safeParse({ name: "", kind: "vaccine", speciesIds: [], productId: null, seriesDoses: 1, seriesIntervalDays: null, boosterIntervalDays: null, minAgeWeeks: null, isActive: true, sortOrder: 0 }).success).toBe(false);
    expect(externalVaccineInput.safeParse({ vaccineTypeId: uuid, givenOn: "2026-01-01", externalPlace: "", lotNo: "", expiryDate: "", doseNo: null, nextDueOn: null }).success).toBe(true);
  });
});
