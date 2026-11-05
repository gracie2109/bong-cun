<template>
  <div class="flex flex-wrap gap-2" role="radiogroup" :aria-label="$t('attendance.templates.color')">
    <button
      v-for="color in SHIFT_COLORS"
      :key="color"
      type="button"
      role="radio"
      :aria-checked="color === modelValue"
      class="flex min-h-11 items-center gap-2 rounded-lg border px-3 text-sm font-semibold transition-colors"
      :class="color === modelValue ? `${SHIFT_COLOR_CLASS[color].chip} ring-2 ring-primary` : 'bg-white text-muted-foreground hover:bg-muted'"
      @click="emit('update:modelValue', color)"
    >
      <span class="size-3 rounded-full" :class="SHIFT_COLOR_CLASS[color].dot" />
      {{ $t(`attendance.colors.${color}`) }}
    </button>
  </div>
</template>

<script lang="ts" setup>
import { SHIFT_COLORS } from "@bongcun/core/attendance";
import type { ShiftColor } from "@bongcun/core/attendance";
import { SHIFT_COLOR_CLASS } from "@/features/admin/attendance/shared/shiftColors";

defineProps<{ modelValue: ShiftColor }>();
const emit = defineEmits<{ "update:modelValue": [value: ShiftColor] }>();
</script>
