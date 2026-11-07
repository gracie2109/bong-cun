import { describe, expect, it } from "vitest";
import { availabilityIssue, crossesMidnight, groupByWeekday, isWholeDay } from "@bongcun/core/attendance";
import type { AvailabilityItem } from "@bongcun/core/attendance";

const item = (over: Partial<AvailabilityItem> = {}): AvailabilityItem => ({
  weekday: 1,
  kind: "unavailable",
  startTime: null,
  endTime: null,
  note: null,
  ...over,
});

describe("availability helpers", () => {
  it("knows a whole day and a night range", () => {
    expect(isWholeDay(item())).toBe(true);
    expect(isWholeDay(item({ startTime: "08:00", endTime: "12:00" }))).toBe(false);
    expect(crossesMidnight(item({ startTime: "20:00", endTime: "08:00" }))).toBe(true);
    expect(crossesMidnight(item({ startTime: "08:00", endTime: "12:00" }))).toBe(false);
  });

  it("flags half-filled and empty ranges and too many rows", () => {
    expect(availabilityIssue([item()])).toBeNull();
    expect(availabilityIssue([item({ startTime: "08:00" })])).toBe("time_incomplete");
    expect(availabilityIssue([item({ startTime: "08:00", endTime: "08:00" })])).toBe("time_same");
    expect(availabilityIssue(Array.from({ length: 22 }, () => item()))).toBe("too_many");
  });

  it("groups by weekday with the whole day first", () => {
    const grouped = groupByWeekday([item({ weekday: 3, startTime: "10:00", endTime: "12:00" }), item({ weekday: 3 })]);
    expect(grouped.get(3)?.[0]?.startTime).toBeNull();
    expect(grouped.get(2)).toEqual([]);
  });
});
