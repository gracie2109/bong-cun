<template>
  <section class="rounded-xl border bg-white p-4">
    <h2 class="mb-3 font-semibold">{{ $t("attendance.me.entries") }}</h2>
    <p v-if="!entries.length" class="text-sm text-muted-foreground">{{ $t("attendance.me.noEntries") }}</p>
    <ul v-else class="space-y-2">
      <li v-for="entry in entries" :key="entry.id" class="flex flex-wrap items-center gap-x-3 gap-y-1 rounded-lg bg-muted/30 px-3 py-2 text-sm">
        <span class="w-12 font-semibold">{{ dayMonth(entry.workDate) }}</span>
        <span>{{ timeOf(entry.checkInAt) }}<template v-if="entry.checkOutAt"> – {{ timeOf(entry.checkOutAt) }}</template><template v-else> – …</template></span>
        <span v-if="entry.checkOutAt" class="text-muted-foreground">{{ formatMinutes(minutesBetween(entry.checkInAt, entry.checkOutAt)) }}</span>
        <span class="text-muted-foreground">{{ entry.branchName }}</span>
        <span v-if="entry.reviewReason" class="rounded-md border border-amber-200 bg-amber-50 px-2 py-0.5 text-xs font-semibold text-amber-900">
          {{ $t(`attendance.today.reason_${entry.reviewReason}`) }}
        </span>
      </li>
    </ul>
  </section>
</template>

<script lang="ts" setup>
import { dayMonth, formatMinutes, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { MyEntry } from "@bongcun/core/attendance";

defineProps<{ entries: MyEntry[] }>();

const minutesBetween = (from: string, to: string) => (new Date(to).getTime() - new Date(from).getTime()) / 60_000;
</script>
