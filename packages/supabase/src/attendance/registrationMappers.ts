// Registration rows -> the shapes the screens use. Pure: no client, no Vue.
import type {
  MyShiftRequest,
  MyShiftRequestListed,
  MyShiftRequestRow,
  RegistrationBoard,
  RegistrationBoardRow,
  RegistrationRules,
  RegistrationRulesRow,
  ShiftRequest,
  ShiftRequestList,
  ShiftRequestListRow,
  ShiftRequestRowRecord,
  SubmitResult,
  SubmitResultRow,
} from "@bongcun/core/attendance";
import { toAvailabilityItem } from "./availabilityMappers";
import { toWeekStatus } from "./publishMappers";

type RequestRow = RegistrationBoardRow["requests"][number];

export const toRegistrationRules = (row: RegistrationRulesRow): RegistrationRules => ({
  isOpen: row.is_open,
  weeksAhead: row.weeks_ahead,
  closeDaysBefore: row.close_days_before,
  maxShiftsPerWeek: row.max_shifts_per_week,
  staffNote: row.staff_note,
  requirePublish: row.require_publish,
});

export const toMyShiftRequest = (row: RequestRow): MyShiftRequest => ({
  id: row.id,
  workDate: row.work_date,
  templateId: row.template_id,
  name: row.name,
  status: row.status,
  note: row.note,
  decisionNote: row.decision_note,
  assignmentId: row.assignment_id,
  startAt: row.start_at,
  endAt: row.end_at,
});

export const toMyShiftRequestListed = (row: MyShiftRequestRow): MyShiftRequestListed => ({
  ...toMyShiftRequest(row),
  branchId: row.branch_id,
  branchName: row.branch_name,
  expired: row.expired,
});

export const toRegistrationBoard = (row: RegistrationBoardRow): RegistrationBoard => ({
  rules: toRegistrationRules(row.rules),
  window: { open: row.window.open, closesAt: row.window.closes_at, reason: row.window.reason },
  templates: row.templates.map((t) => ({
    id: t.id,
    name: t.name,
    startTime: t.start_time,
    endTime: t.end_time,
    breakMinutes: t.break_minutes,
    color: t.color,
    overnight: t.overnight,
  })),
  days: row.days,
  requests: row.requests.map(toMyShiftRequest),
  assignments: row.assignments.map((a) => ({
    id: a.id,
    branchId: a.branch_id,
    branchName: a.branch_name,
    workDate: a.work_date,
    templateId: a.template_id,
    name: a.name,
    startAt: a.start_at,
    endAt: a.end_at,
  })),
  leaves: row.leaves.map((l) => ({ fromDate: l.from_date, toDate: l.to_date, part: l.part, leaveType: l.leave_type })),
  availability: row.availability.map(toAvailabilityItem),
  needs: row.needs.map((n) => ({ templateId: n.template_id, weekday: n.weekday, minStaff: n.min_staff, assigned: n.assigned, pending: n.pending })),
  week: toWeekStatus(row.week),
  submission: row.submission ? { reason: row.submission.reason } : null,
});

export const toSubmitResult = (row: SubmitResultRow): SubmitResult => ({
  created: row.created.map((c) => ({ id: c.id, workDate: c.work_date, templateId: c.template_id, warning: c.warning ?? null })),
  skipped: row.skipped.map((s) => ({ workDate: s.work_date ?? null, templateId: s.template_id ?? null, hint: s.hint })),
});

// ----------------------------------------------------------- manager review
export const toShiftRequest = (row: ShiftRequestRowRecord): ShiftRequest => ({
  id: row.id,
  branchId: row.branch_id,
  branchName: row.branch_name,
  userId: row.user_id,
  userName: row.user_name,
  workDate: row.work_date,
  templateId: row.template_id,
  name: row.name,
  color: row.color,
  startAt: row.start_at,
  endAt: row.end_at,
  breakMinutes: row.break_minutes,
  note: row.note,
  status: row.status,
  assignmentId: row.assignment_id,
  decidedByName: row.decided_by_name,
  decidedAt: row.decided_at,
  decisionNote: row.decision_note,
  createdAt: row.created_at,
  expired: row.expired,
  onLeave: row.on_leave,
  availability: row.availability,
  overlapsAssignment: row.overlaps_assignment,
  onRoster: row.on_roster,
});

export const toShiftRequestList = (row: ShiftRequestListRow): ShiftRequestList => ({ rows: row.rows.map(toShiftRequest), total: row.total });
