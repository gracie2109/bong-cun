<template>
  <li class="flex flex-col gap-2 rounded-xl border bg-white p-3 sm:flex-row sm:items-start sm:gap-4" :class="[isToday && 'border-primary ring-1 ring-primary/40', past && 'opacity-70']">
    <div class="w-20 shrink-0">
      <p class="text-[11px] font-semibold uppercase tracking-wide" :class="isToday ? 'text-primary' : 'text-muted-foreground'">{{ $t(`attendance.weekday.${isoWeekday(day.date)}`) }}</p>
      <p class="text-lg font-semibold tabular-nums">{{ dayMonth(day.date) }}</p>
      <p v-if="isToday" class="text-[11px] font-semibold text-primary">{{ $t("attendance.mySchedule.today") }}</p>
    </div>
    <div class="min-w-0 flex-1 space-y-2">
      <span v-if="day.leave" class="inline-block rounded-md bg-amber-100 px-2 py-1 text-xs font-semibold text-amber-900">
        {{ $t(`attendance.leaveType.${day.leave.leaveType}`) }}<template v-if="day.leave.part !== 'full'"> · {{ $t(`attendance.leavePart.${day.leave.part}`) }}</template>
      </span>
      <div v-for="shift in day.shifts" :key="shift.id" class="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-lg border border-teal-200 bg-teal-50 px-3 py-2 text-sm text-teal-900">
        <span class="font-semibold">{{ shift.name }}</span>
        <span class="tabular-nums">{{ timeOf(shift.startAt) }}–{{ timeOf(shift.endAt) }}</span>
        <span class="text-teal-800/70">{{ shift.branchName }}</span>
        <span v-if="shift.note" class="text-teal-800/70">· {{ shift.note }}</span>
      </div>
      <p v-if="!day.shifts.length && !day.leave" class="py-1 text-sm text-muted-foreground">{{ $t("attendance.mySchedule.off") }}</p>
    </div>
  </li>
</template>

<script lang="ts" setup>
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import { isoWeekday } from "@bongcun/core/attendance";
import type { MyDay } from "./useMyWeek";

defineProps<{ day: MyDay; isToday: boolean; past: boolean }>();
</script>
