<template>
  <div class="grid grid-cols-2 gap-3 sm:grid-cols-5">
    <div v-for="item in items" :key="item.key" class="rounded-xl border bg-white px-4 py-3">
      <p class="text-xs text-muted-foreground">{{ $t(`boarding.board.stats.${item.key}`) }}</p>
      <p class="text-2xl font-bold" :class="item.key === 'overdue' && counts.overdue > 0 && 'text-red-600'">{{ item.value }}</p>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { BoardCounts } from "@bongcun/core/boarding";

const props = defineProps<{ counts: BoardCounts }>();

const KEYS = ["arriving", "departing", "occupied", "overdue", "free"] as const;
const items = computed(() => KEYS.map((key) => ({ key, value: props.counts[key] })));
</script>
