<template>
  <div class="min-h-0 flex-1 overflow-auto rounded-xl border bg-white">
    <table class="border-collapse text-sm">
      <thead class="sticky top-0 z-10 bg-muted text-xs text-muted-foreground">
        <tr>
          <th class="sticky left-0 z-20 min-w-40 bg-muted px-3 py-2 text-left font-semibold">{{ $t("attendance.timesheet.cols.name") }}</th>
          <th v-for="day in grid.days" :key="day" class="min-w-9 border-l px-1 py-2 font-semibold" :class="isSunday(day) ? 'text-red-700' : ''">{{ day.slice(8) }}</th>
          <th class="border-l px-2 py-2 font-semibold">{{ $t("attendance.timesheet.cols.daysWorked") }}</th>
          <th class="border-l px-2 py-2 font-semibold">{{ $t("attendance.timesheet.cols.hours") }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="person in grid.staff" :key="person.userId" class="border-t">
          <th class="sticky left-0 z-10 bg-white px-3 py-1 text-left font-medium">{{ person.name }}</th>
          <MonthGridCell v-for="cell in person.cells" :key="cell.date" :cell="cell" />
          <td class="border-l px-2 text-center font-semibold tabular-nums">{{ person.totals.daysWorked }}</td>
          <td class="border-l px-2 text-center tabular-nums">{{ formatMinutes(person.totals.workedMinutes) }}</td>
        </tr>
        <tr v-if="!grid.staff.length">
          <td :colspan="grid.days.length + 3" class="px-3 py-6 text-center text-muted-foreground">{{ $t("attendance.timesheet.empty") }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import type { TimesheetGrid } from "@bongcun/core/attendance";
import { formatMinutes } from "../shared/attendanceFormat";
import MonthGridCell from "./MonthGridCell.vue";

defineProps<{ grid: TimesheetGrid }>();

const isSunday = (date: string): boolean => new Date(`${date}T00:00:00Z`).getUTCDay() === 0;
</script>
