<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Boxes class="size-4 text-primary" />
      {{ $t("inventory.stock.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <InventoryNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <StockAlertCards v-model:status="status" :alerts="alerts" :expiry-days="expiryDays" />

      <StockFilterBar v-model:search="search" v-model:status="status" v-model:expiry-window="expiryWindow" />

      <PagedTableCard v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("products.col.product") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.sellable") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.expired") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("inventory.stock.nextExpiry") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.min") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("inventory.stock.value") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="6" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('inventory.stock.empty')" />
            <StockRow v-for="row in rows" :key="row.productId" :row="row" :expiry-days="expiryDays" @open="openRow = row" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <StockProductSheet :row="openRow" :branch-id="branchId" :expiry-days="expiryDays" @close="openRow = null" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref, watch } from "vue";
import { Boxes } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { usePagedList } from "@/composables/usePagedList";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useStockAlertCounts, useStockSummary } from "@/queries/inventory";
import type { StockRow as StockRowData } from "@/repositories/inventory";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "@/views/admin/pos/components/BranchPicker.vue";
import InventoryNav from "../InventoryNav.vue";
import StockAlertCards from "./StockAlertCards.vue";
import StockFilterBar from "./StockFilterBar.vue";
import StockProductSheet from "./StockProductSheet.vue";
import StockRow from "./StockRow.vue";
import { useStockFilters } from "./useStockFilters";

const { branches, branchId, selectBranch } = useCurrentBranch();
const { search, status, expiryWindow, expiryDays, page, filter } = useStockFilters(branchId);

const openRow = ref<StockRowData | null>(null);

const listQuery = useStockSummary(page, filter);
const alertsQuery = useStockAlertCounts(branchId, expiryDays);
const alerts = computed(() => alertsQuery.data.value);
const { rows, total, pageCount } = usePagedList(listQuery, page);

// Keep the open sheet in step with the list after a change (minimum stock, a receipt...).
watch(rows, (list) => {
  if (openRow.value) openRow.value = list.find((row) => row.productId === openRow.value?.productId) ?? openRow.value;
});
</script>
