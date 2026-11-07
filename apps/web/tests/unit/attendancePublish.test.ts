import { describe, expect, it } from "vitest";
import { hoursUntil, publishWarnings, staffCanEditWeek } from "@bongcun/core/attendance";

describe("publishing helpers", () => {
  it("locks a published week only for a branch that publishes", () => {
    expect(staffCanEditWeek({ requirePublish: true, status: "published" })).toBe(false);
    expect(staffCanEditWeek({ requirePublish: true, status: "draft" })).toBe(true);
    expect(staffCanEditWeek({ requirePublish: false, status: "published" })).toBe(true);
  });
  it("lists what the publish dialog warns about", () => {
    expect(publishWarnings({ shifts: 0, pendingRequests: 2, missing: 1 })).toEqual(["empty", "pending", "missing"]);
    expect(publishWarnings({ shifts: 5, pendingRequests: 0, missing: 0 })).toEqual([]);
  });
  it("counts hours to a deadline, never below zero", () => {
    const now = new Date("2026-11-07T00:00:00Z").getTime();
    expect(hoursUntil("2026-11-07T10:30:00Z", now)).toBe(11);
    expect(hoursUntil("2026-11-06T10:30:00Z", now)).toBe(0);
    expect(hoursUntil(null, now)).toBe(0);
  });
});
