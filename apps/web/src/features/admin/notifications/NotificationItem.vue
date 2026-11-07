<template>
  <button
    type="button"
    class="flex w-full items-start gap-3 rounded-lg px-3 py-2 text-left transition-colors hover:bg-muted/60"
    :class="{ 'bg-primary/5': !item.readAt }"
    @click="emit('open', item)"
  >
    <span class="mt-1.5 size-2 shrink-0 rounded-full" :class="item.readAt ? 'bg-transparent' : 'bg-primary'" />
    <span class="min-w-0 flex-1">
      <span class="block text-sm" :class="item.readAt ? 'font-medium' : 'font-semibold'">{{ item.title }}</span>
      <span v-if="item.body" class="mt-0.5 block text-xs text-muted-foreground">{{ item.body }}</span>
      <span class="mt-1 block text-[11px] text-muted-foreground">{{ when }}</span>
    </span>
  </button>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { AppNotification } from "@bongcun/core/notifications";
import { timeAgo } from "./format";

const props = defineProps<{ item: AppNotification }>();
const emit = defineEmits<{ open: [item: AppNotification] }>();

const { t, d } = useI18n();
const when = computed(() => {
  const ago = timeAgo(props.item.createdAt);
  return ago.unit === "date" ? d(new Date(props.item.createdAt), "shortFormat") : t(`notifications.ago.${ago.unit}`, { n: ago.value });
});
</script>
