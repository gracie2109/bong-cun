// The hints the attendance RPCs attach to a refusal.
export const ATTENDANCE_ERROR_HINTS = [
  "forbidden",
  "bad_input",
  "not_found",
  "name_taken",
  "not_branch_staff",
  "shift_overlap",
  "has_entry",
  "invalid_range",
  "range_too_long",
] as const;
export type AttendanceErrorHint = (typeof ATTENDANCE_ERROR_HINTS)[number];

export const attendanceErrorHint = (error: unknown): AttendanceErrorHint | null => {
  const hint = (error as { hint?: string } | null)?.hint;
  return ATTENDANCE_ERROR_HINTS.find((item) => item === hint) ?? null;
};
