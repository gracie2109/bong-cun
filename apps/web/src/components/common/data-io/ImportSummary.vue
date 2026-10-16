<template>
  <div class="grid grid-cols-3 gap-3">
    <div v-for="stat in stats" :key="stat.label" class="rounded-xl border bg-white p-3">
      <p class="text-xs text-muted-foreground">{{ $t(stat.label) }}</p>
      <p class="mt-1 text-xl font-semibold" :class="stat.danger && stat.value > 0 ? 'text-destructive' : ''">{{ stat.value }}</p>
    </div>
  </div>
  <slot />
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { ImportReport } from "@bongcun/core/data-io";

const props = defineProps<{ report: ImportReport; errorCount: number }>();

const stats = computed(() => [
  { label: "dataIo.import.stat.created", value: props.report.created, danger: false },
  { label: "dataIo.import.stat.updated", value: props.report.updated, danger: false },
  { label: "dataIo.import.stat.errors", value: props.errorCount, danger: true },
]);
</script>
