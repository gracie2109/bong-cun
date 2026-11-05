<template>
  <section class="rounded-xl border bg-white p-4">
    <h2 class="mb-3 font-semibold">{{ $t("attendance.timesheet.myTitle") }}</h2>
    <dl v-if="totals" class="grid grid-cols-2 gap-3 text-sm sm:grid-cols-3">
      <div v-for="item in items" :key="item.label">
        <dt class="text-xs text-muted-foreground">{{ $t(`attendance.timesheet.mine.${item.label}`) }}</dt>
        <dd class="text-lg font-semibold tabular-nums">{{ item.value }}</dd>
      </div>
    </dl>
  </section>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { useMyTimesheet } from "@/features/admin/attendance/queries";
import { todayInVietnam } from "@/lib/businessDate";
import { formatMinutes } from "../shared/attendanceFormat";
import { monthStart } from "../timesheet/timesheetRange";

// The month so far, from the first day to today.
const today = todayInVietnam();
const query = useMyTimesheet(monthStart(today), today);
const totals = computed(() => query.data.value?.totals ?? null);

const items = computed(() => {
  const t = totals.value;
  if (!t) return [];
  return [
    { label: "scheduled", value: formatMinutes(t.scheduledMinutes) },
    { label: "worked", value: formatMinutes(t.workedMinutes) },
    { label: "overtime", value: formatMinutes(t.overtimeMinutes) },
    { label: "late", value: `${t.lateCount} · ${t.lateMinutes}p` },
    { label: "early", value: `${t.earlyMinutes}p` },
    { label: "absent", value: String(t.absentCount) },
  ];
});
</script>
