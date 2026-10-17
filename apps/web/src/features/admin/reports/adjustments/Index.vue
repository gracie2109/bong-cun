<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Undo2 class="size-4 text-primary" />
      {{ $t("reports.adjustments.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <ReportsNav />
      <ReportFilterBar>
        <template #actions>
          <ExportMenu :exporter="exporter" />
        </template>
      </ReportFilterBar>
      <div class="flex flex-wrap items-center gap-3 rounded-xl border bg-white p-3">
        <div class="flex gap-1 rounded-lg border p-0.5">
          <button
            v-for="item in KINDS"
            :key="item"
            type="button"
            class="rounded-md px-3 py-1 text-xs font-semibold transition-colors"
            :class="kind === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
            @click="kind = item"
          >
            {{ $t(`reports.adjustments.filter.${item}`) }}
          </button>
        </div>
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('reports.adjustments.searchPlaceholder')" />
        </div>
      </div>

      <PagedTableCard
        class="min-h-0 flex-1"
        v-model:page="page.pageIndex"
        v-model:page-size="page.pageSize"
        :page-count="pageCount"
        :count="rows.length"
        :total="total"
        :loading="listQuery.isFetching.value"
        scroll-x="1000px"
      >
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.kind") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.code") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.invoiceCode") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.time") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.items") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.amount") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.refundMethod") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.reason") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.by") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="9" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('reports.empty')" />
            <AdjustmentRow
              v-for="row in rows"
              :key="`${row.kind}-${row.id}`"
              :row="row"
              :can-open-invoice="canOpenInvoice"
              @open="open = { invoiceId: row.invoiceId, branchId: row.branchId }"
            />
          </tbody>
        </table>
      </PagedTableCard>
    </div>

    <InvoiceSheet :invoice-id="open?.invoiceId" :branch="openBranch" @close="open = undefined" />
  </ContentWrap>
</template>

<script lang="ts" setup>
import { computed, ref } from "vue";
import { Search, Undo2 } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Input } from "@/components/ui/input";
import { usePagedList } from "@/composables/usePagedList";
import { supabaseClient } from "@/lib/supabase";
import { useAdjustments } from "@/features/admin/reports/queries/reports";
import { EXPORT_LIMIT, listAdjustments, type AdjustmentKind } from "@bongcun/supabase/reports";
import { useAuthStore } from "@/stores";
import { ContentWrap, Header } from "@/features/admin/components";
import InvoiceSheet from "@/features/admin/pos/invoices/InvoiceSheet.vue";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ReportFilterBar from "../shared/ReportFilterBar.vue";
import { useReportExport } from "../shared/useReportExport";
import ReportsNav from "../ReportsNav.vue";
import AdjustmentRow from "./AdjustmentRow.vue";
import { adjustmentsCsvColumns } from "./adjustmentsCsv";
import { useAdjustmentFilters } from "./useAdjustmentFilters";

const KINDS: AdjustmentKind[] = ["all", "return", "cancel"];

const { t } = useI18n();
const auth = useAuthStore();
const { branches, kind, search, page, filter } = useAdjustmentFilters();

const listQuery = useAdjustments(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

// The invoice sheet is the POS one, so opening it needs "pos: VIEW".
const canOpenInvoice = computed(() => auth.can("pos", "VIEW"));
const open = ref<{ invoiceId: string; branchId: string }>();
const openBranch = computed(() => branches.value.find((branch) => branch.id === open.value?.branchId) ?? null);

const exporter = useReportExport({
  tab: "hoan-tra-huy",
  titleKey: "reports.adjustments.title",
  filter,
  fetchRows: (current) => listAdjustments(supabaseClient(), { pageIndex: 1, pageSize: EXPORT_LIMIT }, current),
  columns: () => adjustmentsCsvColumns(t),
});
</script>
