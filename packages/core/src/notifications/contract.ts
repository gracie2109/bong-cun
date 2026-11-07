// The shape my_notifications returns (supabase/migrations/20261113010000_notifications.sql).
import { z } from "zod";
import { NOTIFICATION_KINDS } from "./types";

export const notificationLinkSchema = z.object({
  name: z.string(),
  query: z.record(z.string()).optional(),
});

export const notificationRowSchema = z.object({
  id: z.string().uuid(),
  branch_id: z.string().uuid().nullable(),
  kind: z.enum(NOTIFICATION_KINDS),
  title: z.string(),
  body: z.string().nullable(),
  link: notificationLinkSchema.nullable(),
  data: z.record(z.unknown()),
  read_at: z.string().nullable(),
  created_at: z.string(),
});

export const notificationPageSchema = z.object({
  rows: z.array(notificationRowSchema),
  total: z.number(),
  unread: z.number(),
});
export type NotificationPageRaw = z.infer<typeof notificationPageSchema>;
