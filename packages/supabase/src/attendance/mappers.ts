// Rows from the attendance functions -> domain types. Pure: no client, no Vue.
import type { z } from "zod";
import type {
  MyTimesheet,
  MyTimesheetRow,
  TimesheetGrid,
  TimesheetGridRow,
  TimesheetList,
  TimesheetListRow,
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
  requests: (row.requests ?? []).map((r) => ({
    id: r.id,
    userId: r.user_id,
    workDate: r.work_date,
    templateId: r.template_id,
    name: r.name,
    color: r.color,
    startAt: r.start_at,
    endAt: r.end_at,
    note: r.note,
    expired: r.expired,
    availability: r.availability,
    onLeave: r.on_leave,
  })),
  availability: (row.availability ?? []).map((a) => ({
    userId: a.user_id,
    weekday: a.weekday,
    kind: a.kind,
    startTime: a.start_time ?? null,
    endTime: a.end_time ?? null,
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

// ------------------------------------------------------------ timesheet
export const toTimesheetList = (row: TimesheetListRow): TimesheetList => ({
  total: row.total,
  rows: row.rows.map((r) => ({
    userId: r.user_id,
    name: r.name,
    branchCodes: r.branch_codes ?? "",
    shiftsScheduled: r.shifts_scheduled,
    shiftsWorked: r.shifts_worked,
    scheduledMinutes: r.scheduled_minutes,
    workedMinutes: r.worked_minutes,
    lateCount: r.late_count,
    lateMinutes: r.late_minutes,
    earlyCount: r.early_count,
    earlyMinutes: r.early_minutes,
    overtimeMinutes: r.overtime_minutes,
    absentCount: r.absent_count,
    unscheduledCount: r.unscheduled_count,
    missingCheckoutCount: r.missing_checkout_count,
    leaveAnnual: r.leave_annual,
    leaveSick: r.leave_sick,
    leaveUnpaid: r.leave_unpaid,
    leaveOther: r.leave_other,
  })),
});

export const toTimesheetGrid = (row: TimesheetGridRow): TimesheetGrid => ({
  days: row.days,
  staff: row.staff.map((s) => ({
    userId: s.user_id,
    name: s.name,
    cells: s.cells.map((c) => ({
      date: c.date,
      code: c.code,
      minutes: c.minutes,
      detail: c.detail.map((d) => ({
        shiftName: d.shift_name,
        status: d.status,
        checkInAt: d.check_in_at,
        checkOutAt: d.check_out_at,
        workedMinutes: d.worked_minutes,
      })),
    })),
    totals: {
      daysWorked: s.totals.days_worked,
      lateCount: s.totals.late_count,
      absentCount: s.totals.absent_count,
      uncheckedCount: s.totals.unchecked_count,
      leaveDays: s.totals.leave_days,
      workedMinutes: s.totals.worked_minutes,
    },
  })),
});

export const toMyTimesheet = (row: MyTimesheetRow): MyTimesheet => ({
  rows: row.rows.map(toAttendanceRow),
  totals: {
    scheduledMinutes: row.totals.scheduled_minutes,
    workedMinutes: row.totals.worked_minutes,
    lateCount: row.totals.late_count,
    lateMinutes: row.totals.late_minutes,
    earlyMinutes: row.totals.early_minutes,
    overtimeMinutes: row.totals.overtime_minutes,
    absentCount: row.totals.absent_count,
  },
});
