<template>
  <section class="rounded-xl border bg-white p-4">
    <h2 class="mb-3 font-semibold">{{ $t("attendance.me.upcoming") }}</h2>
    <p v-if="!shifts.length" class="text-sm text-muted-foreground">{{ $t("attendance.me.noShifts") }}</p>
    <ul v-else class="space-y-2">
      <li v-for="shift in shifts" :key="shift.id" class="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-lg bg-muted/30 px-3 py-2 text-sm">
        <span class="w-12 font-semibold">{{ dayMonth(shift.workDate) }}</span>
        <span class="font-medium">{{ shift.name }}</span>
        <span class="text-muted-foreground">{{ timeOf(shift.startAt) }}–{{ timeOf(shift.endAt) }}</span>
        <span class="text-muted-foreground">{{ shift.branchName }}</span>
        <span v-if="shift.note" class="text-muted-foreground">· {{ shift.note }}</span>
      </li>
    </ul>
    <ul v-if="leaves.length" class="mt-3 space-y-1 text-sm text-sky-800">
      <li v-for="(leave, index) in leaves" :key="index">
        {{ $t(`attendance.leaveType.${leave.leaveType}`) }}: {{ dayMonth(leave.fromDate) }}<template v-if="leave.toDate !== leave.fromDate">–{{ dayMonth(leave.toDate) }}</template>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { MyShift, RosterLeave } from "@bongcun/core/attendance";

defineProps<{ shifts: MyShift[]; leaves: RosterLeave[] }>();
</script>
