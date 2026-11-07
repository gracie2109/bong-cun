import { useRouter } from "vue-router";
import { notificationRoute } from "@bongcun/core/notifications";
import type { AppNotification } from "@bongcun/core/notifications";
import { useMarkNotificationsRead } from "./queries";

/** Opens what a notification points at and marks it read. */
export const useOpenNotification = () => {
  const router = useRouter();
  const markRead = useMarkNotificationsRead();

  return async (item: AppNotification): Promise<void> => {
    if (!item.readAt) markRead.mutate([item.id]);
    const target = notificationRoute(item.link);
    if (target && router.hasRoute(target.name)) await router.push(target);
  };
};
