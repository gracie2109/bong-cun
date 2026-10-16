<template>
  <tr class="border-t">
    <td class="whitespace-nowrap px-4 py-3">
      <span class="font-semibold">{{ row.code }}</span>
      <span v-if="row.status === 'open'" class="ml-2 rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-semibold text-primary">
        {{ $t("reports.shifts.open") }}
      </span>
    </td>
    <td class="px-4 py-3">{{ row.openedByName ?? "—" }}</td>
    <td class="whitespace-nowrap px-4 py-3">{{ dateTime(row.openedAt) }}</td>
    <td class="whitespace-nowrap px-4 py-3">{{ row.closedAt ? dateTime(row.closedAt) : "—" }}</td>
    <td class="px-4 py-3 text-right">{{ row.invoiceCount }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ money(row.salesTotal) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ row.expectedCash === null ? "—" : money(row.expectedCash) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ row.countedCash === null ? "—" : money(row.countedCash) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold" :class="differenceClass(row.difference)">
      {{ row.difference === null ? "—" : signedMoney(row.difference) }}
    </td>
  </tr>
</template>

<script lang="ts" setup>
import type { ShiftRecon } from "@bongcun/supabase/reports";
import { dateTime } from "@/views/admin/pos/format";
import { money } from "../shared/format";
import { differenceClass } from "./differenceClass";

defineProps<{ row: ShiftRecon }>();

const signedMoney = (value: number): string => (value > 0 ? `+${money(value)}` : money(value));
</script>
