import { describe, expect, it } from "vitest";
import { addDays, addMonths, isoWeekday, mondayOf, monthDays, weekDays } from "@bongcun/core/attendance";

describe("calendar helpers", () => {
  it("numbers weekdays like branch_hours (Monday 1 ... Sunday 7)", () => {
    expect(isoWeekday("2026-11-02")).toBe(1);
    expect(isoWeekday("2026-11-08")).toBe(7);
  });

  it("finds the Monday of any day of the week", () => {
    expect(mondayOf("2026-11-02")).toBe("2026-11-02");
    expect(mondayOf("2026-11-05")).toBe("2026-11-02");
    expect(mondayOf("2026-11-08")).toBe("2026-11-02");
  });

  it("lists seven days across a month and a year boundary", () => {
    expect(weekDays("2026-12-28")).toEqual([
      "2026-12-28", "2026-12-29", "2026-12-30", "2026-12-31", "2027-01-01", "2027-01-02", "2027-01-03",
    ]);
  });

  it("adds days and months without time zone drift", () => {
    expect(addDays("2026-03-01", -1)).toBe("2026-02-28");
    expect(addMonths("2026-01-31", 1)).toBe("2026-02-01");
    expect(addMonths("2026-01-15", -1)).toBe("2025-12-01");
  });

  it("lists the days of a month, leap years included", () => {
    expect(monthDays("2026-11-10")).toHaveLength(30);
    expect(monthDays("2028-02-03")).toHaveLength(29);
    expect(monthDays("2026-12-01")[30]).toBe("2026-12-31");
  });
});
