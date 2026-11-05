<template>
  <td class="border-l p-0 text-center" :title="title">
    <span class="flex h-9 min-w-9 items-center justify-center text-xs font-semibold" :class="CODE_TONE[cell.code]">{{ cell.code }}</span>
  </td>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { GridCell } from "@bongcun/core/attendance";
import { formatMinutes, timeOf } from "../shared/attendanceFormat";
import { CODE_TONE } from "./gridCodes";

const props = defineProps<{ cell: GridCell }>();

// Hovering a cell lists what is behind the code: each shift with its status and the clock times.
const title = computed(() =>
  props.cell.detail
    .map((part) => {
      const span = part.checkInAt ? `${timeOf(part.checkInAt)}-${part.checkOutAt ? timeOf(part.checkOutAt) : "…"}` : "";
      return [part.shiftName, span, part.workedMinutes ? formatMinutes(part.workedMinutes) : ""].filter(Boolean).join(" · ");
    })
    .join("\n")
);
</script>
