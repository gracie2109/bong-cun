// Contract of the leave functions: requests, balances and what the manager's list returns.
import { z } from "zod";
import { leavePartSchema, leaveTypeSchema } from "./shifts";

const uuid = z.string().uuid();
const iso = z.string();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const leaveStatusSchema = z.enum(["pending", "approved", "rejected", "cancelled"]);

// ---------------------------------------------------------------- inputs
export const requestLeaveInput = z.object({
  branchId: uuid,
  leaveType: leaveTypeSchema,
  fromDate: date,
  toDate: date,
  part: leavePartSchema,
  reason: z.string().trim().min(1).max(500),
});
export type RequestLeaveInput = z.infer<typeof requestLeaveInput>;

/** A manager files for somebody else; the request is approved at once. */
export const requestLeaveForInput = requestLeaveInput.extend({ userId: uuid });
export type RequestLeaveForInput = z.infer<typeof requestLeaveForInput>;

export const decideLeaveInput = z.object({
  id: uuid,
  approve: z.boolean(),
  note: z.string().max(500).optional(),
  /** Approving may change the type, e.g. to unpaid when the allowance is spent. */
  leaveType: leaveTypeSchema.optional(),
});
export type DecideLeaveInput = z.infer<typeof decideLeaveInput>;

export const leaveFilter = z.object({
  branchId: uuid.nullable(),
  status: z.enum(["all", "pending", "approved", "rejected", "cancelled"]),
  from: date.nullable(),
  to: date.nullable(),
  search: z.string().optional(),
});
export type LeaveFilter = z.infer<typeof leaveFilter>;

// --------------------------------------------------------------- results
export const leaveWarningSchema = z.literal("over_allowance");

export const requestLeaveResultSchema = z.object({ id: uuid, days: z.number(), warning: leaveWarningSchema.nullish() });
export const decideLeaveResultSchema = z.object({
  status: z.enum(["approved", "rejected"]),
  days: z.number(),
  warning: leaveWarningSchema.nullish(),
});

export const leaveBalanceSchema = z.object({ allowance: z.number(), used: z.number(), pending: z.number(), remaining: z.number() });
export type LeaveBalanceRow = z.infer<typeof leaveBalanceSchema>;

export const leaveRowSchema = z.object({
  id: uuid,
  user_id: uuid,
  user_name: z.string(),
  branch_id: uuid,
  branch_name: z.string(),
  leave_type: leaveTypeSchema,
  from_date: date,
  to_date: date,
  part: leavePartSchema,
  days: z.number(),
  reason: z.string(),
  status: leaveStatusSchema,
  decided_by_name: z.string().nullable(),
  decided_at: iso.nullable(),
  decision_note: z.string().nullable(),
  created_by_self: z.boolean().nullable(),
  created_at: iso,
});
export type LeaveRowRecord = z.infer<typeof leaveRowSchema>;

export const leaveListSchema = z.object({ rows: z.array(leaveRowSchema), total: z.number() });
export const myLeaveSchema = z.object({ year: z.number(), requests: z.array(leaveRowSchema), balance: leaveBalanceSchema });
