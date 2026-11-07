import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@bongcun/supabase/db";
import { notificationPageSchema } from "@bongcun/core/notifications";
import type { NotificationPage } from "@bongcun/core/notifications";
import { parseRpc, unwrap } from "@bongcun/supabase/shared";
import { toNotificationPage } from "./mappers";

type Client = SupabaseClient<Database>;

export const listMyNotifications = async (client: Client, page: number, pageSize: number, unreadOnly: boolean): Promise<NotificationPage> =>
  toNotificationPage(
    parseRpc(
      "my_notifications",
      notificationPageSchema,
      unwrap(await client.rpc("my_notifications", { p_page: page, p_page_size: pageSize, p_unread_only: unreadOnly }))
    )
  );

export const getUnreadNotificationCount = async (client: Client): Promise<number> =>
  Number(unwrap(await client.rpc("unread_notification_count")) ?? 0);

// No ids marks every notification of mine as read.
export const markNotificationsRead = async (client: Client, ids?: string[]): Promise<number> =>
  Number(unwrap(await client.rpc("mark_notifications_read", { p_ids: ids })) ?? 0);
