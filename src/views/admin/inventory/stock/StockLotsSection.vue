<template>
  <section class="space-y-2">
    <div class="flex items-center justify-between gap-3">
      <h3 class="text-sm font-semibold">{{ $t("inventory.lots.title") }}</h3>
      <label class="flex items-center gap-2 text-xs text-muted-foreground">
        <Switch v-model:checked="showEmpty" />
        {{ $t("inventory.lots.showEmpty") }}
      </label>
    </div>
    <Skeleton v-if="lotsQuery.isPending.value" class="h-24 w-full" />
    <p v-else-if="lots.length === 0" class="rounded-lg border border-dashed p-4 text-center text-sm text-muted-foreground">
      {{ $t("inventory.lots.empty") }}
    </p>
    <div v-else class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
            <th class="py-2 font-semibold">{{ $t("inventory.lots.lotNo") }}</th>
            <th class="py-2 font-semibold">{{ $t("inventory.lots.expiry") }}</th>
            <th class="py-2 text-right font-semibold">{{ $t("inventory.lots.onHand") }}</th>
            <th class="py-2 text-right font-semibold">{{ $t("inventory.lots.unitCost") }}</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="(lot, index) in lots" :key="lot.id" class="border-b last:border-0">
            <td class="py-2">
              <span class="font-medium">{{ lot.lotNo || $t("inventory.lots.noLot") }}</span>
              <span
                v-if="index === firstSellableIndex"
                class="ml-2 rounded-full bg-primary/10 px-2 py-0.5 text-[10px] font-semibold text-primary"
              >
                {{ $t("inventory.lots.next") }}
              </span>
            </td>
            <td class="py-2">
              <template v-if="lot.expiryDate">
                {{ day(lot.expiryDate) }}
                <span class="ml-1 text-xs" :class="expiryTone(lot.expiryDate)">
                  {{ isExpired(lot.expiryDate) ? $t("inventory.lots.expired") : $t("inventory.stock.inDays", { n: daysUntil(lot.expiryDate) }) }}
                </span>
              </template>
              <span v-else class="text-muted-foreground">{{ $t("inventory.lots.noExpiry") }}</span>
            </td>
            <td class="py-2 text-right font-semibold">{{ qty(lot.qtyOnHand) }}</td>
            <td class="py-2 text-right text-muted-foreground">{{ money(lot.unitCost) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { useProductLots } from "@/queries/inventory";
import { isExpired } from "@/repositories/inventory";
import { money } from "@/views/admin/pos/format";
import { day, daysUntil, qty } from "../format";

const props = defineProps<{ branchId: string | undefined; productId: string; expiryDays: number }>();

const showEmpty = ref(false);
const lotsQuery = useProductLots(
  computed(() => props.branchId),
  computed(() => props.productId),
  showEmpty
);
const lots = computed(() => lotsQuery.data.value ?? []);

// The lot the next sale takes from: the first unexpired one holding stock (lots come FEFO-ordered).
const firstSellableIndex = computed(() =>
  lots.value.findIndex((lot) => lot.qtyOnHand > 0 && !isExpired(lot.expiryDate))
);

const expiryTone = (expiryDate: string): string => {
  if (isExpired(expiryDate)) return "font-semibold text-red-600";
  return daysUntil(expiryDate) < props.expiryDays ? "font-semibold text-amber-700" : "text-muted-foreground";
};
</script>
