<template>
  <ul class="space-y-3">
    <li v-for="day in board.days" :key="day" class="rounded-xl border bg-white">
      <p class="border-b bg-muted/40 px-3 py-2 text-sm font-semibold">
        {{ $t(`attendance.weekday.${isoWeekday(day)}`) }} {{ day.slice(8) }}/{{ day.slice(5, 7) }}
      </p>
      <ul class="divide-y">
        <li v-for="template in board.templates" :key="template.id" class="flex items-center gap-3 px-3 py-2">
          <div class="min-w-0 flex-1">
            <ShiftChip :color="template.color" :name="template.name" />
            <span class="ml-2 text-xs tabular-nums text-muted-foreground">{{ template.startTime }}–{{ template.endTime }}</span>
          </div>
          <div class="w-28 shrink-0">
            <RegisterCell
              :state="cellState(board, day, template)"
              :selected="selection.has(day, template.id)"
              @toggle="selection.toggle(day, template.id)"
              @cancel="emit('cancel', $event)"
            />
          </div>
        </li>
      </ul>
    </li>
  </ul>
</template>

<script lang="ts" setup>
import { isoWeekday } from "@bongcun/core/attendance";
import type { RegistrationBoard } from "@bongcun/core/attendance";
import ShiftChip from "../shared/ShiftChip.vue";
import RegisterCell from "./RegisterCell.vue";
import { cellState } from "./registerGrid";
import type { useRegisterSelection } from "./useRegisterSelection";

defineProps<{ board: RegistrationBoard; selection: ReturnType<typeof useRegisterSelection> }>();
const emit = defineEmits<{ cancel: [id: string] }>();
</script>
