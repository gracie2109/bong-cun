import { isoWeekday } from "@bongcun/core/attendance";
import type { Roster, RosterAssignment, RosterAvailability, RosterLeave, RosterRequest, RosterStaff } from "@bongcun/core/attendance";

/** One day of one person on the roster. */
export type RosterCellData = {
  date: string;
  assignments: RosterAssignment[];
  leave: RosterLeave | null;
  /** Pending shift requests of the person on this day, drawn dashed. */
  requests: RosterRequest[];
  /** What the person said about this weekday (blocked or preferred hours). */
  availability: RosterAvailability[];
  /** The whole day is blocked: the cell is striped. */
  blocked: boolean;
};

export type RosterRowData = { staff: RosterStaff; cells: RosterCellData[]; shiftCount: number };

/** The person x day matrix the grid draws: shifts of that day in time order, and the approved leave covering it. */
export const buildRosterGrid = (roster: Roster, days: string[]): RosterRowData[] =>
  roster.staff.map((staff) => {
    const mine = roster.assignments.filter((item) => item.userId === staff.userId);
    const leaves = roster.leaves.filter((item) => item.userId === staff.userId);
    const requests = roster.requests.filter((item) => item.userId === staff.userId);
    const rules = roster.availability.filter((item) => item.userId === staff.userId);
    const cells = days.map((date) => {
      const availability = rules.filter((item) => item.weekday === isoWeekday(date));
      return {
        date,
        assignments: mine.filter((item) => item.workDate === date).sort((a, b) => a.startAt.localeCompare(b.startAt)),
        leave: leaves.find((item) => item.fromDate <= date && date <= item.toDate) ?? null,
        requests: requests.filter((item) => item.workDate === date).sort((a, b) => a.startAt.localeCompare(b.startAt)),
        availability,
        blocked: availability.some((item) => item.kind === "unavailable" && !item.startTime && !item.endTime),
      };
    });
    return { staff, cells, shiftCount: cells.reduce((sum, cell) => sum + cell.assignments.length, 0) };
  });
