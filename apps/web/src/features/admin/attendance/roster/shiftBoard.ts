import { timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { Roster, RosterAssignment, RosterStaff, ShiftColor } from "@bongcun/core/attendance";

/** One person on a shift of one day. */
export type ShiftBoardEntry = { staff: RosterStaff; assignment: RosterAssignment };

/** One shift as a row of the board: the same name and hours, a cell per day. */
export type ShiftBoardRow = {
  key: string;
  name: string;
  color: ShiftColor;
  templateId: string | null;
  /** `HH:mm`. */
  startTime: string;
  endTime: string;
  cells: Record<string, ShiftBoardEntry[]>;
};

export type ShiftBoard = { rows: ShiftBoardRow[]; dayTotals: Record<string, number> };

/**
 * The shift x day matrix: who works which shift on which day. Rows follow the shift templates' own order
 * (custom hours get a row of their own), people inside a cell are sorted by name.
 */
export const buildShiftBoard = (roster: Roster, days: string[]): ShiftBoard => {
  const people = new Map(roster.staff.map((person) => [person.userId, person]));
  const rows = new Map<string, ShiftBoardRow>();
  const dayTotals: Record<string, number> = Object.fromEntries(days.map((day) => [day, 0]));

  for (const assignment of roster.assignments) {
    const staff = people.get(assignment.userId);
    if (!staff || !(assignment.workDate in dayTotals)) continue;
    const startTime = timeOf(assignment.startAt);
    const endTime = timeOf(assignment.endAt);
    const key = `${assignment.name}|${startTime}|${endTime}`;
    const row = rows.get(key) ?? {
      key,
      name: assignment.name,
      color: assignment.color,
      templateId: assignment.templateId,
      startTime,
      endTime,
      cells: Object.fromEntries(days.map((day) => [day, [] as ShiftBoardEntry[]])),
    };
    row.cells[assignment.workDate]?.push({ staff, assignment });
    dayTotals[assignment.workDate] = (dayTotals[assignment.workDate] ?? 0) + 1;
    rows.set(key, row);
  }

  // A template with nobody this week still gets its row, so the manager can fill it.
  for (const template of roster.templates.filter((item) => item.isActive)) {
    const exists = [...rows.values()].some((row) => row.templateId === template.id);
    if (exists) continue;
    const key = `template:${template.id}`;
    rows.set(key, {
      key,
      name: template.name,
      color: template.color,
      templateId: template.id,
      startTime: template.startTime,
      endTime: template.endTime,
      cells: Object.fromEntries(days.map((day) => [day, [] as ShiftBoardEntry[]])),
    });
  }

  const order = new Map(roster.templates.map((template, index) => [template.id, index]));
  const list = [...rows.values()].sort((a, b) => {
    const left = a.templateId ? (order.get(a.templateId) ?? 999) : 1000;
    const right = b.templateId ? (order.get(b.templateId) ?? 999) : 1000;
    return left - right || a.name.localeCompare(b.name);
  });
  for (const row of list) for (const day of days) row.cells[day]?.sort((a, b) => a.staff.name.localeCompare(b.staff.name));
  return { rows: list, dayTotals };
};
