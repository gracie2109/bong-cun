// The schedule history log (supabase/migrations/20261113020000_schedule_history.sql).
export const HISTORY_ENTITIES = ["assignment", "request", "week", "submission", "settings", "exemption", "availability"] as const;
export type HistoryEntity = (typeof HISTORY_ENTITIES)[number];

export const HISTORY_ACTIONS = [
  "insert",
  "update",
  "delete",
  "submit",
  "cancel",
  "approve",
  "reject",
  "publish",
  "auto_publish",
  "declare_none",
  "replace",
] as const;
export type HistoryAction = (typeof HISTORY_ACTIONS)[number];

export type HistoryRow = {
  id: number;
  branchId: string | null;
  weekMonday: string | null;
  entity: HistoryEntity;
  entityId: string | null;
  action: HistoryAction;
  actorId: string | null;
  actorName: string;
  targetUserId: string | null;
  targetUserName: string | null;
  before: Record<string, unknown> | unknown[] | null;
  after: Record<string, unknown> | unknown[] | null;
  changedFields: string[];
  reason: string | null;
  source: string | null;
  wasPublished: boolean;
  createdAt: string;
};

export type HistoryList = { rows: HistoryRow[]; total: number };

export type HistoryFilter = {
  branchId: string | null;
  from: string | null;
  to: string | null;
  userId: string | null;
  entity: HistoryEntity | null;
  publishedOnly: boolean;
};
