<template>
  <div class="space-y-2">
    <h3 class="text-sm font-semibold">{{ $t("attendance.today.history") }}</h3>
    <p v-if="!changes.length" class="text-sm text-muted-foreground">{{ $t("attendance.today.noHistory") }}</p>
    <ul v-else class="space-y-2">
      <li v-for="change in changes" :key="change.id" class="rounded-lg border bg-muted/30 px-3 py-2 text-sm">
        <div class="flex items-center justify-between gap-2">
          <span class="font-semibold">{{ $t(`attendance.today.action.${change.action}`) }}</span>
          <span class="text-xs text-muted-foreground">{{ dayMonth(change.changedAt) }} {{ timeOf(change.changedAt) }} · {{ change.changedByName ?? $t("attendance.today.system") }}</span>
        </div>
        <p v-if="change.reason" class="text-muted-foreground">{{ change.reason }}</p>
      </li>
    </ul>
  </div>
</template>

<script lang="ts" setup>
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { EntryChange } from "@bongcun/core/attendance";

defineProps<{ changes: EntryChange[] }>();
</script>
