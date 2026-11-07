<template>
  <button
    type="button"
    class="rounded-md border border-dashed px-2 py-1 text-left text-xs font-semibold"
    :class="[SHIFT_COLOR_CLASS[request.color].chip, request.expired && 'opacity-60']"
    :disabled="!canDecide || request.expired"
    :title="$t('attendance.roster.requestTitle')"
    @click="emit('decide')"
  >
    <span class="block">{{ request.name }} · {{ $t("attendance.roster.pending") }}</span>
    <span class="block font-normal tabular-nums">{{ timeOf(request.startAt) }}–{{ timeOf(request.endAt) }}</span>
    <span v-if="request.onLeave || request.availability === 'unavailable'" class="mt-0.5 flex items-center gap-1 font-normal text-amber-800">
      <TriangleAlert class="size-3" />
      {{ request.onLeave ? $t("attendance.requests.flags.onLeave") : $t("attendance.requests.flags.unavailable") }}
    </span>
  </button>
</template>

<script lang="ts" setup>
import { TriangleAlert } from "lucide-vue-next";
import { SHIFT_COLOR_CLASS } from "@/features/admin/attendance/shared/shiftColors";
import { timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { RosterRequest } from "@bongcun/core/attendance";

defineProps<{ request: RosterRequest; canDecide: boolean }>();
const emit = defineEmits<{ decide: [] }>();
</script>
