<template>
  <section class="space-y-2">
    <h3 class="text-sm font-semibold">{{ $t("shop.admin.timeline") }}</h3>
    <ol class="space-y-2 border-l pl-4 text-sm">
      <li v-for="(event, index) in events" :key="index" class="relative">
        <span class="absolute -left-[1.3rem] top-1.5 size-2 rounded-full bg-primary" />
        <p class="font-medium">{{ $t(`shop.order.status.${event.status}`) }}</p>
        <p class="text-xs text-muted-foreground">
          {{ dateTime(event.createdAt) }}<template v-if="event.actorName"> · {{ event.actorName }}</template>
        </p>
        <p v-if="event.note" class="text-xs">{{ event.note }}</p>
      </li>
    </ol>
  </section>
</template>

<script lang="ts" setup>
import type { AdminOrderEvent } from "@bongcun/core/shop";
import { dateTime } from "@/features/admin/pos/format";

defineProps<{ events: AdminOrderEvent[] }>();
</script>
