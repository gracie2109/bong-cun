import type { Roster, RosterAssignment, RosterLeave, RosterStaff } from "@bongcun/core/attendance";

/** One day of one person on the roster. */
export type RosterCellData = { date: string; assignments: RosterAssignment[]; leave: RosterLeave | null };

export type RosterRowData = { staff: RosterStaff; cells: RosterCellData[]; shiftCount: number };

/** The person x day matrix the grid draws: shifts of that day in time order, and the approved leave covering it. */
export const buildRosterGrid = (roster: Roster, days: string[]): RosterRowData[] =>
  roster.staff.map((staff) => {
    const mine = roster.assignments.filter((item) => item.userId === staff.userId);
    const leaves = roster.leaves.filter((item) => item.userId === staff.userId);
    const cells = days.map((date) => ({
      date,
      assignments: mine.filter((item) => item.workDate === date).sort((a, b) => a.startAt.localeCompare(b.startAt)),
      leave: leaves.find((item) => item.fromDate <= date && date <= item.toDate) ?? null,
    }));
    return { staff, cells, shiftCount: cells.reduce((sum, cell) => sum + cell.assignments.length, 0) };
  });
