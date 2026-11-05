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

// ---------------------------------------------------------------- clock
export type ClockBranch = { id: string; code: string; name: string };

export type OpenEntry = {
  id: string;
  branchId: string;
  branchName: string;
  checkInAt: string;
  assignmentId: string | null;
  shiftName: string | null;
  shiftEndAt: string | null;
};

export type ClockShift = { id: string; branchId: string; branchName: string; name: string; startAt: string; endAt: string };

export type ClockStatus = { now: string; branches: ClockBranch[]; openEntry: OpenEntry | null; shifts: ClockShift[] };

export type ClockInResult = { entryId: string; assignmentId: string | null; shiftName: string | null; lateMinutes: number; onLeave: boolean };
export type ClockOutResult = { entryId: string; workedMinutes: number; earlyMinutes: number; overtimeMinutes: number };

// ------------------------------------------------------- attendance rows
export type AttendanceStatus =
  | "leave"
  | "missing_checkout"
  | "working"
  | "unscheduled"
  | "late_early"
  | "late"
  | "early"
  | "present"
  | "absent"
  | "not_in"
  | "upcoming";

export type ReviewReason = "missing_checkout" | "unscheduled";

export type AttendanceRow = {
  branchId: string;
  userId: string;
  userName: string;
  workDate: string;
  assignmentId: string | null;
  entryId: string | null;
  shiftName: string | null;
  startAt: string | null;
  endAt: string | null;
  checkInAt: string | null;
  checkOutAt: string | null;
  scheduledMinutes: number;
  workedMinutes: number;
  lateMinutes: number;
  earlyMinutes: number;
  overtimeMinutes: number;
  status: AttendanceStatus;
  leaveType: LeaveType | null;
  reviewReason: ReviewReason | null;
  reviewed: boolean;
};

export type ReviewItem = {
  entryId: string;
  userId: string;
  userName: string;
  workDate: string;
  checkInAt: string;
  checkOutAt: string | null;
  reason: ReviewReason;
};

export type TodayBoard = { date: string; staff: RosterStaff[]; rows: AttendanceRow[]; leaves: RosterLeave[]; review: ReviewItem[] };

export type EntryChange = {
  id: string;
  action: "create" | "update" | "delete" | "auto_close";
  before: Record<string, unknown> | null;
  after: Record<string, unknown> | null;
  reason: string | null;
  changedByName: string | null;
  changedAt: string;
};

export type MyShift = {
  id: string;
  branchId: string;
  branchName: string;
  workDate: string;
  name: string;
  startAt: string;
  endAt: string;
  breakMinutes: number;
  note: string | null;
  hasEntry: boolean;
};

export type MyEntry = {
  id: string;
  branchId: string;
  branchName: string;
  workDate: string;
  assignmentId: string | null;
  checkInAt: string;
  checkOutAt: string | null;
  reviewReason: ReviewReason | null;
};

export type MySchedule = { assignments: MyShift[]; entries: MyEntry[]; leaves: RosterLeave[] };

// ---------------------------------------------------------------- leave
export type LeaveStatus = "pending" | "approved" | "rejected" | "cancelled";

export type LeaveRequest = {
  id: string;
  userId: string;
  userName: string;
  branchId: string;
  branchName: string;
  leaveType: LeaveType;
  fromDate: string;
  toDate: string;
  part: LeavePart;
  days: number;
  reason: string;
  status: LeaveStatus;
  decidedByName: string | null;
  decidedAt: string | null;
  decisionNote: string | null;
  /** False when a manager filed it for the person. */
  createdBySelf: boolean;
  createdAt: string;
};

export type LeaveBalance = { allowance: number; used: number; pending: number; remaining: number };
export type LeaveList = { rows: LeaveRequest[]; total: number };
export type MyLeave = { year: number; requests: LeaveRequest[]; balance: LeaveBalance };
export type LeaveResult = { id?: string; days: number; warning: "over_allowance" | null };
