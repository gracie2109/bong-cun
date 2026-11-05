// Domain types of staff attendance, in the shape screens use (camel case).
export const SHIFT_COLORS = ["teal", "sky", "amber", "rose", "violet", "slate"] as const;
export type ShiftColor = (typeof SHIFT_COLORS)[number];

export type ShiftTemplate = {
  id: string;
  branchId: string;
  name: string;
  /** `HH:mm`. */
  startTime: string;
  endTime: string;
  breakMinutes: number;
  color: ShiftColor;
  isActive: boolean;
  sortOrder: number;
  /** The shift ends the next morning. */
  overnight: boolean;
};

export type AttendanceRules = {
  lateGraceMinutes: number;
  earlyGraceMinutes: number;
  checkinEarlyMinutes: number;
  overtimeMinMinutes: number;
  allowUnscheduled: boolean;
  reviewAfterHours: number;
};

export type RosterStaff = { userId: string; name: string; role: string; photoUrl: string | null };

export type RosterAssignment = {
  id: string;
  userId: string;
  /** `yyyy-MM-dd`, the day the shift starts (Vietnam time). */
  workDate: string;
  templateId: string | null;
  name: string;
  color: ShiftColor;
  startAt: string;
  endAt: string;
  breakMinutes: number;
  note: string | null;
  hasEntry: boolean;
};

export type LeaveType = "annual" | "sick" | "unpaid" | "other";
export type LeavePart = "full" | "am" | "pm";

/** An approved leave drawn on the roster. */
export type RosterLeave = { userId: string; fromDate: string; toDate: string; part: LeavePart; leaveType: LeaveType };

export type Roster = {
  staff: RosterStaff[];
  templates: ShiftTemplate[];
  assignments: RosterAssignment[];
  leaves: RosterLeave[];
};
