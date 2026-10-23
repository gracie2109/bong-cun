<template>
  <WidgetCard
    :title="$t('dashboard.spa.title')"
    :icon="Scissors"
    :state="state"
    :to="{ name: 'spaBoard' }"
    :link-label="$t('dashboard.spa.open')"
    :empty-text="board?.isClosed ? $t('dashboard.spa.closed') : $t('dashboard.spa.empty')"
    @retry="refetch()"
  >
    <dl class="grid grid-cols-2 gap-3 sm:grid-cols-4">
      <div v-for="key in KEYS" :key="key">
        <dt class="text-xs text-muted-foreground">{{ $t(`dashboard.spa.${key}`) }}</dt>
        <dd class="text-xl font-bold">{{ counts[key] }}</dd>
      </div>
    </dl>
    <ul v-if="upcoming.length" class="mt-3 space-y-1 border-t pt-3 text-sm">
      <li v-for="ticket in upcoming" :key="ticket.id" class="flex items-center gap-3">
        <span class="w-12 font-semibold">{{ timeOf(ticket.startAt) }}</span>
        <span class="min-w-0 flex-1 truncate">{{ ticket.name }}<template v-if="ticket.petName"> · {{ ticket.petName }}</template></span>
      </li>
    </ul>
  </WidgetCard>
</template>

<script lang="ts" setup>
import { Scissors } from "lucide-vue-next";
import { timeOf } from "@/features/admin/schedule/format";
import WidgetCard from "../../kit/WidgetCard.vue";
import { useSpaToday } from "./useSpaToday";

const KEYS = ["waiting", "inProgress", "done", "cancelled"] as const;
const { state, board, counts, upcoming, refetch } = useSpaToday();
</script>
