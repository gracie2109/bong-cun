import { describe, expect, it } from "vitest";
import { effectivePart, emptyLeaveDraft, leaveDraftError, toRequestInput } from "@/features/admin/attendance/leave/leaveDraft";

const draft = (patch: Partial<ReturnType<typeof emptyLeaveDraft>> = {}) => ({ ...emptyLeaveDraft("b1", "2026-11-09"), reason: "Trip", ...patch });

describe("leave draft", () => {
  it("accepts a filled form and rejects each gap", () => {
    expect(leaveDraftError(draft(), false)).toBeNull();
    expect(leaveDraftError(draft({ branchId: "" }), false)).toBe("branch_required");
    expect(leaveDraftError(draft(), true)).toBe("staff_required");
    expect(leaveDraftError(draft({ userId: "u" }), true)).toBeNull();
    expect(leaveDraftError(draft({ fromDate: "" }), false)).toBe("dates_required");
    expect(leaveDraftError(draft({ toDate: "2026-11-08" }), false)).toBe("range_invalid");
    expect(leaveDraftError(draft({ reason: "  " }), false)).toBe("reason_required");
  });

  it("keeps a half day only for a single day", () => {
    expect(effectivePart(draft({ part: "am" }))).toBe("am");
    expect(effectivePart(draft({ part: "am", toDate: "2026-11-10" }))).toBe("full");
    expect(toRequestInput(draft({ part: "pm", toDate: "2026-11-10", reason: " Trip " }))).toMatchObject({ part: "full", reason: "Trip" });
  });
});
