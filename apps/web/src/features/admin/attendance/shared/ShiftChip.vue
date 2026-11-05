<template>
  <span class="inline-flex items-center gap-1.5 rounded-md border px-2 py-0.5 text-xs font-semibold" :class="SHIFT_COLOR_CLASS[color].chip">
    <span class="size-1.5 rounded-full" :class="SHIFT_COLOR_CLASS[color].dot" />
    <slot>{{ name }}</slot>
  </span>
</template>

<script lang="ts" setup>
import type { ShiftColor } from "@bongcun/core/attendance";
import { SHIFT_COLOR_CLASS } from "./shiftColors";

defineProps<{ name?: string; color: ShiftColor }>();
</script>
