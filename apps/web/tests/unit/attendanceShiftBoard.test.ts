import { describe, expect, it } from "vitest";
import type { Roster } from "@bongcun/core/attendance";
import { isoWeekOf } from "@bongcun/core/attendance";
import { buildShiftBoard } from "@/features/admin/attendance/roster/shiftBoard";
import { weeksOfMonth } from "@/features/admin/attendance/shared/weekCalendar";

const staff = (userId: string, name: string) => ({ userId, name, role: "cashier", photoUrl: null });
const shift = (id: string, userId: string, workDate: string, templateId: string, name: string, startAt: string, endAt: string) => ({
  id, userId, workDate, templateId, name, color: "teal" as const, startAt, endAt, breakMinutes: 0, note: null, hasEntry: false,
});
const template = (id: string, name: string, startTime: string, endTime: string, isActive = true) => ({
  id, branchId: "b", name, startTime, endTime, breakMinutes: 0, color: "teal" as const, isActive, sortOrder: 0, overnight: false,
});

const roster: Roster = {
  staff: [staff("u1", "Binh"), staff("u2", "An")],
  templates: [template("t1", "Sang", "07:30", "12:00"), template("t2", "Chieu", "12:00", "16:30"), template("t3", "Cu", "08:00", "09:00", false)],
  assignments: [
    shift("a", "u1", "2026-11-09", "t1", "Sang", "2026-11-09T00:30:00Z", "2026-11-09T05:00:00Z"),
    shift("b", "u2", "2026-11-09", "t1", "Sang", "2026-11-09T00:30:00Z", "2026-11-09T05:00:00Z"),
  ],
  leaves: [],
  requests: [],
  availability: [],
};
const days = ["2026-11-09", "2026-11-10"];

describe("buildShiftBoard", () => {
  it("lists who works each shift per day, sorted by name, and counts the day", () => {
    const board = buildShiftBoard(roster, days);
    const morning = board.rows.find((row) => row.name === "Sang");
    expect(morning?.cells["2026-11-09"]?.map((entry) => entry.staff.name)).toEqual(["An", "Binh"]);
    expect(board.dayTotals["2026-11-09"]).toBe(2);
    expect(board.dayTotals["2026-11-10"]).toBe(0);
  });

  it("keeps a row for an active template nobody works, and none for a retired one", () => {
    const names = buildShiftBoard(roster, days).rows.map((row) => row.name);
    expect(names).toEqual(["Sang", "Chieu"]);
  });
});

describe("week calendar", () => {
  it("numbers ISO weeks", () => {
    expect(isoWeekOf("2026-11-02")).toEqual({ year: 2026, week: 45 });
    expect(isoWeekOf("2027-01-01")).toEqual({ year: 2026, week: 53 });
  });

  it("builds Monday-first weeks that cover the month", () => {
    const weeks = weeksOfMonth("2026-11-01");
    expect(weeks[0]?.monday).toBe("2026-10-26");
    expect(weeks[weeks.length - 1]?.days).toContain("2026-11-30");
    expect(weeks.every((week) => week.days.length === 7)).toBe(true);
  });
});
