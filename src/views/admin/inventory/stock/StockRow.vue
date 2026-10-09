<template>
  <tr
    class="cursor-pointer border-t hover:bg-muted/40"
    :class="row.isActive ? '' : 'opacity-60'"
    @click="emit('open')"
  >
    <td class="px-4 py-3">
      <p class="font-semibold">{{ row.name }}</p>
      <p class="text-xs text-muted-foreground">{{ [row.sku, row.unit].filter(Boolean).join(" · ") }}</p>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right">
      <span class="font-semibold" :class="sellableTone">{{ qty(row.sellable) }}</span>
      <span v-if="isLow" class="ml-2 rounded-full bg-amber-50 px-2 py-0.5 text-[10px] font-semibold text-amber-700">
        {{ $t("inventory.stock.status.low") }}
      </span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right" :class="row.expired > 0 ? 'font-semibold text-red-600' : 'text-muted-foreground'">
      {{ row.expired > 0 ? qty(row.expired) : "—" }}
    </td>
    <td class="whitespace-nowrap px-4 py-3">
      <template v-if="row.nextExpiry">
        {{ day(row.nextExpiry) }}
        <span
          class="ml-1 text-xs"
          :class="daysUntil(row.nextExpiry) < expiryDays ? 'font-semibold text-amber-700' : 'text-muted-foreground'"
        >
          {{ $t("inventory.stock.inDays", { n: daysUntil(row.nextExpiry) }) }}
        </span>
      </template>
      <span v-else class="text-muted-foreground">—</span>
    </td>
    <td class="whitespace-nowrap px-4 py-3 text-right text-muted-foreground">{{ row.minQty === null ? "—" : qty(row.minQty) }}</td>
    <td class="whitespace-nowrap px-4 py-3 text-right">{{ money(row.stockValue) }}</td>
  </tr>
</template>

<script lang="ts" setup>
import { computed } from "vue";
import type { StockRow } from "@/repositories/inventory";
import { money } from "@/views/admin/pos/format";
import { day, daysUntil, qty } from "../format";

const props = defineProps<{
  row: StockRow;
  /** Days ahead that count as "expiring". */
  expiryDays: number;
}>();

const emit = defineEmits<{ open: [] }>();

const isLow = computed(() => props.row.minQty !== null && props.row.sellable < props.row.minQty);
const sellableTone = computed(() => {
  if (props.row.sellable === 0) return "text-red-600";
  return isLow.value ? "text-amber-700" : "";
});
</script>
