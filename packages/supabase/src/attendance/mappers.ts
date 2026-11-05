// Rows from the attendance functions -> domain types. Pure: no client, no Vue.
import type { AttendanceRules, AttendanceRulesRow, Roster, RosterRow, ShiftTemplate, ShiftTemplateRow } from "@bongcun/core/attendance";

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
