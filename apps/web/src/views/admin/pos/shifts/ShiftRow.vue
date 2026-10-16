<template>
  <tr class="border-t">
    <td class="whitespace-nowrap px-4 py-3 font-semibold">
      {{ shift.code }}
      <span
        v-if="shift.status === 'open'"
        class="ml-1 rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-semibold text-primary"
      >
        {{ $t("pos.shifts.open") }}
      </span>
    </td>
    <td class="px-4 py-3">{{ shift.openedByName }}</td>
    <td class="whitespace-nowrap px-4 py-3">{{ dateTime(shift.openedAt) }}</td>
    <td class="whitespace-nowrap px-4 py-3">
      {{ dateTime(shift.closedAt) }}
      <span v-if="shift.closedByName && shift.closedByName !== shift.openedByName" class="block text-xs text-muted-foreground">
        {{ shift.closedByName }}
      </span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ money(shift.openingCash) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ shift.expectedCash === null ? "—" : money(shift.expectedCash) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ shift.countedCash === null ? "—" : money(shift.countedCash) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold" :class="cashDifferenceClass(shift)">
      {{ cashDifference(shift) === null ? "—" : money(cashDifference(shift)) }}
    </td>
    <td class="px-4 py-3 text-right">
      <Button v-if="shift.status === 'open' && canClose" size="sm" variant="outline" @click="emit('close')">
        {{ $t("pos.shift.close") }}
      </Button>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import { Button } from "@/components/ui/button";
import type { CashShift } from "@/repositories/pos";
import { dateTime, money } from "../format";
import { cashDifference, cashDifferenceClass } from "./shiftCash";

defineProps<{ shift: CashShift; canClose: boolean }>();

const emit = defineEmits<{ close: [] }>();
</script>
