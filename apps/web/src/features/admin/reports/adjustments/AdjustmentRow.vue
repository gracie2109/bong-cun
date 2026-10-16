<template>
  <tr class="border-t">
    <td class="px-4 py-3">
      <span
        class="rounded-full px-2 py-0.5 text-[11px] font-semibold"
        :class="row.kind === 'return' ? 'bg-amber-50 text-amber-700' : 'bg-red-50 text-red-600'"
      >
        {{ $t(`reports.adjustments.kinds.${row.kind}`) }}
      </span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 font-semibold">{{ row.code }}</td>
    <td class="whitespace-nowrap px-4 py-3">
      <button v-if="canOpenInvoice" type="button" class="font-semibold text-primary hover:underline" @click="emit('open')">
        {{ row.invoiceCode }}
      </button>
      <span v-else>{{ row.invoiceCode }}</span>
    </td>
    <td class="whitespace-nowrap px-4 py-3">{{ dateTime(row.at) }}</td>
    <td class="max-w-64 truncate px-4 py-3" :title="row.itemSummary ?? ''">{{ row.itemSummary ?? "—" }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ money(row.amount) }}</td>
    <td class="px-4 py-3">{{ row.method ? $t(`reports.method.${row.method}`) : "—" }}</td>
    <td class="max-w-56 truncate px-4 py-3" :title="row.reason ?? ''">{{ row.reason ?? "—" }}</td>
    <td class="px-4 py-3">{{ row.byName ?? "—" }}</td>
  </tr>
</template>

<script lang="ts" setup>
import type { Adjustment } from "@bongcun/supabase/reports";
import { dateTime } from "@/features/admin/pos/format";
import { money } from "../shared/format";

defineProps<{ row: Adjustment; canOpenInvoice: boolean }>();
const emit = defineEmits<{ open: [] }>();
</script>
