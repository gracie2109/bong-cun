<template>
  <div class="overflow-x-auto">
    <table class="w-full text-sm">
      <thead>
        <tr class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
          <th class="py-2 font-semibold">{{ $t("pos.invoices.item") }}</th>
          <th class="py-2 text-right font-semibold">{{ $t("pos.invoices.qty") }}</th>
          <th class="py-2 text-right font-semibold">{{ $t("pos.invoices.amount") }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="line in lines" :key="line.id" class="border-b last:border-0">
          <td class="py-2">
            <p class="font-medium">{{ line.name }}</p>
            <p class="text-xs text-muted-foreground">
              {{ money(line.unitPrice) }}
              <template v-if="line.petName"> · {{ line.petName }}</template>
              <template v-if="line.weightKg"> · {{ line.weightKg }} kg</template>
            </p>
          </td>
          <td class="py-2 text-right">
            {{ line.qty }}
            <span v-if="returnedQty(line.id)" class="block text-[11px] text-red-600">
              {{ $t("pos.returns.returnedQty", { n: returnedQty(line.id) }) }}
            </span>
          </td>
          <td class="py-2 text-right font-medium">{{ money(line.amount) }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script lang="ts" setup>
import type { InvoiceLine } from "@/repositories/pos";
import { money } from "../format";

defineProps<{
  lines: InvoiceLine[];
  /** Quantity of a line already returned. */
  returnedQty: (lineId: string) => number;
}>();
</script>
