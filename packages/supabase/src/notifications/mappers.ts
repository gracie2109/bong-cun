import type { AppNotification, NotificationPage, NotificationPageRaw } from "@bongcun/core/notifications";

export const toNotificationPage = (raw: NotificationPageRaw): NotificationPage => ({
  total: raw.total,
  unread: raw.unread,
  rows: raw.rows.map(
    (row): AppNotification => ({
      id: row.id,
      branchId: row.branch_id,
      kind: row.kind,
      title: row.title,
      body: row.body,
      link: row.link ? { name: row.link.name, query: row.link.query ?? {} } : null,
      data: row.data,
      readAt: row.read_at,
      createdAt: row.created_at,
    })
  ),
});
