<template>
  <Sheet :open="!!row" @update:open="(open) => !open && emit('close')">
    <SheetContent side="right" class="flex w-full flex-col gap-0 p-0 sm:max-w-2xl">
      <SheetHeader class="border-b px-6 py-4">
        <SheetTitle>{{ row?.name }}</SheetTitle>
        <SheetDescription>{{ row ? [row.sku, row.unit].filter(Boolean).join(" · ") : "" }}</SheetDescription>
      </SheetHeader>

      <div v-if="row" class="flex-1 space-y-6 overflow-y-auto px-6 py-5">
        <StockSummaryCards :row="row" :expiry-days="expiryDays" />
        <MinStockForm :row="row" :branch-id="branchId" />
        <StockLotsSection :branch-id="branchId" :product-id="row.productId" :expiry-days="expiryDays" />
        <StockMovementsSection :branch-id="branchId" :product-id="row.productId" />
      </div>
    </SheetContent>
  </Sheet>
</template>

<script lang="ts" setup>
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import type { StockRow } from "@/repositories/inventory";
import MinStockForm from "./MinStockForm.vue";
import StockLotsSection from "./StockLotsSection.vue";
import StockMovementsSection from "./StockMovementsSection.vue";
import StockSummaryCards from "./StockSummaryCards.vue";

defineProps<{ row: StockRow | null; branchId: string | undefined; expiryDays: number }>();
const emit = defineEmits<{ close: [] }>();
</script>
