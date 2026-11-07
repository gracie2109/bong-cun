<template>
  <ul class="grid gap-2 sm:grid-cols-2 lg:grid-cols-4">
    <li v-for="[day, list] in grouped" :key="day" class="rounded-lg border bg-white p-2 text-sm">
      <p class="mb-1 font-semibold">{{ $t(`attendance.weekday.${day}`) }}</p>
      <p v-if="!list.length" class="text-muted-foreground">—</p>
      <p
        v-for="(item, index) in list"
        :key="index"
        class="rounded px-2 py-1"
        :class="item.kind === 'unavailable' ? 'bg-muted text-muted-foreground' : 'bg-emerald-50 text-emerald-800'"
      >
        {{ $t(`attendance.availability.${item.kind}`) }}
        <span class="font-medium">{{ isWholeDay(item) ? $t("attendance.availability.wholeDay") : `${item.startTime}–${item.endTime}` }}</span>
      </p>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { groupByWeekday, isWholeDay } from "@bongcun/core/attendance";
import type { AvailabilityItem } from "@bongcun/core/attendance";

const props = defineProps<{ items: AvailabilityItem[] }>();
const grouped = computed(() => [...groupByWeekday(props.items)]);
</script>
