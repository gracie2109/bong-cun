<template>
  <p v-if="rows.length" class="rounded-lg border px-3 py-2 text-sm" :class="blocked ? 'border-amber-200 bg-amber-50 text-amber-900' : 'bg-muted/30'">
    <span class="font-semibold">{{ $t("attendance.roster.availabilityOf", { name }) }}:</span>
    <template v-for="(item, index) in rows" :key="index">
      {{ index ? "; " : " " }}{{ $t(`attendance.availability.${item.kind}`) }}
      {{ item.startTime && item.endTime ? `${item.startTime}–${item.endTime}` : $t("attendance.availability.wholeDay") }}
    </template>
  </p>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { isoWeekday } from "@bongcun/core/attendance";
import type { RosterAvailability } from "@bongcun/core/attendance";

const props = defineProps<{ availability: RosterAvailability[]; userId: string | undefined; date: string; name: string }>();

const rows = computed(() =>
  !props.userId || !props.date ? [] : props.availability.filter((item) => item.userId === props.userId && item.weekday === isoWeekday(props.date))
);
const blocked = computed(() => rows.value.some((item) => item.kind === "unavailable"));
</script>
