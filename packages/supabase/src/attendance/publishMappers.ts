import type { Exemption, RegistrationStatus, WeekStatus, WeekStatusRow, WeekWithShifts } from "@bongcun/core/attendance";
import type { RegistrationStatusRaw } from "@bongcun/core/attendance";

export const toWeekStatus = (row: WeekStatusRow): WeekStatus => ({
  requirePublish: row.require_publish,
  status: row.status,
  publishedAt: row.published_at,
  publishedByName: row.published_by_name,
  autoPublished: row.auto_published,
  pendingRequests: row.pending_requests,
  missingCount: row.missing_count,
});

export const toRegistrationStatus = (raw: RegistrationStatusRaw): RegistrationStatus => ({
  missingCount: raw.missing_count,
  closesAt: raw.closes_at,
  rows: raw.rows.map((row) => ({
    userId: row.user_id,
    name: row.name,
    mustRegister: row.must_register,
    state: row.state,
    requestCount: row.request_count,
    assignedCount: row.assigned_count,
  })),
});

export const toExemptions = (rows: { user_id: string; name: string; note: string | null }[]): Exemption[] =>
  rows.map((row) => ({ userId: row.user_id, name: row.name, note: row.note }));

export const toWeeksWithShifts = (rows: { week_monday: string; shifts: number }[]): WeekWithShifts[] =>
  rows.map((row) => ({ weekMonday: row.week_monday, shifts: row.shifts }));
