// In-app notifications. The kinds match the check constraint on public.notifications.
export const NOTIFICATION_KINDS = [
  "schedule_published",
  "schedule_changed",
  "registration_reminder",
  "registration_missing",
  "publish_reminder",
] as const;
export type NotificationKind = (typeof NOTIFICATION_KINDS)[number];

export type NotificationLink = {
  name: string;
  query: Record<string, string>;
};

export type AppNotification = {
  id: string;
  branchId: string | null;
  kind: NotificationKind;
  title: string;
  body: string | null;
  link: NotificationLink | null;
  data: Record<string, unknown>;
  readAt: string | null;
  createdAt: string;
};

export type NotificationPage = {
  rows: AppNotification[];
  total: number;
  unread: number;
};
