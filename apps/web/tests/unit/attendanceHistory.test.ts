import { describe, expect, it } from "vitest";
import { actionTone, diffRows, visibleFields } from "@bongcun/core/attendance";

describe("schedule history helpers", () => {
  it("diffs only the fields that changed", () => {
    expect(diffRows({ note: "a", name: "x" }, { note: "b", name: "x" }, ["note", "name"])).toEqual([{ field: "note", from: "a", to: "b" }]);
  });
  it("treats a missing side as empty", () => {
    expect(diffRows(null, { note: "b" }, ["note"])).toEqual([{ field: "note", from: null, to: "b" }]);
  });
  it("shows changed fields for an update, without bookkeeping columns", () => {
    expect(visibleFields({ action: "update", before: {}, after: {}, changedFields: ["note", "updated_at", "id"] })).toEqual(["note"]);
  });
  it("shows the row's fields for an insert", () => {
    expect(visibleFields({ action: "insert", before: null, after: { id: "1", name: "Morning", note: null }, changedFields: [] })).toEqual(["name", "note"]);
  });
  it("tones the actions", () => {
    expect(actionTone("delete")).toBe("bad");
    expect(actionTone("insert")).toBe("good");
    expect(actionTone("update")).toBe("warn");
  });
});
