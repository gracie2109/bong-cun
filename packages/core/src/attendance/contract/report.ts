// Contract of the timesheet functions: the summary, the monthly grid and my own timesheet.
import { z } from "zod";
import { attendanceRowSchema, attendanceStatusSchema } from "./clock";

const uuid = z.string().uuid();
const iso = z.string();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const timesheetFilter = z.object({
  branchId: uuid.nullable(),
  from: date,
  to: date,
  search: z.string().optional(),
});
export type TimesheetFilter = z.infer<typeof timesheetFilter>;

export const timesheetRowSchema = z.object({
  user_id: uuid,
  name: z.string(),
  branch_codes: z.string().nullable(),
  shifts_scheduled: z.number(),
  shifts_worked: z.number(),
  scheduled_minutes: z.number(),
  worked_minutes: z.number(),
  late_count: z.number(),
  late_minutes: z.number(),
  early_count: z.number(),
  early_minutes: z.number(),
  overtime_minutes: z.number(),
  absent_count: z.number(),
  unscheduled_count: z.number(),
  missing_checkout_count: z.number(),
  leave_annual: z.number(),
  leave_sick: z.number(),
  leave_unpaid: z.number(),
  leave_other: z.number(),
});
export type TimesheetRowRecord = z.infer<typeof timesheetRowSchema>;

export const timesheetListSchema = z.object({ rows: z.array(timesheetRowSchema), total: z.number() });
export type TimesheetListRow = z.infer<typeof timesheetListSchema>;

/** One cell of the monthly grid: `P Ô K N` leave, `V` absent, `?` forgot to clock out, `M` late, `S` left early, `X` worked, `X+` unscheduled. */
export const gridCodeSchema = z.enum(["", "P", "Ô", "K", "N", "V", "?", "M", "S", "X", "X+"]);

export const timesheetGridSchema = z.object({
  days: z.array(date),
  staff: z.array(
    z.object({
      user_id: uuid,
      name: z.string(),
      cells: z.array(
        z.object({
          date,
          code: gridCodeSchema,
          minutes: z.number(),
          detail: z.array(
            z.object({
              shift_name: z.string().nullable(),
              status: attendanceStatusSchema,
              check_in_at: iso.nullable(),
              check_out_at: iso.nullable(),
              worked_minutes: z.number(),
            })
          ),
        })
      ),
      totals: z.object({
        days_worked: z.number(),
        late_count: z.number(),
        absent_count: z.number(),
        unchecked_count: z.number(),
        leave_days: z.number(),
        worked_minutes: z.number(),
      }),
    })
  ),
});
export type TimesheetGridRow = z.infer<typeof timesheetGridSchema>;

export const myTimesheetSchema = z.object({
  rows: z.array(attendanceRowSchema),
  totals: z.object({
    scheduled_minutes: z.number(),
    worked_minutes: z.number(),
    late_count: z.number(),
    late_minutes: z.number(),
    early_minutes: z.number(),
    overtime_minutes: z.number(),
    absent_count: z.number(),
  }),
});
export type MyTimesheetRow = z.infer<typeof myTimesheetSchema>;
