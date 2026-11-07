import type { HistoryList, HistoryListRaw, HistoryRow, HistoryRowRaw } from "@bongcun/core/attendance";

export const toHistoryRow = (raw: HistoryRowRaw): HistoryRow => ({
  id: raw.id,
  branchId: raw.branch_id,
  weekMonday: raw.week_monday,
  entity: raw.entity,
  entityId: raw.entity_id,
  action: raw.action,
  actorId: raw.actor_id,
  actorName: raw.actor_name,
  targetUserId: raw.target_user_id,
  targetUserName: raw.target_user_name,
  before: raw.before,
  after: raw.after,
  changedFields: raw.changed_fields,
  reason: raw.reason,
  source: raw.source,
  wasPublished: raw.was_published,
  createdAt: raw.created_at,
});

export const toHistoryList = (raw: HistoryListRaw): HistoryList => ({ total: raw.total, rows: raw.rows.map(toHistoryRow) });
