<template>
  <li class="rounded-xl border bg-white p-3">
    <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
      <p v-if="showName" class="font-semibold">{{ request.userName }}</p>
      <LeaveStatusPill :status="request.status" />
      <span class="rounded-md border px-2 py-0.5 text-xs font-semibold">{{ $t(`attendance.leaveType.${request.leaveType}`) }}</span>
      <span class="text-sm">
        {{ dayMonth(request.fromDate) }}<template v-if="request.toDate !== request.fromDate">–{{ dayMonth(request.toDate) }}</template>
        <template v-if="request.part !== 'full'"> · {{ $t(`attendance.leavePart.${request.part}`) }}</template>
      </span>
      <span class="text-sm text-muted-foreground">{{ request.days }} {{ $t("attendance.leave.days") }}</span>
      <span v-if="request.branchName" class="text-sm text-muted-foreground">{{ request.branchName }}</span>
      <span class="ml-auto flex gap-2">
        <slot name="actions" />
      </span>
    </div>
    <p class="mt-1 text-sm text-muted-foreground">{{ request.reason }}</p>
    <p v-if="request.decidedByName" class="mt-1 text-xs text-muted-foreground">
      {{ $t("attendance.leave.decidedBy", { name: request.decidedByName }) }}<template v-if="request.decisionNote"> · {{ request.decisionNote }}</template>
    </p>
  </li>
</template>

<script lang="ts" setup>
import { dayMonth } from "@/features/admin/attendance/shared/attendanceFormat";
import type { LeaveRequest } from "@bongcun/core/attendance";
import LeaveStatusPill from "./LeaveStatusPill.vue";

defineProps<{ request: LeaveRequest; showName?: boolean }>();
</script>
