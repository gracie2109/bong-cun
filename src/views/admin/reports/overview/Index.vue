<template>
  <Header>
    <h1 class="flex items-center gap-2 font-semibold">
      <ChartColumn class="size-4 text-primary" />
      {{ $t("reports.title") }}
    </h1>
  </Header>

  <ContentWrap>
    <div class="space-y-5">
      <ReportsNav />
      <ReportFilterBar>
        <template #actions>
          <ExportMenu :exporter="exporter" />
        </template>
      </ReportFilterBar>

      <p v-if="ready && !branchValue" class="rounded-xl border bg-white px-4 py-10 text-center text-sm text-muted-foreground">
        {{ $t("reports.noBranch") }}
      </p>
      <template v-else-if="filter">
        <OverviewKpis v-if="overview" :data="overview" />
        <p v-else-if="overviewPending" class="rounded-xl border bg-white px-4 py-10 text-center text-sm text-muted-foreground">
          {{ $t("reports.loading") }}
        </p>
        <div class="grid gap-5 xl:grid-cols-[minmax(0,1fr)_22rem]">
          <RevenueChartCard v-model:bucket="bucket" :points="series" :loading="seriesPending" />
          <MixCard v-if="overview" :data="overview" />
        </div>
        <SeriesTable
          v-model:pagination="page"
          :rows="pageRows"
          :total="series.length"
          :page-count="pageCount"
          :totals="totals"
          :bucket="bucket"
          :loading="seriesPending"
        />
      </template>
    </div>
  </ContentWrap>
</template>

<script lang="ts" setup>
import { ChartColumn } from "lucide-vue-next";
import { ContentWrap, Header } from "@/views/admin/components";
import ExportMenu from "@/components/common/data-io/ExportMenu.vue";
import ReportFilterBar from "../shared/ReportFilterBar.vue";
import ReportsNav from "../ReportsNav.vue";
import MixCard from "./MixCard.vue";
import OverviewKpis from "./OverviewKpis.vue";
import RevenueChartCard from "./RevenueChartCard.vue";
import SeriesTable from "./SeriesTable.vue";
import { useOverview } from "./useOverview";

const {
  ready,
  branchValue,
  filter,
  bucket,
  overview,
  overviewPending,
  seriesPending,
  series,
  totals,
  page,
  pageCount,
  pageRows,
  exporter,
} = useOverview();
</script>
