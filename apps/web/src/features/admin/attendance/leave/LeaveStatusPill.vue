<template>
  <span class="inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-semibold" :class="TONE[status]">
    {{ $t(`attendance.leave.status.${status}`) }}
  </span>
</template>

<script lang="ts" setup>
import type { LeaveStatus, StaffRequestStatus } from "@bongcun/core/attendance";

// "submitted" is a shift request whose week is not published yet: the decision is hidden.
defineProps<{ status: LeaveStatus | StaffRequestStatus }>();

const TONE: Record<LeaveStatus | StaffRequestStatus, string> = {
  submitted: "border-sky-200 bg-sky-50 text-sky-800",
  pending: "border-amber-200 bg-amber-50 text-amber-900",
  approved: "border-emerald-200 bg-emerald-50 text-emerald-800",
  rejected: "border-red-200 bg-red-50 text-red-800",
  cancelled: "border-slate-200 bg-slate-50 text-slate-600",
};
</script>
