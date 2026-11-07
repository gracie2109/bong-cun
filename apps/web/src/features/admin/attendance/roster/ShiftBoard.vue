<template>
  <div class="min-h-0 flex-1 overflow-auto rounded-xl border bg-white">
    <table class="w-full border-collapse text-sm">
      <thead class="sticky top-0 z-20 bg-white">
        <tr>
          <th class="sticky left-0 z-30 min-w-40 bg-white px-4 py-3 text-left text-[11px] font-semibold uppercase tracking-wide text-muted-foreground">
            {{ $t("attendance.roster.shiftColumn") }}
          </th>
          <th v-for="day in days" :key="day" class="border-l px-2 py-3 text-center" :class="day === today && 'bg-primary/5 text-primary'">
            <span class="block text-[11px] font-semibold uppercase tracking-wide">{{ $t(`attendance.weekday.${isoWeekday(day)}`) }}</span>
            <span class="block text-sm font-semibold tabular-nums">{{ day.slice(8) }}/{{ day.slice(5, 7) }}</span>
            <span class="block text-[11px] font-normal text-muted-foreground">{{ $t("attendance.roster.people", { n: board.dayTotals[day] ?? 0 }) }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="board.rows.length === 0">
          <td :colspan="days.length + 1" class="px-4 py-10 text-center text-muted-foreground">{{ $t("attendance.roster.noTemplates") }}</td>
        </tr>
        <tr v-for="row in board.rows" :key="row.key" class="border-t">
          <th class="sticky left-0 z-10 bg-white px-4 py-2 text-left font-normal">
            <ShiftChip :color="row.color" :name="row.name" />
            <span class="mt-1 block text-xs tabular-nums text-muted-foreground">{{ row.startTime }}–{{ row.endTime }}</span>
          </th>
          <ShiftBoardCell
            v-for="day in days"
            :key="day"
            :entries="row.cells[day] ?? []"
            :color="row.color"
            :is-today="day === today"
            :past="day < today"
            :can-create="canCreate && day >= today && row.templateId !== null"
            :can-open="canOpen && day >= today"
            :staff="staff"
            @edit="(person, assignment) => emit('edit', person, day, assignment)"
            @add="(person) => emit('add', person, day, row.templateId)"
          />
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import { todayInVietnam } from "@/lib/businessDate";
import ShiftChip from "@/features/admin/attendance/shared/ShiftChip.vue";
import { isoWeekday } from "@bongcun/core/attendance";
import type { Roster, RosterAssignment, RosterStaff } from "@bongcun/core/attendance";
import ShiftBoardCell from "./ShiftBoardCell.vue";
import { buildShiftBoard } from "./shiftBoard";

const props = defineProps<{ roster: Roster; days: string[]; canCreate: boolean; canOpen: boolean }>();
const emit = defineEmits<{
  edit: [staff: RosterStaff, date: string, assignment: RosterAssignment];
  add: [staff: RosterStaff, date: string, templateId: string | null];
}>();

const today = todayInVietnam();
const board = computed(() => buildShiftBoard(props.roster, props.days));
const staff = computed(() => props.roster.staff);
</script>
