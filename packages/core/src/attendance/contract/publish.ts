// Publishing a week: its state, who has not registered, and what publishing did.
import { z } from "zod";

const uuid = z.string().uuid();
const date = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const weekStatusSchema = z.object({
  require_publish: z.boolean(),
  status: z.enum(["draft", "published"]),
  published_at: z.string().nullable(),
  published_by_name: z.string().nullable(),
  auto_published: z.boolean(),
  /** Only for managers. */
  pending_requests: z.number().nullable(),
  missing_count: z.number().nullable(),
});
export type WeekStatusRow = z.infer<typeof weekStatusSchema>;

export const registrationStateSchema = z.enum(["submitted", "declared_none", "missing", "exempt", "manager"]);
export type RegistrationState = z.infer<typeof registrationStateSchema>;

export const registrationStatusRowSchema = z.object({
  user_id: uuid,
  name: z.string(),
  must_register: z.boolean(),
  state: registrationStateSchema,
  request_count: z.number(),
  assigned_count: z.number(),
});

export const registrationStatusSchema = z.object({
  rows: z.array(registrationStatusRowSchema),
  missing_count: z.number(),
  closes_at: z.string().nullable(),
});
export type RegistrationStatusRaw = z.infer<typeof registrationStatusSchema>;

export const publishResultSchema = z.object({ notified: z.number(), rejected: z.number(), shifts: z.number() });
export type PublishResult = z.infer<typeof publishResultSchema>;

export const copyPersonResultSchema = z.object({ copied: z.number(), skipped: z.number() });

export const exemptionListSchema = z.array(z.object({ user_id: uuid, name: z.string(), note: z.string().nullable() }));
export const weeksWithShiftsSchema = z.array(z.object({ week_monday: date, shifts: z.number() }));

export const declareNoShiftsInput = z.object({ branchId: uuid, monday: date, reason: z.string().max(300).nullish() });
export type DeclareNoShiftsInput = z.infer<typeof declareNoShiftsInput>;
