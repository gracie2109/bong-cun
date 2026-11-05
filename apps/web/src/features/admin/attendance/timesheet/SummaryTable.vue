<template>
  <div class="min-h-0 flex-1 overflow-auto rounded-xl border bg-white">
    <table class="w-full min-w-[56rem] text-sm">
      <thead class="sticky top-0 bg-muted/60 text-left text-xs text-muted-foreground">
        <tr>
          <th class="px-3 py-2 font-semibold">{{ $t("attendance.timesheet.cols.name") }}</th>
          <th v-for="col in NUMBER_COLUMNS" :key="col" class="px-3 py-2 text-right font-semibold">{{ $t(`attendance.timesheet.cols.${col}`) }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :key="row.userId" class="border-t">
          <td class="px-3 py-2">
            <p class="font-medium">{{ row.name }}</p>
            <p v-if="row.branchCodes" class="text-xs text-muted-foreground">{{ row.branchCodes }}</p>
          </td>
          <td class="px-3 py-2 text-right tabular-nums">{{ row.shiftsWorked }}/{{ row.shiftsScheduled }}</td>
          <td class="px-3 py-2 text-right tabular-nums">{{ formatMinutes(row.workedMinutes) }}</td>
          <td class="px-3 py-2 text-right tabular-nums" :class="warn(row.lateCount)">{{ row.lateCount }}<small v-if="row.lateCount"> · {{ row.lateMinutes }}p</small></td>
          <td class="px-3 py-2 text-right tabular-nums" :class="warn(row.earlyCount)">{{ row.earlyCount }}<small v-if="row.earlyCount"> · {{ row.earlyMinutes }}p</small></td>
          <td class="px-3 py-2 text-right tabular-nums">{{ formatMinutes(row.overtimeMinutes) }}</td>
          <td class="px-3 py-2 text-right tabular-nums" :class="row.absentCount ? 'font-semibold text-red-700' : ''">{{ row.absentCount }}</td>
          <td class="px-3 py-2 text-right tabular-nums" :class="warn(row.missingCheckoutCount)">{{ row.missingCheckoutCount }}</td>
          <td class="px-3 py-2 text-right tabular-nums">{{ row.leaveAnnual }}</td>
          <td class="px-3 py-2 text-right tabular-nums">{{ row.leaveSick }}</td>
          <td class="px-3 py-2 text-right tabular-nums">{{ row.leaveUnpaid + row.leaveOther }}</td>
        </tr>
        <tr v-if="!rows.length && !loading">
          <td :colspan="NUMBER_COLUMNS.length + 1" class="px-3 py-6 text-center text-muted-foreground">{{ $t("attendance.timesheet.empty") }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import type { TimesheetRow } from "@bongcun/core/attendance";
import { formatMinutes } from "../shared/attendanceFormat";

defineProps<{ rows: TimesheetRow[]; loading: boolean }>();

const NUMBER_COLUMNS = ["shifts", "worked", "late", "early", "overtime", "absent", "missing", "annual", "sick", "otherLeave"] as const;
const warn = (count: number): string => (count > 0 ? "text-amber-700" : "");
</script>
