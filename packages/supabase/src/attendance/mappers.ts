// Rows from the attendance functions -> domain types. Pure: no client, no Vue.
import type { z } from "zod";
import type {
  LeaveBalance,
  LeaveList,
  LeaveRequest,
  LeaveRowRecord,
  MyLeave,
  AttendanceRow,
  AttendanceRowRecord,
  AttendanceRules,
  AttendanceRulesRow,
  ClockStatus,
  MySchedule,
  MyScheduleRow,
  Roster,
  RosterRow,
  ShiftTemplate,
  ShiftTemplateRow,
  TodayBoard,
  TodayBoardRow,
  clockStatusSchema,
  leaveBalanceSchema,
  leaveListSchema,
  myLeaveSchema,
} from "@bongcun/core/attendance";

export const toShiftTemplate = (row: ShiftTemplateRow): ShiftTemplate => ({
  id: row.id,
  branchId: row.branch_id,
  name: row.name,
  startTime: row.start_time,
  endTime: row.end_time,
  breakMinutes: row.break_minutes,
  color: row.color,
  isActive: row.is_active,
  sortOrder: row.sort_order,
  overnight: row.overnight,
});

export const toAttendanceRules = (row: AttendanceRulesRow): AttendanceRules => ({
  lateGraceMinutes: row.late_grace_minutes,
  earlyGraceMinutes: row.early_grace_minutes,
  checkinEarlyMinutes: row.checkin_early_minutes,
  overtimeMinMinutes: row.overtime_min_minutes,
  allowUnscheduled: row.allow_unscheduled,
  reviewAfterHours: row.review_after_hours,
});

export const toRoster = (row: RosterRow): Roster => ({
  staff: row.staff.map((s) => ({ userId: s.user_id, name: s.name, role: s.role, photoUrl: s.photo_url })),
  templates: row.templates.map(toShiftTemplate),
  assignments: row.assignments.map((a) => ({
    id: a.id,
    userId: a.user_id,
    workDate: a.work_date,
    templateId: a.template_id,
    name: a.name,
    color: a.color,
    startAt: a.start_at,
    endAt: a.end_at,
    breakMinutes: a.break_minutes,
    note: a.note,
    hasEntry: a.has_entry,
  })),
  leaves: row.leaves.map((l) => ({
    userId: l.user_id,
    fromDate: l.from_date,
    toDate: l.to_date,
    part: l.part,
    leaveType: l.leave_type,
  })),
});

// ---------------------------------------------------------------- clock
export const toClockStatus = (row: z.infer<typeof clockStatusSchema>): ClockStatus => ({
  now: row.now,
  branches: row.branches,
  openEntry: row.open_entry && {
    id: row.open_entry.id,
    branchId: row.open_entry.branch_id,
    branchName: row.open_entry.branch_name,
    checkInAt: row.open_entry.check_in_at,
    assignmentId: row.open_entry.assignment_id,
    shiftName: row.open_entry.shift_name,
    shiftEndAt: row.open_entry.shift_end_at,
  },
  shifts: row.shifts.map((s) => ({ id: s.id, branchId: s.branch_id, branchName: s.branch_name, name: s.name, startAt: s.start_at, endAt: s.end_at })),
});

export const toAttendanceRow = (row: AttendanceRowRecord): AttendanceRow => ({
  branchId: row.branch_id,
  userId: row.user_id,
  userName: row.user_name ?? "",
  workDate: row.work_date,
  assignmentId: row.assignment_id,
  entryId: row.entry_id,
  shiftName: row.shift_name,
  startAt: row.start_at,
  endAt: row.end_at,
  checkInAt: row.check_in_at,
  checkOutAt: row.check_out_at,
  scheduledMinutes: row.scheduled_minutes,
  workedMinutes: row.worked_minutes,
  lateMinutes: row.late_minutes,
  earlyMinutes: row.early_minutes,
  overtimeMinutes: row.overtime_minutes,
  status: row.status,
  leaveType: row.leave_type,
  reviewReason: row.review_reason,
  reviewed: row.reviewed,
});

type LeaveRow = TodayBoardRow["leaves"][number];
const toLeave = (l: LeaveRow) => ({ userId: l.user_id, fromDate: l.from_date, toDate: l.to_date, part: l.part, leaveType: l.leave_type });

export const toTodayBoard = (row: TodayBoardRow): TodayBoard => ({
  date: row.date,
  staff: row.staff.map((s) => ({ userId: s.user_id, name: s.name, role: s.role, photoUrl: s.photo_url })),
  rows: row.rows.map(toAttendanceRow),
  leaves: row.leaves.map(toLeave),
  review: row.review.map((r) => ({
    entryId: r.entry_id,
    userId: r.user_id,
    userName: r.user_name,
    workDate: r.work_date,
    checkInAt: r.check_in_at,
    checkOutAt: r.check_out_at,
    reason: r.review_reason,
  })),
});

export const toMySchedule = (row: MyScheduleRow): MySchedule => ({
  assignments: row.assignments.map((a) => ({
    id: a.id,
    branchId: a.branch_id,
    branchName: a.branch_name,
    workDate: a.work_date,
    name: a.name,
    startAt: a.start_at,
    endAt: a.end_at,
    breakMinutes: a.break_minutes,
    note: a.note,
    hasEntry: a.has_entry,
  })),
  entries: row.entries.map((e) => ({
    id: e.id,
    branchId: e.branch_id,
    branchName: e.branch_name,
    workDate: e.work_date,
    assignmentId: e.assignment_id,
    checkInAt: e.check_in_at,
    checkOutAt: e.check_out_at,
    reviewReason: e.review_reason,
  })),
  leaves: row.leaves.map(toLeave),
});

// ---------------------------------------------------------------- leave
export const toLeaveRequest = (row: LeaveRowRecord): LeaveRequest => ({
  id: row.id,
  userId: row.user_id,
  userName: row.user_name,
  branchId: row.branch_id,
  branchName: row.branch_name,
  leaveType: row.leave_type,
  fromDate: row.from_date,
  toDate: row.to_date,
  part: row.part,
  days: row.days,
  reason: row.reason,
  status: row.status,
  decidedByName: row.decided_by_name,
  decidedAt: row.decided_at,
  decisionNote: row.decision_note,
  createdBySelf: row.created_by_self ?? true,
  createdAt: row.created_at,
});

export const toLeaveBalance = (row: z.infer<typeof leaveBalanceSchema>): LeaveBalance => ({ ...row });

export const toLeaveList = (row: z.infer<typeof leaveListSchema>): LeaveList => ({ rows: row.rows.map(toLeaveRequest), total: row.total });

export const toMyLeave = (row: z.infer<typeof myLeaveSchema>): MyLeave => ({
  year: row.year,
  requests: row.requests.map(toLeaveRequest),
  balance: toLeaveBalance(row.balance),
});
