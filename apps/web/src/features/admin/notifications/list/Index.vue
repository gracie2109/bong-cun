<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <BellRing class="size-4 text-primary" />
      {{ $t("notifications.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-4">
      <div class="flex flex-wrap items-center gap-2">
        <ChoiceButton :active="!unreadOnly" @click="setUnreadOnly(false)">{{ $t("notifications.all") }}</ChoiceButton>
        <ChoiceButton :active="unreadOnly" @click="setUnreadOnly(true)">
          {{ $t("notifications.unread", { n: unread }) }}
        </ChoiceButton>
        <Button v-if="unread > 0" type="button" variant="outline" size="sm" class="ml-auto" @click="markRead.mutate(undefined)">
          {{ $t("notifications.markAllRead") }}
        </Button>
      </div>

      <ul class="min-h-0 flex-1 space-y-1 overflow-y-auto rounded-lg border bg-white p-2">
        <li v-for="item in rows" :key="item.id">
          <NotificationItem :item="item" @open="openNotification" />
        </li>
        <li v-if="!rows.length && !query.isPending.value" class="px-3 py-6 text-center text-sm text-muted-foreground">
          {{ $t("notifications.empty") }}
        </li>
      </ul>

      <div v-if="pageCount > 1" class="flex justify-end">
        <TablePager v-model:page="page" :page-count="pageCount" :loading="query.isFetching.value" />
      </div>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { BellRing } from "lucide-vue-next";
import TablePager from "@/components/common/TablePager.vue";
import { Button } from "@/components/ui/button";
import { ContentWrap, Header } from "@/features/admin/components";
import NotificationItem from "../NotificationItem.vue";
import { useMarkNotificationsRead, useNotifications } from "../queries";
import { useOpenNotification } from "../useOpenNotification";
import ChoiceButton from "./ChoiceButton.vue";

const PAGE_SIZE = 20;
const page = ref(1);
const unreadOnly = ref(false);

const query = useNotifications(page, PAGE_SIZE, unreadOnly);
const markRead = useMarkNotificationsRead();
const openNotification = useOpenNotification();

const rows = computed(() => query.data.value?.rows ?? []);
const unread = computed(() => query.data.value?.unread ?? 0);
const pageCount = computed(() => Math.max(1, Math.ceil((query.data.value?.total ?? 0) / PAGE_SIZE)));

const setUnreadOnly = (value: boolean) => {
  unreadOnly.value = value;
  page.value = 1;
};
</script>
