<template>
  <div class="space-y-2 text-sm">
    <label class="block space-y-1">
      <span class="font-medium">{{ $t("dashboard.add.range") }}</span>
      <select :value="mode" class="h-9 w-full rounded-md border bg-white px-2" @change="onMode(($event.target as HTMLSelectElement).value)">
        <option value="default">{{ $t("dashboard.add.rangeDefault", { range: $t(`dashboard.range.${fallback}`) }) }}</option>
        <option v-for="preset in RANGE_PRESETS" :key="preset" :value="preset">{{ $t(`dashboard.range.${preset}`) }}</option>
        <option value="fixed">{{ $t("dashboard.add.rangeFixed") }}</option>
      </select>
    </label>
    <div v-if="range?.kind === 'fixed'" class="grid grid-cols-2 gap-2">
      <input type="date" :value="range.from" class="h-9 rounded-md border bg-white px-2" @change="onDate('from', $event)" />
      <input type="date" :value="range.to" class="h-9 rounded-md border bg-white px-2" @change="onDate('to', $event)" />
    </div>
    <p v-if="range?.kind === 'fixed' && !usable" class="text-xs text-red-600">{{ $t("dashboard.add.rangeInvalid") }}</p>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { RANGE_PRESETS, type RangeConfig, type RangePreset } from "@bongcun/core/dashboard";
import { useToday } from "../useToday";
import { isUsableRange } from "./widgetRange";

defineProps<{ fallback: RangePreset }>();
const range = defineModel<RangeConfig | undefined>("range");
const today = useToday();

const mode = computed(() => (range.value ? (range.value.kind === "fixed" ? "fixed" : range.value.preset) : "default"));
const usable = computed(() => range.value?.kind !== "fixed" || isUsableRange(range.value));

const onMode = (value: string) => {
  if (value === "default") range.value = undefined;
  else if (value === "fixed") range.value = { kind: "fixed", from: today.value, to: today.value };
  else range.value = { kind: "preset", preset: value as RangePreset };
};
const onDate = (side: "from" | "to", event: Event) => {
  const value = (event.target as HTMLInputElement).value;
  if (range.value?.kind === "fixed" && value) range.value = { ...range.value, [side]: value };
};
</script>
