import { describe, expect, it } from "vitest";
import { addMonths, isUsableRange, monthEnd, monthStart, rangeDays } from "@/features/admin/attendance/timesheet/timesheetRange";

describe("timesheet ranges", () => {
  it("finds month bounds across years and leap days", () => {
    expect(monthStart("2026-11-17")).toBe("2026-11-01");
    expect(addMonths("2026-11-01", 2)).toBe("2027-01-01");
    expect(addMonths("2026-01-01", -1)).toBe("2025-12-01");
    expect(monthEnd("2028-02-01")).toBe("2028-02-29");
    expect(monthEnd("2026-12-01")).toBe("2026-12-31");
  });

  it("counts both ends and refuses ranges that are reversed or too long", () => {
    expect(rangeDays("2026-11-01", "2026-11-01")).toBe(1);
    expect(isUsableRange("2026-11-01", "2026-11-30")).toBe(true);
    expect(isUsableRange("2026-11-30", "2026-11-01")).toBe(false);
    expect(isUsableRange("2026-01-01", "2026-04-04")).toBe(false);
    expect(isUsableRange("", "2026-11-01")).toBe(false);
  });
});
