<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Scale class="size-4 text-primary" />
      {{ $t("reports.shifts.title") }}
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
            v-for="item in STATUSES"
            :key="item"
            type="button"
            class="rounded-md px-3 py-1 text-xs font-semibold transition-colors"
            :class="status === item ? 'bg-primary text-primary-foreground' : 'text-muted-foreground hover:bg-muted'"
            @click="status = item"
          >
            {{ $t(`reports.shifts.filter.${item}`) }}
          </button>
        </div>
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('reports.shifts.searchPlaceholder')" />
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
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.shiftCode") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.cashier") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.openedAt") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.closedAt") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.invoices") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.sales") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.expectedCash") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.countedCash") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.difference") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="9" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('reports.empty')" />
            <ShiftReconRow v-for="row in rows" :key="row.id" :row="row" />
          </tbody>
        </table>
      </PagedTableCard>
      <p class="text-xs text-muted-foreground">{{ $t("reports.shifts.note") }}</p>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { Scale, Search } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Input } from "@/components/ui/input";
import { usePagedList } from "@/composables/usePagedList";
import { supabaseClient } from "@/lib/supabase";
import { useShiftRecon } from "@/queries/reports";
import { EXPORT_LIMIT, listShiftRecon, type ShiftStatusFilter } from "@/repositories/reports";
import { ContentWrap, Header } from "@/views/admin/components";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ReportFilterBar from "../shared/ReportFilterBar.vue";
import { useReportExport } from "../shared/useReportExport";
import ReportsNav from "../ReportsNav.vue";
import ShiftReconRow from "./ShiftReconRow.vue";
import { shiftsCsvColumns } from "./shiftsCsv";
import { useShiftReconFilters } from "./useShiftReconFilters";

const STATUSES: ShiftStatusFilter[] = ["all", "open", "closed", "mismatch"];

const { t } = useI18n();
const { status, search, page, filter } = useShiftReconFilters();

const listQuery = useShiftRecon(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

const exporter = useReportExport({
  tab: "doi-chieu-ca",
  titleKey: "reports.shifts.title",
  filter,
  fetchRows: (current) => listShiftRecon(supabaseClient(), { pageIndex: 1, pageSize: EXPORT_LIMIT }, current),
  columns: () => shiftsCsvColumns(t),
});
</script>
