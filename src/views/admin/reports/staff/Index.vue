<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Users class="size-4 text-primary" />
      {{ $t("reports.staff.title") }}
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
        <StaffTabs v-model:role="role" />
        <div class="relative min-w-60 flex-1">
          <Search class="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input v-model="search" class="pl-9" :placeholder="$t('reports.staff.searchPlaceholder')" />
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
        scroll-x="700px"
      >
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-[11px] uppercase tracking-wide text-muted-foreground">
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.staff") }}</th>
              <template v-if="role === 'cashier'">
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.invoices") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.netSales") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.refunds") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.cancelled") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.avgTicket") }}</th>
              </template>
              <template v-else>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.tickets") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.pets") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.serviceRevenue") }}</th>
                <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.share") }}</th>
              </template>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :colspan="6" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('reports.empty')" />
            <template v-for="row in rows" :key="row.staffId ?? 'unassigned'">
              <CashierRow v-if="role === 'cashier'" :row="row" />
              <SpaStaffRow v-else :row="row" />
            </template>
          </tbody>
        </table>
      </PagedTableCard>
      <p class="text-xs text-muted-foreground">{{ $t(`reports.staff.note.${role}`) }}</p>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { Search, Users } from "lucide-vue-next";
import { useI18n } from "vue-i18n";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { Input } from "@/components/ui/input";
import { usePagedList } from "@/composables/usePagedList";
import { supabaseClient } from "@/lib/supabase";
import { useStaffRevenue } from "@/queries/reports";
import { EXPORT_LIMIT, listStaffRevenue } from "@/repositories/reports";
import { ContentWrap, Header } from "@/views/admin/components";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ReportFilterBar from "../shared/ReportFilterBar.vue";
import { useReportExport } from "../shared/useReportExport";
import ReportsNav from "../ReportsNav.vue";
import CashierRow from "./CashierRow.vue";
import SpaStaffRow from "./SpaStaffRow.vue";
import StaffTabs from "./StaffTabs.vue";
import { staffCsvColumns } from "./staffCsv";
import { useStaffFilters } from "./useStaffFilters";

const { t } = useI18n();
const { role, search, page, filter } = useStaffFilters();

const listQuery = useStaffRevenue(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);

const exporter = useReportExport({
  tab: "nhan-vien",
  titleKey: "reports.staff.title",
  filter,
  fetchRows: (current) => listStaffRevenue(supabaseClient(), { pageIndex: 1, pageSize: EXPORT_LIMIT }, current),
  columns: () => staffCsvColumns(role.value, t),
});
</script>
