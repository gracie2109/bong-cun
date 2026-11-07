<template>
  <span class="flex flex-wrap gap-1">
    <span v-if="request.expired" class="rounded-md bg-muted px-1.5 py-0.5 text-xs font-semibold text-muted-foreground">{{ $t("attendance.requests.flags.expired") }}</span>
    <span v-if="request.onLeave" class="rounded-md bg-sky-50 px-1.5 py-0.5 text-xs font-semibold text-sky-800">{{ $t("attendance.requests.flags.onLeave") }}</span>
    <span v-if="request.availability === 'unavailable'" class="rounded-md bg-amber-50 px-1.5 py-0.5 text-xs font-semibold text-amber-800">{{ $t("attendance.requests.flags.unavailable") }}</span>
    <span v-else-if="request.availability === 'preferred'" class="rounded-md bg-emerald-50 px-1.5 py-0.5 text-xs font-semibold text-emerald-800">{{ $t("attendance.requests.flags.preferred") }}</span>
    <span v-if="request.overlapsAssignment" class="rounded-md bg-rose-50 px-1.5 py-0.5 text-xs font-semibold text-rose-800">{{ $t("attendance.requests.flags.overlap") }}</span>
    <span v-if="request.status === 'approved' && !request.onRoster" class="rounded-md bg-muted px-1.5 py-0.5 text-xs font-semibold text-muted-foreground">{{ $t("attendance.requests.flags.removed") }}</span>
  </span>
</template>

<script lang="ts" setup>
import type { ShiftRequest } from "@bongcun/core/attendance";

defineProps<{ request: ShiftRequest }>();
</script>
