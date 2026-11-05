// Contract of the shift functions (templates, settings, roster). Inputs are camel case and say what a
// caller sends; result schemas describe the `jsonb` the database answers with, key for key.
import { z } from "zod";
import { SHIFT_COLORS } from "../types";

const uuid = z.string().uuid();
const time = z.string().regex(/^\d{2}:\d{2}$/);
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const shiftColorSchema = z.enum(SHIFT_COLORS);
export const leaveTypeSchema = z.enum(["annual", "sick", "unpaid", "other"]);
export const leavePartSchema = z.enum(["full", "am", "pm"]);

// ---------------------------------------------------------------- inputs
/** `save_shift_template` (creates, or replaces when `id` is passed). */
export const shiftTemplateInput = z.object({
  id: uuid.optional(),
  name: z.string().trim().min(1).max(40),
  startTime: time,
  endTime: time,
  breakMinutes: z.number().int().min(0),
  color: shiftColorSchema,
  sortOrder: z.number().int().optional(),
});
export type ShiftTemplateInput = z.infer<typeof shiftTemplateInput>;

/** `save_attendance_settings`; every field is optional, the rest keeps its value. */
export const attendanceRulesInput = z.object({
  lateGraceMinutes: z.number().int().min(0).max(60).optional(),
  earlyGraceMinutes: z.number().int().min(0).max(60).optional(),
  checkinEarlyMinutes: z.number().int().min(0).max(240).optional(),
  overtimeMinMinutes: z.number().int().min(0).max(240).optional(),
  allowUnscheduled: z.boolean().optional(),
  reviewAfterHours: z.number().int().min(4).max(24).optional(),
});
export type AttendanceRulesInput = z.infer<typeof attendanceRulesInput>;

/** `assign_shift`: a template, or a custom start and end. */
export const assignShiftInput = z.object({
  branchId: uuid,
  userId: uuid,
  workDate: date,
  templateId: uuid.nullish(),
  startTime: time.nullish(),
  endTime: time.nullish(),
  breakMinutes: z.number().int().min(0).nullish(),
  note: z.string().max(300).nullish(),
});
export type AssignShiftInput = z.infer<typeof assignShiftInput>;

/** `update_shift_assignment`; leave out what stays. */
export const updateShiftInput = z.object({
  id: uuid,
  workDate: date.optional(),
  templateId: uuid.nullable().optional(),
  startTime: time.optional(),
  endTime: time.optional(),
  breakMinutes: z.number().int().min(0).optional(),
  note: z.string().max(300).nullable().optional(),
});
export type UpdateShiftInput = z.infer<typeof updateShiftInput>;

export const copyWeekInput = z.object({
  branchId: uuid,
  fromMonday: date,
  toMonday: date,
  overwrite: z.boolean().optional(),
});
export type CopyWeekInput = z.infer<typeof copyWeekInput>;

// --------------------------------------------------------------- results
export const attendanceRulesSchema = z.object({
  late_grace_minutes: z.number(),
  early_grace_minutes: z.number(),
  checkin_early_minutes: z.number(),
  overtime_min_minutes: z.number(),
  allow_unscheduled: z.boolean(),
  review_after_hours: z.number(),
});

export type AttendanceRulesRow = z.infer<typeof attendanceRulesSchema>;

export const shiftTemplateRowSchema = z.object({
  id: uuid,
  branch_id: uuid,
  name: z.string(),
  start_time: time,
  end_time: time,
  break_minutes: z.number(),
  color: shiftColorSchema,
  is_active: z.boolean(),
  sort_order: z.number(),
  overnight: z.boolean(),
});
export type ShiftTemplateRow = z.infer<typeof shiftTemplateRowSchema>;

export const assignShiftResultSchema = z.object({ id: uuid, warning: z.literal("on_leave").optional() });
export const copyWeekResultSchema = z.object({ copied: z.number(), skipped: z.number() });

export const rosterSchema = z.object({
  staff: z.array(z.object({ user_id: uuid, name: z.string(), role: z.string(), photo_url: z.string().nullable() })),
  templates: z.array(shiftTemplateRowSchema),
  assignments: z.array(
    z.object({
      id: uuid,
      user_id: uuid,
      work_date: date,
      template_id: uuid.nullable(),
      name: z.string(),
      color: shiftColorSchema,
      start_at: z.string(),
      end_at: z.string(),
      break_minutes: z.number(),
      note: z.string().nullable(),
      has_entry: z.boolean(),
    })
  ),
  leaves: z.array(
    z.object({
      user_id: uuid,
      from_date: date,
      to_date: date,
      part: leavePartSchema,
      leave_type: leaveTypeSchema,
    })
  ),
});
export type RosterRow = z.infer<typeof rosterSchema>;
