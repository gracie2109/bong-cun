import { computed, reactive, ref, watch } from "vue";
import { useI18n } from "vue-i18n";
import { supabaseClient } from "@/lib/supabase";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { useReportOverview, useRevenueSeries } from "@/features/admin/reports/queries/reports";
import { getRevenueSeries, type Bucket, type SeriesPoint } from "@bongcun/supabase/reports";
import { useReportExport } from "../shared/useReportExport";
import { useReportFilters } from "../shared/useReportFilters";
import { seriesCsvColumns } from "./seriesCsv";
import { sumSeries } from "./seriesTotals";

const TABLE_PAGE_SIZE = 20;

/** Data of the overview tab: KPI figures, the revenue series, the paged table and the export. */
export const useOverview = () => {
  const { t } = useI18n();
  const { filter, ready, branchValue } = useReportFilters();
  const bucket = ref<Bucket>("day");

  const overviewQuery = useReportOverview(filter);
  const seriesQuery = useRevenueSeries(filter, bucket);

  const series = computed<SeriesPoint[]>(() => seriesQuery.data.value ?? []);
  const totals = computed(() => sumSeries(series.value));

  // The table under the chart pages in the browser: the chart needs the whole series.
  const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize: TABLE_PAGE_SIZE });
  watch([filter, bucket], () => (page.pageIndex = INITIAL_PAGE_INDEX));
  const pageCount = computed(() => Math.max(1, Math.ceil(series.value.length / page.pageSize)));
  const pageRows = computed(() => {
    const start = (page.pageIndex - 1) * page.pageSize;
    return series.value.slice(start, start + page.pageSize);
  });

  const exportDay = useReportExport<SeriesPoint>({
    tab: "tong-quan",
    titleKey: "reports.chart.title",
    filter,
    fetchRows: async (current) => {
      const rows = await getRevenueSeries(supabaseClient(), current, "day");
      return { rows, total: rows.length };
    },
    columns: () => seriesCsvColumns(t),
  });

  return {
    ready,
    branchValue,
    filter,
    bucket,
    overview: computed(() => overviewQuery.data.value),
    overviewPending: overviewQuery.isPending,
    seriesPending: seriesQuery.isPending,
    series,
    totals,
    page,
    pageCount,
    pageRows,
    exporter: exportDay,
  };
};
