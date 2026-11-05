<template>
  <li class="rounded-xl border bg-white p-3">
    <div class="flex items-center justify-between gap-3">
      <div class="min-w-0">
        <p class="truncate font-semibold">{{ line.staff.name }}</p>
        <p class="text-xs text-muted-foreground">{{ line.staff.role }}</p>
      </div>
      <span v-if="line.leave && !line.rows.length" class="rounded-md border border-sky-200 bg-sky-50 px-2 py-0.5 text-xs font-semibold text-sky-800">
        {{ $t(`attendance.leaveType.${line.leave.leaveType}`) }}
      </span>
      <span v-else-if="!line.rows.length" class="text-xs text-muted-foreground">{{ $t("attendance.today.noShift") }}</span>
    </div>

    <ul v-if="line.rows.length" class="mt-2 space-y-2">
      <li
        v-for="row in line.rows"
        :key="row.assignmentId ?? row.entryId ?? row.workDate"
        class="flex min-h-11 flex-wrap items-center gap-x-3 gap-y-1 rounded-lg bg-muted/30 px-3 py-2 text-sm"
      >
        <StatusPill :status="row.status" />
        <span class="font-medium">{{ row.shiftName ?? $t("attendance.today.unscheduled") }}</span>
        <span v-if="row.startAt && row.endAt" class="text-muted-foreground">{{ timeOf(row.startAt) }}–{{ timeOf(row.endAt) }}</span>
        <span v-if="row.checkInAt" class="text-muted-foreground">
          {{ $t("attendance.today.in") }} {{ timeOf(row.checkInAt) }}<template v-if="row.checkOutAt"> · {{ $t("attendance.today.out") }} {{ timeOf(row.checkOutAt) }}</template>
        </span>
        <span v-if="row.lateMinutes" class="text-amber-700">{{ $t("attendance.today.late", { minutes: row.lateMinutes }) }}</span>
        <span v-if="row.earlyMinutes" class="text-amber-700">{{ $t("attendance.today.early", { minutes: row.earlyMinutes }) }}</span>
        <span v-if="row.overtimeMinutes" class="text-emerald-700">{{ $t("attendance.today.overtime", { minutes: row.overtimeMinutes }) }}</span>
        <Button v-if="canEdit && (row.entryId || row.assignmentId)" type="button" size="sm" variant="ghost" class="ml-auto min-h-9" @click="emit('edit', row)">
          <Pencil class="mr-1 size-3.5" />
          {{ row.entryId ? $t("attendance.today.fix") : $t("attendance.today.record") }}
        </Button>
      </li>
    </ul>
  </li>
</template>

<script lang="ts" setup>
import { Pencil } from "lucide-vue-next";
import { Button } from "@/components/ui/button";
import { timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import StatusPill from "@/features/admin/attendance/shared/StatusPill.vue";
import type { AttendanceRow } from "@bongcun/core/attendance";
import type { StaffLine } from "./todayBoard";

defineProps<{ line: StaffLine; canEdit: boolean }>();
const emit = defineEmits<{ edit: [row: AttendanceRow] }>();
</script>
