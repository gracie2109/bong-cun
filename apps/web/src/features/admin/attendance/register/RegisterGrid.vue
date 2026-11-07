<template>
  <div class="overflow-x-auto rounded-xl border bg-white">
    <table class="w-full min-w-[56rem] border-collapse text-sm">
      <thead>
        <tr class="border-b bg-muted/40 text-xs">
          <th class="sticky left-0 z-10 w-40 bg-muted/40 px-3 py-2 text-left font-semibold">{{ $t("attendance.register.shift") }}</th>
          <th v-for="day in board.days" :key="day" class="px-2 py-2 text-center font-semibold">
            {{ $t(`attendance.weekday.${isoWeekday(day)}`) }}
            <span class="block font-normal text-muted-foreground">{{ day.slice(8) }}/{{ day.slice(5, 7) }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="template in board.templates" :key="template.id" class="border-b last:border-b-0">
          <th class="sticky left-0 z-10 bg-white px-3 py-2 text-left align-middle">
            <ShiftChip :color="template.color" :name="template.name" />
            <span class="mt-1 block text-xs font-normal tabular-nums text-muted-foreground">{{ template.startTime }}–{{ template.endTime }}</span>
          </th>
          <td v-for="day in board.days" :key="day" class="min-w-24 border-l align-middle">
            <RegisterCell
              :state="cellState(board, day, template)"
              :selected="selection.has(day, template.id)"
              @toggle="selection.toggle(day, template.id)"
              @cancel="emit('cancel', $event)"
            />
          </td>
        </tr>
      </tbody>
    </table>
  </div>
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
