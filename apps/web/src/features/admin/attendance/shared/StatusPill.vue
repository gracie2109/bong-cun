<template>
  <span class="inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-semibold" :class="TONE[status]">
    {{ $t(`attendance.status.${status}`) }}
  </span>
</template>

<script lang="ts" setup>
import type { AttendanceStatus } from "@bongcun/core/attendance";

defineProps<{ status: AttendanceStatus }>();

const OK = "border-emerald-200 bg-emerald-50 text-emerald-800";
const WARN = "border-amber-200 bg-amber-50 text-amber-900";
const BAD = "border-red-200 bg-red-50 text-red-800";
const MUTED = "border-slate-200 bg-slate-50 text-slate-600";

const TONE: Record<AttendanceStatus, string> = {
  leave: "border-sky-200 bg-sky-50 text-sky-800",
  missing_checkout: BAD,
  working: OK,
  unscheduled: WARN,
  late_early: WARN,
  late: WARN,
  early: WARN,
  present: OK,
  absent: BAD,
  not_in: BAD,
  upcoming: MUTED,
};
</script>
