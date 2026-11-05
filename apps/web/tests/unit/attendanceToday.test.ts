import { describe, expect, it } from "vitest";
import { buildStaffLines, summarize } from "@/features/admin/attendance/today/todayBoard";
import { draftError, toEditInput } from "@/features/admin/attendance/today/entryDraft";
import { formatMinutes, fromLocalInput, toLocalInput } from "@/features/admin/attendance/shared/attendanceFormat";
import type { AttendanceRow, TodayBoard } from "@bongcun/core/attendance";

const row = (userId: string, patch: Partial<AttendanceRow>): AttendanceRow => ({
  branchId: "b", userId, userName: userId, workDate: "2026-11-09", assignmentId: null, entryId: null, shiftName: "Day",
  startAt: null, endAt: null, checkInAt: null, checkOutAt: null, scheduledMinutes: 0, workedMinutes: 0, lateMinutes: 0,
  earlyMinutes: 0, overtimeMinutes: 0, status: "upcoming", leaveType: null, reviewReason: null, reviewed: false, ...patch,
});

const board = (rows: AttendanceRow[]): TodayBoard => ({
  date: "2026-11-09",
  staff: ["a", "b", "c", "d"].map((id) => ({ userId: id, name: id.toUpperCase(), role: "cashier", photoUrl: null })),
  rows,
  leaves: [{ userId: "d", fromDate: "2026-11-09", toDate: "2026-11-09", part: "full", leaveType: "annual" }],
  review: [],
});

describe("today board", () => {
  const lines = buildStaffLines(
    board([
      row("a", { status: "upcoming" }),
      row("b", { status: "working", entryId: "e1", checkInAt: "2026-11-09T01:00:00Z" }),
      row("c", { status: "not_in" }),
    ])
  );

  it("puts people who forgot to come first, then who is working", () => {
    expect(lines.map((line) => line.staff.userId)).toEqual(["c", "b", "a", "d"]);
  });

  it("counts each group once", () => {
    expect(summarize(lines)).toEqual({ working: 1, notIn: 1, upcoming: 1, done: 0, leave: 1 });
  });
});

describe("entry draft", () => {
  it("asks for a reason and a sensible time range", () => {
    expect(draftError({ checkIn: "", checkOut: "", reason: "x" })).toBe("times_required");
    expect(draftError({ checkIn: "2026-11-09T09:00", checkOut: "2026-11-09T08:00", reason: "x" })).toBe("out_before_in");
    expect(draftError({ checkIn: "2026-11-09T09:00", checkOut: "", reason: " " })).toBe("reason_required");
    expect(draftError({ checkIn: "2026-11-09T09:00", checkOut: "2026-11-09T17:00", reason: "forgot" })).toBeNull();
  });

  it("sends Vietnam time as UTC and leaves an open entry open", () => {
    const input = toEditInput("e", null, { checkIn: "2026-11-09T08:00", checkOut: "", reason: " forgot " });
    expect(input).toMatchObject({ checkInAt: "2026-11-09T01:00:00.000Z", checkOutAt: null, reason: "forgot" });
    expect(toLocalInput("2026-11-09T01:00:00.000Z")).toBe("2026-11-09T08:00");
    expect(fromLocalInput("2026-11-09T08:00")).toBe("2026-11-09T01:00:00.000Z");
  });

  it("writes minutes the way the screens do", () => {
    expect([0, 45, 60, 65, 125].map(formatMinutes)).toEqual(["0p", "45p", "1g00p", "1g05p", "2g05p"]);
  });
});
