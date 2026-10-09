<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Receipt class="size-4 text-primary" />
      {{ $t("pos.invoices.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <PosNav />
        <BranchPicker :model-value="branchId" :branches="branches" @update:model-value="selectBranch" />
      </div>

      <InvoicesFilterBar v-model:search="search" v-model:period="period" v-model:status="status" />

      <PagedTableCard v-model:page="page.pageIndex" v-model:page-size="page.pageSize" :page-count="pageCount" :count="rows.length" :total="total">
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.time") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("pos.receipt.customer") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("pos.receipt.cashier") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("pos.total") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("pos.invoices.status") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="6" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('pos.invoices.empty')" />
            <InvoiceRow v-for="row in rows" :key="row.id" :invoice="row" @open="openId = row.id" />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <InvoiceSheet :invoice-id="openId" :branch="branch" @close="openId = undefined" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ref } from "vue";
import { Receipt } from "lucide-vue-next";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { usePagedList } from "@/composables/usePagedList";
import { useInvoicesList } from "@/queries/pos";
import { ContentWrap, Header } from "@/views/admin/components";
import BranchPicker from "../components/BranchPicker.vue";
import PosNav from "../PosNav.vue";
import InvoiceRow from "./InvoiceRow.vue";
import InvoiceSheet from "./InvoiceSheet.vue";
import InvoicesFilterBar from "./InvoicesFilterBar.vue";
import { useInvoicesFilters } from "./useInvoicesFilters";

const { branches, branch, branchId, selectBranch } = useCurrentBranch();
const { search, period, status, page, filter } = useInvoicesFilters(branchId);
const openId = ref<string>();

const listQuery = useInvoicesList(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
</script>
