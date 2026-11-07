import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getUnreadNotificationCount, listMyNotifications, markNotificationsRead } from "@bongcun/supabase/notifications";
import { notificationKeys } from "@/queries/keys";

const UNREAD_REFRESH_MS = 60_000;

/** The badge number. Asked again every minute and when the tab gets focus back (no realtime yet). */
export const useUnreadCount = (enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: notificationKeys.unread(),
    queryFn: () => getUnreadNotificationCount(supabaseClient()),
    enabled: computed(() => unref(enabled)),
    refetchInterval: UNREAD_REFRESH_MS,
    refetchOnWindowFocus: true,
  });

export const useNotifications = (page: MaybeRef<number>, pageSize: number, unreadOnly: MaybeRef<boolean> = false, enabled: MaybeRef<boolean> = true) =>
  useQuery({
    queryKey: computed(() => notificationKeys.list(unref(page), pageSize, unref(unreadOnly))),
    queryFn: () => listMyNotifications(supabaseClient(), unref(page), pageSize, unref(unreadOnly)),
    enabled: computed(() => unref(enabled)),
    placeholderData: keepPreviousData,
    refetchOnWindowFocus: true,
  });

/** Marks the given notifications (or all of mine) read, then refreshes the badge and the lists. */
export const useMarkNotificationsRead = () => {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (ids?: string[]) => markNotificationsRead(supabaseClient(), ids),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: notificationKeys.all }),
  });
};
