<template>
  <td class="min-w-36 border-l p-1 align-top" :class="[leaveClass, isToday && 'bg-primary/5', cell.blocked && 'bg-[repeating-linear-gradient(135deg,transparent,transparent_6px,rgba(148,163,184,0.18)_6px,rgba(148,163,184,0.18)_12px)]']" :title="cell.blocked ? $t('attendance.roster.blockedDay') : undefined">
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
      <RosterRequestChip v-for="request in cell.requests" :key="request.id" :request="request" :can-decide="canDecide" @decide="emit('decide', request)" />
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
import type { RosterAssignment, RosterRequest } from "@bongcun/core/attendance";
import RosterRequestChip from "./RosterRequestChip.vue";
import type { RosterCellData } from "./rosterGrid";

defineProps<{ cell: RosterCellData; isToday: boolean; leaveClass?: string; canCreate: boolean; canOpen: boolean; canDecide: boolean }>();
const emit = defineEmits<{ add: []; edit: [assignment: RosterAssignment]; decide: [request: RosterRequest] }>();
</script>
