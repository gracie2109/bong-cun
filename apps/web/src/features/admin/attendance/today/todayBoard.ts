import type { AttendanceRow, RosterLeave, RosterStaff, TodayBoard } from "@bongcun/core/attendance";

export type StaffLine = { staff: RosterStaff; rows: AttendanceRow[]; leave: RosterLeave | null };

export type BoardSummary = { working: number; notIn: number; upcoming: number; done: number; leave: number };

const isWorking = (row: AttendanceRow) => row.entryId !== null && row.checkOutAt === null;
const needsAttention = (row: AttendanceRow) => row.status === "not_in" || row.status === "absent" || row.status === "missing_checkout";

/** How urgent a line is: forgotten clock-ins and clock-outs first, then who is working, then the rest. */
const rank = (line: StaffLine): number => {
  if (line.rows.some(needsAttention)) return 0;
  if (line.rows.some(isWorking)) return 1;
  if (line.rows.some((row) => row.status === "upcoming")) return 2;
  if (line.rows.length > 0) return 3;
  return line.leave ? 4 : 5;
};

/** One line per staff member of the branch, with their rows of the day and any leave, most urgent first. */
export const buildStaffLines = (board: TodayBoard): StaffLine[] => {
  const lines = board.staff.map<StaffLine>((staff) => ({
    staff,
    rows: board.rows.filter((row) => row.userId === staff.userId),
    leave: board.leaves.find((leave) => leave.userId === staff.userId) ?? null,
  }));
  return lines.sort((a, b) => rank(a) - rank(b) || a.staff.name.localeCompare(b.staff.name));
};

export const summarize = (lines: StaffLine[]): BoardSummary => ({
  working: lines.filter((line) => line.rows.some(isWorking)).length,
  notIn: lines.filter((line) => line.rows.some((row) => row.status === "not_in" || row.status === "absent")).length,
  upcoming: lines.filter((line) => line.rows.some((row) => row.status === "upcoming")).length,
  done: lines.filter((line) => line.rows.length > 0 && !line.rows.some(isWorking) && line.rows.every((row) => row.entryId !== null)).length,
  leave: lines.filter((line) => line.leave !== null || line.rows.some((row) => row.status === "leave")).length,
});
