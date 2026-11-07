// Shift registration: the window a branch opens, the page's board, and the requests a person sends.
import { z } from "zod";
import { availabilityRowSchema } from "./availability";
import { leavePartSchema, leaveTypeSchema, shiftColorSchema } from "./shifts";

const uuid = z.string().uuid();
const iso = z.string();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);
const time = z.string().regex(/^\d{2}:\d{2}$/);

export const shiftRequestStatusSchema = z.enum(["pending", "approved", "rejected", "cancelled"]);
export type ShiftRequestStatus = z.infer<typeof shiftRequestStatusSchema>;

// ---------------------------------------------------------------- inputs
export const registrationSettingsInput = z.object({
  isOpen: z.boolean(),
  weeksAhead: z.number().int().min(1).max(6),
  closeDaysBefore: z.number().int().min(0).max(14),
  maxShiftsPerWeek: z.number().int().min(1).max(21).nullable(),
  staffNote: z.string().max(300).nullable(),
});
export type RegistrationSettingsInput = z.infer<typeof registrationSettingsInput>;

export const submitRequestsInput = z.object({
  branchId: uuid,
  monday: date,
  /** One entry per cell of the grid: a day and a shift template. */
  cells: z.array(z.object({ workDate: date, templateId: uuid })).min(1).max(21),
  note: z.string().max(300).nullable(),
});
export type SubmitRequestsInput = z.infer<typeof submitRequestsInput>;

// --------------------------------------------------------------- results
export const registrationRulesSchema = z.object({
  is_open: z.boolean(),
  weeks_ahead: z.number(),
  close_days_before: z.number(),
  max_shifts_per_week: z.number().nullable(),
  staff_note: z.string().nullable(),
});
export type RegistrationRulesRow = z.infer<typeof registrationRulesSchema>;

export const registrationWindowReasonSchema = z.enum(["closed", "past_deadline", "too_far"]);
export type RegistrationWindowReason = z.infer<typeof registrationWindowReasonSchema>;

export const registrationWindowSchema = z.object({
  open: z.boolean(),
  closes_at: iso,
  reason: registrationWindowReasonSchema.nullable(),
});
export type RegistrationWindowRow = z.infer<typeof registrationWindowSchema>;

export const boardTemplateSchema = z.object({
  id: uuid,
  name: z.string(),
  start_time: time,
  end_time: time,
  break_minutes: z.number(),
  color: shiftColorSchema,
  overnight: z.boolean(),
});

export const boardRequestSchema = z.object({
  id: uuid,
  work_date: date,
  template_id: uuid.nullable(),
  name: z.string(),
  status: shiftRequestStatusSchema,
  note: z.string().nullable(),
  decision_note: z.string().nullable(),
  assignment_id: uuid.nullable(),
  start_at: iso,
  end_at: iso,
});

export const boardAssignmentSchema = z.object({
  id: uuid,
  branch_id: uuid,
  branch_name: z.string(),
  work_date: date,
  template_id: uuid.nullable(),
  name: z.string(),
  start_at: iso,
  end_at: iso,
});

export const boardLeaveSchema = z.object({ from_date: date, to_date: date, part: leavePartSchema, leave_type: leaveTypeSchema });

/** How many people a shift needs on a weekday, and how many are lined up (step 7 of the plan, optional). */
export const boardNeedSchema = z.object({
  template_id: uuid,
  weekday: z.number(),
  min_staff: z.number(),
  assigned: z.number(),
  pending: z.number(),
});

export const registrationBoardSchema = z.object({
  rules: registrationRulesSchema,
  window: registrationWindowSchema,
  templates: z.array(boardTemplateSchema),
  days: z.array(date),
  requests: z.array(boardRequestSchema),
  assignments: z.array(boardAssignmentSchema),
  leaves: z.array(boardLeaveSchema),
  availability: z.array(availabilityRowSchema),
  needs: z.array(boardNeedSchema),
});
export type RegistrationBoardRow = z.infer<typeof registrationBoardSchema>;

export const submitWarningSchema = z.enum(["on_leave", "unavailable"]);
export type SubmitWarning = z.infer<typeof submitWarningSchema>;

export const submitResultSchema = z.object({
  created: z.array(z.object({ id: uuid, work_date: date, template_id: uuid, warning: submitWarningSchema.nullish() })),
  skipped: z.array(z.object({ work_date: z.string().nullish(), template_id: z.string().nullish(), hint: z.string() })),
});
export type SubmitResultRow = z.infer<typeof submitResultSchema>;

export const myShiftRequestSchema = boardRequestSchema.extend({
  branch_id: uuid,
  branch_name: z.string(),
  expired: z.boolean(),
});
export const myShiftRequestsSchema = z.array(myShiftRequestSchema);
export type MyShiftRequestRow = z.infer<typeof myShiftRequestSchema>;
