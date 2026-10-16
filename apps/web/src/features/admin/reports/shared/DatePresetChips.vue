<template>
  <div class="flex flex-wrap items-center gap-2">
    <div class="flex flex-wrap gap-1 rounded-lg border bg-white p-1">
      <button
        v-for="item in PRESETS"
        :key="item"
        type="button"
        class="rounded-md px-2.5 py-1 text-xs font-semibold transition-colors"
        :class="preset === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
        @click="emit('select', item)"
      >
        {{ $t(`reports.presets.${item}`) }}
      </button>
    </div>
    <template v-if="preset === 'custom'">
      <Input type="date" class="h-9 w-40" :model-value="range.from" :max="range.to" :aria-label="$t('reports.from')" @update:model-value="setFrom" />
      <span class="text-muted-foreground">–</span>
      <Input type="date" class="h-9 w-40" :model-value="range.to" :min="range.from" :aria-label="$t('reports.to')" @update:model-value="setTo" />
    </template>
  </div>
</template>

<script lang="ts" setup>
import { Input } from "@/components/ui/input";
import { isIsoDate, PRESETS, type DateRange, type Preset } from "./dateRange";

const props = defineProps<{ preset: Preset; range: DateRange }>();
const emit = defineEmits<{ select: [preset: Preset]; "update:range": [range: DateRange] }>();

const setFrom = (value: string | number) => {
  if (isIsoDate(value)) emit("update:range", { from: value, to: props.range.to });
};
const setTo = (value: string | number) => {
  if (isIsoDate(value)) emit("update:range", { from: props.range.from, to: value });
};
</script>
