<template>
  <Sheet :open="!!row" @update:open="(open) => !open && emit('close')">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-2xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ row?.name }}</SheetTitle>
        <SheetDescription>{{ row ? [row.sku, row.unit].filter(Boolean).join(" · ") : "" }}</SheetDescription>
      </SheetHeader>

      <div v-if="row" class="flex-1 space-y-6 overflow-y-auto px-6 py-5">
        <dl class="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <div class="rounded-xl bg-muted/50 p-3">
            <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.sellable") }}</dt>
            <dd class="text-lg font-bold">{{ qty(row.sellable) }}</dd>
          </div>
          <div class="rounded-xl bg-muted/50 p-3">
            <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.expired") }}</dt>
            <dd class="text-lg font-bold" :class="row.expired > 0 ? 'text-red-600' : ''">{{ qty(row.expired) }}</dd>
          </div>
          <div class="rounded-xl bg-muted/50 p-3">
            <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.expiringShort", { days: expiryDays }) }}</dt>
            <dd class="text-lg font-bold" :class="row.expiring > 0 ? 'text-amber-700' : ''">{{ qty(row.expiring) }}</dd>
          </div>
          <div class="rounded-xl bg-muted/50 p-3">
            <dt class="text-xs text-muted-foreground">{{ $t("inventory.stock.value") }}</dt>
            <dd class="text-lg font-bold">{{ money(row.stockValue) }}</dd>
          </div>
        </dl>

        <form class="flex flex-wrap items-end gap-3" @submit.prevent="saveMin">
          <div class="space-y-2">
            <Label for="min-qty">{{ $t("inventory.stock.minLabel") }}</Label>
            <Input id="min-qty" v-model="minText" class="w-40" inputmode="decimal" :disabled="!canUpdate" placeholder="0" />
          </div>
          <Button v-if="canUpdate" type="submit" variant="outline" :disabled="!minChanged || minMutation.isPending.value">
            {{ $t("petCare.common.save") }}
          </Button>
          <p class="basis-full text-xs text-muted-foreground">{{ $t("inventory.stock.minHint") }}</p>
        </form>

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
          <table v-else class="w-full text-sm">
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
                    <span
                      class="ml-1 text-xs"
                      :class="isExpired(lot.expiryDate) ? 'font-semibold text-red-600' : daysUntil(lot.expiryDate) < expiryDays ? 'font-semibold text-amber-700' : 'text-muted-foreground'"
                    >
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
        </section>

        <section class="space-y-2">
          <h3 class="text-sm font-semibold">{{ $t("inventory.movements.title") }}</h3>
          <Skeleton v-if="movementsQuery.isPending.value" class="h-24 w-full" />
          <p v-else-if="movements.length === 0" class="rounded-lg border border-dashed p-4 text-center text-sm text-muted-foreground">
            {{ $t("inventory.movements.empty") }}
          </p>
          <table v-else class="w-full text-sm">
            <thead>
              <tr class="border-b text-left text-[11px] uppercase tracking-wide text-muted-foreground">
                <th class="py-2 font-semibold">{{ $t("pos.invoices.time") }}</th>
                <th class="py-2 font-semibold">{{ $t("inventory.movements.reason") }}</th>
                <th class="py-2 font-semibold">{{ $t("inventory.lots.lotNo") }}</th>
                <th class="py-2 text-right font-semibold">{{ $t("inventory.movements.qty") }}</th>
                <th class="py-2 text-right font-semibold">{{ $t("inventory.movements.balance") }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="move in movements" :key="move.id" class="border-b last:border-0">
                <td class="whitespace-nowrap py-2 text-xs">{{ dateTime(move.createdAt) }}</td>
                <td class="py-2">
                  {{ $t(`inventory.movements.reasons.${move.reason}`) }}
                  <span v-if="move.ref" class="block text-xs text-muted-foreground">{{ move.ref }}</span>
                </td>
                <td class="py-2 text-xs">
                  {{ move.lotNo || $t("inventory.lots.noLot") }}
                  <span v-if="move.expiryDate" class="block text-muted-foreground">{{ day(move.expiryDate) }}</span>
                </td>
                <td class="py-2 text-right font-semibold" :class="move.qty > 0 ? 'text-primary' : 'text-red-600'">
                  {{ move.qty > 0 ? "+" : "" }}{{ qty(move.qty) }}
                </td>
                <td class="py-2 text-right text-muted-foreground">{{ qty(move.balanceAfter) }}</td>
              </tr>
            </tbody>
          </table>
        </section>
      </div>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import { usePermission } from "@/composables/usePermission";
import { useProductLots, useProductMovements, useSetMinStock } from "@/queries/inventory";
import { isExpired, type StockRow } from "@/repositories/inventory";
import { dateTime, money } from "@/views/admin/pos/format";
import { day, daysUntil, parseQty, qty } from "../format";

const props = defineProps<{ row: StockRow | null; branchId: string | undefined; expiryDays: number }>();
const emit = defineEmits<{ close: [] }>();

const { canUpdate } = usePermission("inventory");
const productId = computed(() => props.row?.productId);
const branchId = computed(() => props.branchId);
const showEmpty = ref(false);
const lotsQuery = useProductLots(branchId, productId, showEmpty);
const movementsQuery = useProductMovements(branchId, productId);
const lots = computed(() => lotsQuery.data.value ?? []);
const movements = computed(() => movementsQuery.data.value ?? []);
const minMutation = useSetMinStock();
const minText = ref("");

// The lot the next sale takes from: the first unexpired one holding stock (lots come FEFO-ordered).
const firstSellableIndex = computed(() =>
  lots.value.findIndex((lot) => lot.qtyOnHand > 0 && !isExpired(lot.expiryDate))
);

watch(
  () => [props.row?.productId, props.row?.minQty] as const,
  () => {
    minText.value = props.row?.minQty ? String(props.row.minQty) : "";
  },
  { immediate: true }
);

const minValue = computed(() => {
  const value = parseQty(minText.value);
  return Number.isFinite(value) && value > 0 ? value : null;
});
const minChanged = computed(() => minValue.value !== (props.row?.minQty ?? null));

const saveMin = async () => {
  if (!props.row || !props.branchId) return;
  try {
    await minMutation.mutateAsync({ branchId: props.branchId, productId: props.row.productId, minQty: minValue.value });
  } catch {
    // the mutation already showed the failure toast
  }
};
</script>
