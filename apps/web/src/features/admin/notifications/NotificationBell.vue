<template>
  <Popover v-model:open="open">
    <PopoverTrigger as-child>
      <button type="button" class="relative cursor-pointer" :aria-label="$t('notifications.title')">
        <BellRing class="size-6" />
        <span
          v-if="unread > 0"
          class="absolute -right-2 -top-2 grid min-w-4 place-items-center rounded-full bg-red-600 px-1 text-[10px] font-semibold leading-4 text-white"
        >
          {{ unread > 9 ? "9+" : unread }}
        </span>
      </button>
    </PopoverTrigger>
    <PopoverContent class="w-96 max-w-[calc(100vw-1.5rem)] p-2">
      <div class="mb-1 flex items-center justify-between gap-2 px-2">
        <h2 class="text-sm font-bold">{{ $t("notifications.title") }}</h2>
        <button
          v-if="unread > 0"
          type="button"
          class="text-xs font-medium text-primary hover:underline"
          :disabled="markRead.isPending.value"
          @click="markRead.mutate(undefined)"
        >
          {{ $t("notifications.markAllRead") }}
        </button>
      </div>
      <p v-if="!rows.length" class="py-6 text-center text-sm text-muted-foreground">{{ $t("notifications.empty") }}</p>
      <ul v-else class="max-h-96 space-y-0.5 overflow-y-auto">
        <li v-for="item in rows" :key="item.id">
          <NotificationItem :item="item" @open="openItem" />
        </li>
      </ul>
      <router-link
        :to="{ name: 'adminNotifications' }"
        class="mt-1 block rounded-lg px-2 py-2 text-center text-xs font-medium text-primary hover:bg-muted/60"
        @click="open = false"
      >
        {{ $t("notifications.seeAll") }}
      </router-link>
    </PopoverContent>
  </Popover>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { BellRing } from "lucide-vue-next";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import NotificationItem from "./NotificationItem.vue";
import { useOpenNotification } from "./useOpenNotification";
import { useMarkNotificationsRead, useNotifications, useUnreadCount } from "./queries";

const open = ref(false);
const unreadQuery = useUnreadCount();
// The latest ten are only fetched once the bell has been opened.
const latest = useNotifications(1, 10, false, open);
const markRead = useMarkNotificationsRead();
const openNotification = useOpenNotification();

const unread = computed(() => unreadQuery.data.value ?? 0);
const rows = computed(() => latest.data.value?.rows ?? []);

const openItem = async (item: Parameters<typeof openNotification>[0]) => {
  open.value = false;
  await openNotification(item);
};
</script>
