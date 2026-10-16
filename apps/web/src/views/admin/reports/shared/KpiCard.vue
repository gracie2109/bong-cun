<template>
  <div class="rounded-xl border bg-white p-4">
    <p class="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{{ label }}</p>
    <p class="mt-1 text-2xl font-bold tracking-tight">{{ value }}</p>
    <p class="mt-1 flex flex-wrap items-center gap-x-2 text-xs text-muted-foreground">
      <span v-if="change" class="font-semibold" :class="changeClass">{{ arrow }} {{ percent(change.percent) }}</span>
      <span v-else-if="compare">—</span>
      <span v-if="compare && change">{{ $t("reports.vsPrevious") }}</span>
      <span v-if="hint" :class="hintWarn ? 'text-amber-600' : ''">{{ hint }}</span>
    </p>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { delta, percent } from "./format";

const props = defineProps<{
  label: string;
  value: string;
  /** Current and previous figures; leave out for a card with no comparison. */
  compare?: { current: number; previous: number };
  /** True when a rise is bad news (refunds). */
  riseIsBad?: boolean;
  hint?: string;
  hintWarn?: boolean;
}>();

const change = computed(() => (props.compare ? delta(props.compare.current, props.compare.previous) : null));
const arrow = computed(() => (change.value?.direction === "up" ? "▲" : change.value?.direction === "down" ? "▼" : "•"));
const changeClass = computed(() => {
  const direction = change.value?.direction;
  if (!direction || direction === "flat") return "text-muted-foreground";
  const good = (direction === "up") !== !!props.riseIsBad;
  return good ? "text-emerald-600" : "text-red-600";
});
</script>
