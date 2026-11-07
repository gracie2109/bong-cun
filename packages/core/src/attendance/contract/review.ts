// Reviewing shift requests: the manager's list, deciding many at once, and the badge.
import { z } from "zod";
import { availabilityKindSchema } from "./availability";
import { shiftRequestStatusSchema } from "./registration";
import { shiftColorSchema } from "./shifts";

const uuid = z.string().uuid();
const iso = z.string();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

// ---------------------------------------------------------------- inputs
export const shiftRequestFilter = z.object({
  branchId: uuid.nullable(),
  status: z.enum(["all", "pending", "approved", "rejected", "cancelled"]),
  from: date.nullable(),
  to: date.nullable(),
  search: z.string().optional(),
});
export type ShiftRequestFilter = z.infer<typeof shiftRequestFilter>;

export const decideRequestsInput = z.object({
  ids: z.array(uuid).min(1).max(200),
  approve: z.boolean(),
  note: z.string().max(300).nullable(),
});
export type DecideRequestsInput = z.infer<typeof decideRequestsInput>;

// --------------------------------------------------------------- results
export const shiftRequestRowSchema = z.object({
  id: uuid,
  branch_id: uuid,
  branch_name: z.string(),
  user_id: uuid,
  user_name: z.string(),
  work_date: date,
  template_id: uuid.nullable(),
  name: z.string(),
  color: shiftColorSchema,
  start_at: iso,
  end_at: iso,
  break_minutes: z.number(),
  note: z.string().nullable(),
  status: shiftRequestStatusSchema,
  assignment_id: uuid.nullable(),
  decided_by_name: z.string().nullable(),
  decided_at: iso.nullable(),
  decision_note: z.string().nullable(),
  created_at: iso,
  expired: z.boolean(),
  on_leave: z.boolean(),
  availability: availabilityKindSchema.nullable(),
  overlaps_assignment: z.boolean(),
  on_roster: z.boolean(),
});
export type ShiftRequestRowRecord = z.infer<typeof shiftRequestRowSchema>;

export const shiftRequestListSchema = z.object({ rows: z.array(shiftRequestRowSchema), total: z.number() });
export type ShiftRequestListRow = z.infer<typeof shiftRequestListSchema>;

export const decideRequestsResultSchema = z.object({
  approved: z.number(),
  rejected: z.number(),
  failed: z.array(z.object({ id: uuid, hint: z.string() })),
});
export type DecideRequestsResultRow = z.infer<typeof decideRequestsResultSchema>;
