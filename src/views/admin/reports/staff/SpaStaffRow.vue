<template>
  <tr class="border-t">
    <td class="px-4 py-3 font-semibold" :class="row.staffId ? '' : 'italic text-muted-foreground'">
      {{ row.staffId ? (row.name ?? "—") : $t("reports.staff.unassigned") }}
    </td>
    <td class="px-4 py-3 text-right">{{ row.ticketCount }}</td>
    <td class="px-4 py-3 text-right">{{ row.petCount || "—" }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ money(row.netSales) }}</td>
    <td class="px-4 py-3">
      <div class="ml-auto flex w-28 items-center gap-2">
        <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-muted">
          <div class="h-full rounded-full bg-primary" :style="{ width: `${Math.min(row.share, 100)}%` }" />
        </div>
        <span class="w-10 text-right text-xs text-muted-foreground">{{ percent(row.share) }}</span>
      </div>
    </td>
  </tr>
</template>

<script lang="ts" setup>
import type { StaffRevenue } from "@/repositories/reports";
import { money, percent } from "../shared/format";

defineProps<{ row: StaffRevenue }>();
</script>
