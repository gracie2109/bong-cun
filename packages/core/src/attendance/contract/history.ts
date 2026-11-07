// The shapes schedule_history_list and schedule_history_of return.
import { z } from "zod";
import { HISTORY_ACTIONS, HISTORY_ENTITIES } from "../historyTypes";

const jsonValue = z.union([z.record(z.unknown()), z.array(z.unknown())]);

export const historyRowSchema = z.object({
  id: z.number(),
  branch_id: z.string().uuid().nullable(),
  week_monday: z.string().nullable(),
  entity: z.enum(HISTORY_ENTITIES),
  entity_id: z.string().nullable(),
  action: z.enum(HISTORY_ACTIONS),
  actor_id: z.string().uuid().nullable(),
  actor_name: z.string(),
  target_user_id: z.string().uuid().nullable(),
  target_user_name: z.string().nullable(),
  before: jsonValue.nullable(),
  after: jsonValue.nullable(),
  changed_fields: z.array(z.string()),
  reason: z.string().nullable(),
  source: z.string().nullable(),
  was_published: z.boolean(),
  created_at: z.string(),
});

export const historyListSchema = z.object({ rows: z.array(historyRowSchema), total: z.number() });
export const historyOfSchema = z.array(historyRowSchema);
export type HistoryRowRaw = z.infer<typeof historyRowSchema>;
export type HistoryListRaw = z.infer<typeof historyListSchema>;
