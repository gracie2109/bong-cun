// Contract of the clock functions and the day views built on attendance rows.
import { z } from "zod";
import { leavePartSchema, leaveTypeSchema } from "./shifts";

const uuid = z.string().uuid();
const iso = z.string();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const attendanceStatusSchema = z.enum([
  "leave",
  "missing_checkout",
  "working",
  "unscheduled",
  "late_early",
  "late",
  "early",
  "present",
  "absent",
  "not_in",
  "upcoming",
]);
export const reviewReasonSchema = z.enum(["missing_checkout", "unscheduled"]);

// ---------------------------------------------------------------- inputs
export const clockInInput = z.object({ branchId: uuid, note: z.string().max(300).optional(), unscheduledOk: z.boolean().optional() });
export type ClockInInput = z.infer<typeof clockInInput>;

/** `add_time_entry`: a manager records hours for somebody; the reason is mandatory. */
export const addEntryInput = z.object({
  branchId: uuid,
  userId: uuid,
  checkInAt: iso,
  checkOutAt: iso.nullable(),
  assignmentId: uuid.nullable(),
  reason: z.string().trim().min(1),
});
export type AddEntryInput = z.infer<typeof addEntryInput>;

export const editEntryInput = z.object({
  id: uuid,
  checkInAt: iso,
  checkOutAt: iso.nullable(),
  assignmentId: uuid.nullable(),
  reason: z.string().trim().min(1),
});
export type EditEntryInput = z.infer<typeof editEntryInput>;

// --------------------------------------------------------------- results
export const clockStatusSchema = z.object({
  now: iso,
  branches: z.array(z.object({ id: uuid, code: z.string(), name: z.string() })),
  open_entry: z
    .object({
      id: uuid,
      branch_id: uuid,
      branch_name: z.string(),
      check_in_at: iso,
      assignment_id: uuid.nullable(),
      shift_name: z.string().nullable(),
      shift_end_at: iso.nullable(),
    })
    .nullable(),
  shifts: z.array(z.object({ id: uuid, branch_id: uuid, branch_name: z.string(), name: z.string(), start_at: iso, end_at: iso })),
});

export const clockInResultSchema = z.object({
  entry_id: uuid,
  assignment_id: uuid.optional(),
  shift_name: z.string().optional(),
  late_minutes: z.number(),
  warning: z.literal("on_leave").optional(),
});

export const clockOutResultSchema = z.object({
  entry_id: uuid,
  worked_minutes: z.number(),
  early_minutes: z.number(),
  overtime_minutes: z.number(),
});

/** One row of `attendance_rows` (a scheduled shift, or an entry without a shift). */
export const attendanceRowSchema = z.object({
  branch_id: uuid,
  user_id: uuid,
  user_name: z.string().nullable(),
  work_date: date,
  assignment_id: uuid.nullable(),
  entry_id: uuid.nullable(),
  shift_name: z.string().nullable(),
  start_at: iso.nullable(),
  end_at: iso.nullable(),
  check_in_at: iso.nullable(),
  check_out_at: iso.nullable(),
  scheduled_minutes: z.number(),
  worked_minutes: z.number(),
  late_minutes: z.number(),
  early_minutes: z.number(),
  overtime_minutes: z.number(),
  status: attendanceStatusSchema,
  leave_type: leaveTypeSchema.nullable(),
  review_reason: reviewReasonSchema.nullable(),
  reviewed: z.boolean(),
});
export type AttendanceRowRecord = z.infer<typeof attendanceRowSchema>;

const leaveSchema = z.object({
  user_id: uuid,
  from_date: date,
  to_date: date,
  part: leavePartSchema,
  leave_type: leaveTypeSchema,
});

export const todayBoardSchema = z.object({
  date,
  staff: z.array(z.object({ user_id: uuid, name: z.string(), role: z.string(), photo_url: z.string().nullable() })),
  rows: z.array(attendanceRowSchema),
  leaves: z.array(leaveSchema),
  review: z.array(
    z.object({
      entry_id: uuid,
      user_id: uuid,
      user_name: z.string(),
      work_date: date,
      check_in_at: iso,
      check_out_at: iso.nullable(),
      review_reason: reviewReasonSchema,
    })
  ),
});
export type TodayBoardRow = z.infer<typeof todayBoardSchema>;

export const entryChangeSchema = z.object({
  id: uuid,
  action: z.enum(["create", "update", "delete", "auto_close"]),
  before: z.record(z.unknown()).nullable(),
  after: z.record(z.unknown()).nullable(),
  reason: z.string().nullable(),
  changed_by_name: z.string().nullable(),
  changed_at: iso,
});

export const mySchedulePartSchema = z.object({
  assignments: z.array(
    z.object({
      id: uuid,
      branch_id: uuid,
      branch_name: z.string(),
      work_date: date,
      name: z.string(),
      start_at: iso,
      end_at: iso,
      break_minutes: z.number(),
      note: z.string().nullable(),
      has_entry: z.boolean(),
    })
  ),
  entries: z.array(
    z.object({
      id: uuid,
      branch_id: uuid,
      branch_name: z.string(),
      work_date: date,
      assignment_id: uuid.nullable(),
      check_in_at: iso,
      check_out_at: iso.nullable(),
      review_reason: reviewReasonSchema.nullable(),
    })
  ),
  leaves: z.array(leaveSchema),
});
export type MyScheduleRow = z.infer<typeof mySchedulePartSchema>;
