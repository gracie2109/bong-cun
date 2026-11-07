import { describe, expect, it } from "vitest";
import { timeAgo } from "@/features/admin/notifications/format";

const NOW = new Date("2026-11-07T12:00:00Z").getTime();

describe("timeAgo", () => {
  it("picks the unit by age", () => {
    expect(timeAgo("2026-11-07T11:59:30Z", NOW).unit).toBe("now");
    expect(timeAgo("2026-11-07T11:55:00Z", NOW)).toEqual({ unit: "minutes", value: 5 });
    expect(timeAgo("2026-11-07T09:00:00Z", NOW)).toEqual({ unit: "hours", value: 3 });
    expect(timeAgo("2026-11-05T12:00:00Z", NOW)).toEqual({ unit: "days", value: 2 });
    expect(timeAgo("2026-10-01T12:00:00Z", NOW).unit).toBe("date");
  });
});
