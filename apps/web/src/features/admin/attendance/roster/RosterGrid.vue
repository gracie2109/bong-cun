<template>
  <div class="min-h-0 flex-1 overflow-auto rounded-xl border bg-white">
    <table class="w-full border-collapse text-sm">
      <thead class="sticky top-0 z-20 bg-white">
        <tr>
          <th class="sticky left-0 z-30 min-w-44 bg-white px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
            {{ $t("attendance.roster.staff") }}
          </th>
          <th v-for="day in days" :key="day" class="border-l px-2 py-3 text-center" :class="day === today && 'bg-primary/5 text-primary'">
            <span class="block text-[11px] font-semibold uppercase tracking-wide">{{ $t(`attendance.weekday.${isoWeekday(day)}`) }}</span>
            <span class="block text-sm font-semibold tabular-nums">{{ day.slice(8) }}/{{ day.slice(5, 7) }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="rows.length === 0">
          <td :colspan="days.length + 1" class="px-4 py-10 text-center text-muted-foreground">{{ $t("attendance.roster.noStaff") }}</td>
        </tr>
        <tr v-for="row in rows" :key="row.staff.userId" class="border-t">
          <th class="sticky left-0 z-10 bg-white px-4 py-2 text-left font-normal">
            <button v-if="canOpen" type="button" class="block text-left font-semibold hover:underline" :title="$t('attendance.availability.edit')" @click="emit('availability', row.staff)">{{ row.staff.name }}</button>
            <span v-else class="block font-semibold">{{ row.staff.name }}</span>
            <span class="block text-xs text-muted-foreground">{{ row.staff.role }} · {{ $t("attendance.roster.shiftCount", { n: row.shiftCount }) }}</span>
          </th>
          <RosterCell
            v-for="cell in row.cells"
            :key="cell.date"
            :cell="cell"
            :is-today="cell.date === today"
            :can-create="canCreate"
            :can-open="canOpen"
            :can-decide="canDecide"
            @decide="emit('decide', $event)"
            @add="emit('add', row.staff, cell.date)"
            @edit="emit('edit', row.staff, cell.date, $event)"
          />
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import { todayInVietnam } from "@/lib/businessDate";
import { isoWeekday } from "@bongcun/core/attendance";
import type { RosterAssignment, RosterRequest, RosterStaff } from "@bongcun/core/attendance";
import RosterCell from "./RosterCell.vue";
import type { RosterRowData } from "./rosterGrid";

defineProps<{ rows: RosterRowData[]; days: string[]; canCreate: boolean; canOpen: boolean; canDecide: boolean }>();
const emit = defineEmits<{
  add: [staff: RosterStaff, date: string];
  edit: [staff: RosterStaff, date: string, assignment: RosterAssignment];
  decide: [request: RosterRequest];
  availability: [staff: RosterStaff];
}>();

const today = todayInVietnam();
</script>
