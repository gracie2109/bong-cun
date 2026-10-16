<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <Package class="size-4 text-primary" />
      {{ $t("reports.items.title") }}
    </h1>
  </Header>

  <ContentWrap fill>
    <div class="flex min-h-0 flex-1 flex-col gap-5">
      <ReportsNav />
      <ReportFilterBar />
      <SearchView
        v-model:search="search"
        :placeholder="$t('reports.items.searchPlaceholder')"
        :active-count="activeCount"
        :refreshing="listQuery.isFetching.value"
        @open-filters="syncDraft"
        @apply="apply"
        @reset-filters="resetDraft"
        @clear="clearAll"
        @refresh="listQuery.refetch()"
      >
        <template #quick><ItemsKindSwitch v-model="kind" /></template>
        <template #filters><ItemsFilterFields v-model="draft.sort" /></template>
        <template #actions><ExportMenu :exporter="exporter" compact /></template>
      </SearchView>

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
              <th class="px-4 py-3 font-semibold">#</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.name") }}</th>
              <th class="px-4 py-3 font-semibold">{{ $t("reports.cols.type") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.qtySold") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.qtyReturned") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.itemRevenue") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.share") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.cost") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.profit") }}</th>
              <th class="px-4 py-3 text-right font-semibold">{{ $t("reports.cols.margin") }}</th>
            </tr>
          </thead>
          <tbody>
            <TableStateRows :filtered="isFiltered" @clear="clearAll" :colspan="10" :pending="listQuery.isPending.value" :empty="rows.length === 0" :empty-text="$t('reports.empty')" />
            <ItemRow v-for="(row, index) in rows" :key="`${row.itemType}-${row.itemId}`" :item="row" :rank="rankOf(index)" />
          </tbody>
        </table>
      </PagedTableCard>
      <p class="text-xs text-muted-foreground">{{ $t("reports.items.note") }}</p>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { Package } from "lucide-vue-next";
import { SearchView } from "@/components/common/search-view";
import PagedTableCard from "@/components/common/PagedTableCard.vue";
import TableStateRows from "@/components/common/TableStateRows.vue";
import { usePagedList } from "@/composables/usePagedList";
import { supabaseClient } from "@/lib/supabase";
import { useI18n } from "vue-i18n";
import { useTopItems } from "@/queries/reports";
import { EXPORT_LIMIT, listTopItems } from "@/repositories/reports";
import { ContentWrap, Header } from "@/views/admin/components";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ReportFilterBar from "../shared/ReportFilterBar.vue";
import { useReportExport } from "../shared/useReportExport";
import ReportsNav from "../ReportsNav.vue";
import ItemRow from "./ItemRow.vue";
import { itemsCsvColumns } from "./itemsCsv";
import ItemsFilterFields from "./ItemsFilterFields.vue";
import ItemsKindSwitch from "./ItemsKindSwitch.vue";
import { useItemsFilters } from "./useItemsFilters";

const { t } = useI18n();
const { kind, search, page, filter, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft } = useItemsFilters();

const listQuery = useTopItems(page, filter);
const { rows, total, pageCount } = usePagedList(listQuery, page);
const rankOf = (index: number) => (page.pageIndex - 1) * page.pageSize + index + 1;

const exporter = useReportExport({
  tab: "san-pham-dich-vu",
  titleKey: "reports.items.title",
  filter,
  fetchRows: (current) => listTopItems(supabaseClient(), { pageIndex: 1, pageSize: EXPORT_LIMIT }, current),
  columns: () => itemsCsvColumns(t),
});
</script>
