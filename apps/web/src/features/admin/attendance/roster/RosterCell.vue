<template>
  <td class="min-w-36 border-l p-1 align-top" :class="[leaveClass, isToday && 'bg-primary/5']">
    <div class="flex min-h-11 flex-col gap-1">
      <span v-if="cell.leave" class="rounded-md bg-amber-100 px-2 py-1 text-[11px] font-semibold text-amber-900">
        {{ $t(`attendance.leaveType.${cell.leave.leaveType}`) }}<template v-if="cell.leave.part !== 'full'"> · {{ $t(`attendance.leavePart.${cell.leave.part}`) }}</template>
      </span>
      <button
        v-for="item in cell.assignments"
        :key="item.id"
        type="button"
        class="rounded-md border px-2 py-1 text-left text-xs font-semibold"
        :class="SHIFT_COLOR_CLASS[item.color].chip"
        :disabled="!canOpen"
        @click="emit('edit', item)"
      >
        <span class="block">{{ item.name }}</span>
        <span class="block font-normal tabular-nums">{{ timeOf(item.startAt) }}–{{ timeOf(item.endAt) }}</span>
        <Lock v-if="item.hasEntry" class="mt-0.5 size-3 opacity-60" />
      </button>
      <button
        v-if="canCreate"
        type="button"
        class="flex min-h-11 flex-1 items-center justify-center rounded-md text-muted-foreground/50 hover:bg-muted hover:text-foreground"
        :aria-label="$t('attendance.roster.addShift')"
        @click="emit('add')"
      >
        <Plus class="size-4" />
      </button>
    </div>
  </td>
</template>

<script lang="ts" setup>
import { Lock, Plus } from "lucide-vue-next";
import { SHIFT_COLOR_CLASS } from "@/features/admin/attendance/shared/shiftColors";
import { timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { RosterAssignment } from "@bongcun/core/attendance";
import type { RosterCellData } from "./rosterGrid";

defineProps<{ cell: RosterCellData; isToday: boolean; leaveClass?: string; canCreate: boolean; canOpen: boolean }>();
const emit = defineEmits<{ add: []; edit: [assignment: RosterAssignment] }>();
</script>
