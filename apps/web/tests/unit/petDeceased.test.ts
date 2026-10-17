import { describe, expect, it } from "vitest";
import { medicalErrorHint } from "@bongcun/core/medical";
import { toDeceasedPreview } from "@bongcun/supabase/pets";

describe("toDeceasedPreview", () => {
  it("maps the preview and tolerates missing parts", () => {
    const preview = toDeceasedPreview({
      appointments: [{ id: "a1", code: "LH-1", start_at: "2026-10-20T03:00:00Z", branch_name: "Q1", whole: false }],
      blocking: [{ type: "inpatient", id: "s1", code: "NT-1" }],
      open: [{ type: "visit", id: "v1", code: "KB-1", status: "waiting" }],
    });
    expect(preview.appointments).toEqual([
      { id: "a1", code: "LH-1", startAt: "2026-10-20T03:00:00Z", branchName: "Q1", whole: false },
    ]);
    expect(preview.stays).toEqual([]);
    expect(preview.blocking[0]).toEqual({ type: "inpatient", id: "s1", code: "NT-1" });
    expect(preview.open[0]?.type).toBe("visit");
  });

  it("treats an empty answer as nothing to cancel", () => {
    expect(toDeceasedPreview(null).visits).toEqual([]);
  });
});

describe("pet_in_kennel", () => {
  it("is a known medical error hint", () => {
    expect(medicalErrorHint({ hint: "pet_in_kennel" })).toBe("pet_in_kennel");
  });
});
