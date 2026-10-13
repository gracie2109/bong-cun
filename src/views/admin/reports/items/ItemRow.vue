<template>
  <tr class="border-t">
    <td class="px-4 py-3 text-muted-foreground">{{ rank }}</td>
    <td class="px-4 py-3">
      <span class="font-semibold">{{ item.name }}</span>
      <span v-if="item.sku" class="block text-xs text-muted-foreground">{{ item.sku }}</span>
    </td>
    <td class="px-4 py-3">
      <span class="rounded-full bg-muted px-2 py-0.5 text-[11px] font-semibold">{{ $t(`reports.itemType.${item.itemType}`) }}</span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ item.qtySold }}<span v-if="item.unit" class="text-xs text-muted-foreground"> {{ item.unit }}</span></td>
    <td class="px-4 py-3 text-right" :class="item.qtyReturned ? 'text-red-600' : 'text-muted-foreground'">{{ item.qtyReturned || "—" }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold">{{ money(item.netRevenue) }}</td>
    <td class="px-4 py-3">
      <div class="ml-auto flex w-28 items-center gap-2">
        <div class="h-1.5 flex-1 overflow-hidden rounded-full bg-muted">
          <div class="h-full rounded-full bg-primary" :style="{ width: `${Math.min(item.share, 100)}%` }" />
        </div>
        <span class="w-10 text-right text-xs text-muted-foreground">{{ percent(item.share) }}</span>
      </div>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ item.cost === null ? "—" : money(item.cost) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right font-semibold" :class="profitClass">
      {{ item.grossProfit === null ? "—" : money(item.grossProfit) }}
    </td>
    <td class="px-4 py-3 text-right text-muted-foreground">{{ margin }}</td>
  </tr>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { TopItem } from "@/repositories/reports";
import { money, percent } from "../shared/format";

const props = defineProps<{ item: TopItem; rank: number }>();

const profitClass = computed(() => ((props.item.grossProfit ?? 0) < 0 ? "text-red-600" : ""));
// Margin on revenue after refunds; services have no cost, so no margin.
const margin = computed(() => {
  const { grossProfit, netRevenue, refunds } = props.item;
  const base = netRevenue - refunds;
  return grossProfit === null || base <= 0 ? "—" : percent((grossProfit / base) * 100);
});
</script>
