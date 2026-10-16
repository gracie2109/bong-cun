<template>
  <div class="space-y-1.5">
    <Label>{{ $t("medical.ward.hours") }}</Label>
    <div class="flex flex-wrap gap-2">
      <button
        v-for="hour in hours"
        :key="hour"
        type="button"
        class="rounded-full border px-3 py-1 text-sm font-semibold transition-colors"
        :class="modelValue.includes(hour) ? 'border-primary bg-primary text-primary-foreground' : 'bg-white text-muted-foreground hover:bg-muted'"
        @click="toggle(hour)"
      >
        {{ hour }}
      </button>
    </div>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { Label } from "@/components/ui/label";
import { HOUR_PRESETS } from "./orderDraft";

const props = defineProps<{ modelValue: string[] }>();
const emit = defineEmits<{ "update:modelValue": [value: string[]] }>();

// An order made before keeps its own hours even when they are not one of the presets.
const hours = computed(() => [...new Set([...HOUR_PRESETS, ...props.modelValue])].sort());

const toggle = (hour: string) => {
  const times = props.modelValue;
  emit("update:modelValue", times.includes(hour) ? times.filter((time) => time !== hour) : [...times, hour].sort());
};
</script>
