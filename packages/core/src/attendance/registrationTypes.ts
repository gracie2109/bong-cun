// What the registration screens work with (camelCase). The database rows live in contract/registration.ts.
import type { AvailabilityItem } from "./contract/availability";
import type { RegistrationWindowReason, ShiftRequestStatus, StaffRequestStatus, SubmitWarning } from "./contract/registration";
import type { WeekStatus } from "./publishTypes";
import type { LeavePart, LeaveType, ShiftColor } from "./types";

export type RegistrationRules = {
  isOpen: boolean;
  weeksAhead: number;
  closeDaysBefore: number;
  maxShiftsPerWeek: number | null;
  staffNote: string | null;
  requirePublish: boolean;
};

export type RegistrationWindow = { open: boolean; closesAt: string; reason: RegistrationWindowReason | null };

export type RegistrationTemplate = {
  id: string;
  name: string;
  startTime: string;
  endTime: string;
  breakMinutes: number;
  color: ShiftColor;
  overnight: boolean;
};

export type MyShiftRequest = {
  id: string;
  workDate: string;
  templateId: string | null;
  name: string;
  status: StaffRequestStatus;
  note: string | null;
  decisionNote: string | null;
  assignmentId: string | null;
  startAt: string;
  endAt: string;
};

/** A request listed across branches, with the branch name and whether its shift already started. */
export type MyShiftRequestListed = MyShiftRequest & { branchId: string; branchName: string; expired: boolean };

export type RegistrationAssignment = {
  id: string;
  branchId: string;
  branchName: string;
  workDate: string;
  templateId: string | null;
  name: string;
  startAt: string;
  endAt: string;
};

export type RegistrationLeave = { fromDate: string; toDate: string; part: LeavePart; leaveType: LeaveType };

export type StaffingNeed = { templateId: string; weekday: number; minStaff: number; assigned: number; pending: number };

export type RegistrationBoard = {
  rules: RegistrationRules;
  window: RegistrationWindow;
  templates: RegistrationTemplate[];
  days: string[];
  requests: MyShiftRequest[];
  assignments: RegistrationAssignment[];
  leaves: RegistrationLeave[];
  availability: AvailabilityItem[];
  needs: StaffingNeed[];
  week: WeekStatus;
  /** The person declared "no shifts this week". */
  submission: { reason: string | null } | null;
};

export type SubmitResult = {
  created: { id: string; workDate: string; templateId: string; warning: SubmitWarning | null }[];
  skipped: { workDate: string | null; templateId: string | null; hint: string }[];
};

// ----------------------------------------------------------- manager review
export type ShiftRequest = {
  id: string;
  branchId: string;
  branchName: string;
  userId: string;
  userName: string;
  workDate: string;
  templateId: string | null;
  name: string;
  color: ShiftColor;
  startAt: string;
  endAt: string;
  breakMinutes: number;
  note: string | null;
  status: ShiftRequestStatus;
  assignmentId: string | null;
  decidedByName: string | null;
  decidedAt: string | null;
  decisionNote: string | null;
  createdAt: string;
  /** Pending and the shift already started: it can only be rejected. */
  expired: boolean;
  onLeave: boolean;
  availability: "unavailable" | "preferred" | null;
  /** Pending and the person already has a shift at that time. */
  overlapsAssignment: boolean;
  /** Approved and the shift is still on the roster. */
  onRoster: boolean;
};

export type ShiftRequestList = { rows: ShiftRequest[]; total: number };

export type DecideRequestsResult = { approved: number; rejected: number; failed: { id: string; hint: string }[] };
