<template>
  <li class="flex items-start gap-3 rounded-xl border bg-white p-3">
    <input
      v-if="selectable"
      type="checkbox"
      class="mt-1 size-5 shrink-0"
      :checked="selected"
      :aria-label="$t('attendance.requests.select', { name: request.userName })"
      @change="emit('toggle')"
    />
    <div class="min-w-0 flex-1 space-y-1">
      <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
        <p class="font-semibold">{{ request.userName }}</p>
        <LeaveStatusPill :status="request.status" />
        <ShiftChip :color="request.color" :name="request.name" />
        <span class="text-sm tabular-nums">
          {{ $t(`attendance.weekday.${isoWeekday(request.workDate)}`) }} {{ dayMonth(request.workDate) }} · {{ timeOf(request.startAt) }}–{{ timeOf(request.endAt) }}
        </span>
        <span class="text-sm text-muted-foreground">{{ request.branchName }}</span>
      </div>
      <RequestFlags :request="request" />
      <p v-if="request.note" class="text-sm text-muted-foreground">{{ request.note }}</p>
      <p v-if="request.decidedByName" class="text-xs text-muted-foreground">
        {{ $t("attendance.leave.decidedBy", { name: request.decidedByName }) }}<template v-if="request.decisionNote"> · {{ request.decisionNote }}</template>
      </p>
    </div>
    <slot name="actions" />
  </li>
</template>

<script lang="ts" setup>
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import ShiftChip from "@/features/admin/attendance/shared/ShiftChip.vue";
import { isoWeekday } from "@bongcun/core/attendance";
import type { ShiftRequest } from "@bongcun/core/attendance";
import LeaveStatusPill from "../leave/LeaveStatusPill.vue";
import RequestFlags from "./RequestFlags.vue";

defineProps<{ request: ShiftRequest; selectable: boolean; selected: boolean }>();
const emit = defineEmits<{ toggle: [] }>();
</script>
