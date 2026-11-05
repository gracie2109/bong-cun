import { describe, expect, it } from "vitest";
import type { Roster } from "@bongcun/core/attendance";
import { buildRosterGrid } from "@/features/admin/attendance/roster/rosterGrid";

const staff = (userId: string, name: string) => ({ userId, name, role: "cashier", photoUrl: null });
const shift = (id: string, userId: string, workDate: string, startAt: string) => ({
  id, userId, workDate, templateId: null, name: "Day", color: "teal" as const, startAt, endAt: startAt, breakMinutes: 0, note: null, hasEntry: false,
});

const roster: Roster = {
  staff: [staff("u1", "An"), staff("u2", "Binh")],
  templates: [],
  assignments: [
    shift("b", "u1", "2026-11-02", "2026-11-02T08:00:00Z"),
    shift("a", "u1", "2026-11-02", "2026-11-02T01:00:00Z"),
    shift("c", "u2", "2026-11-03", "2026-11-03T01:00:00Z"),
  ],
  leaves: [{ userId: "u2", fromDate: "2026-11-02", toDate: "2026-11-02", part: "am", leaveType: "sick" }],
};
const days = ["2026-11-02", "2026-11-03"];

describe("buildRosterGrid", () => {
  const rows = buildRosterGrid(roster, days);

  it("makes one row per person with one cell per day", () => {
    expect(rows.map((row) => row.staff.name)).toEqual(["An", "Binh"]);
    expect(rows[0]!.cells.map((cell) => cell.date)).toEqual(days);
  });

  it("puts the shifts of a day in time order", () => {
    expect(rows[0]!.cells[0]!.assignments.map((item) => item.id)).toEqual(["a", "b"]);
    expect(rows[0]!.shiftCount).toBe(2);
  });

  it("shows leave on the days it covers only", () => {
    expect(rows[1]!.cells[0]!.leave?.leaveType).toBe("sick");
    expect(rows[1]!.cells[1]!.leave).toBeNull();
    expect(rows[0]!.cells[0]!.leave).toBeNull();
  });
});
