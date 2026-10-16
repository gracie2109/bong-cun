<template>
  <tr class="border-t">
    <td class="px-4 py-3 font-semibold">{{ row.name ?? "—" }}</td>
    <td class="px-4 py-3 text-right">{{ row.invoiceCount }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ money(row.netSales) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right" :class="row.refunds ? 'text-red-600' : 'text-muted-foreground'">
      {{ row.refunds ? money(row.refunds) : "—" }}
    </td>
    <td class="px-4 py-3 text-right" :class="row.cancelledCount ? 'text-amber-600' : 'text-muted-foreground'">{{ row.cancelledCount || "—" }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ money(row.avgTicket) }}</td>
  </tr>
</template>

<script lang="ts" setup>
import type { StaffRevenue } from "@/repositories/reports";
import { money } from "../shared/format";

defineProps<{ row: StaffRevenue }>();
</script>
