import { computed } from "vue";
import type { Bucket, ReportFilter, ReportOverview, SeriesPoint, TopItem, TopItemFilter } from "@bongcun/supabase/reports";
import { bucketLabel, useReportOverview, useRevenueSeries, useTopItems } from "@/features/admin/reports";
import { bucketFor } from "../../range/widgetRange";
import type { SourceContext, SourceResult } from "./context";

/** A report filter for the active report source, or null (query off) while it may not be read. */
const reportFilter = (ctx: SourceContext, source: Parameters<SourceContext["isActive"]>[0]) =>
  computed<ReportFilter | null>(() => {
    if (!ctx.isActive(source) || (!ctx.isAll.value && !ctx.branchId.value)) return null;
    return { branchId: ctx.isAll.value ? null : (ctx.branchId.value as string), ...ctx.range.value };
  });

/** Net revenue of one line of business, or of everything. */
const segmentAmount = (overview: ReportOverview, segment: unknown): number => {
  if (segment === "shop" || segment === "spa" || segment === "boarding" || segment === "medical") return overview.segments[segment];
  return overview.netRevenue;
};

const OVERVIEW_PICKS: Record<string, (overview: ReportOverview, segment: unknown) => { value: number; previous?: number }> = {
  net: (o, segment) => ({ value: segmentAmount(o, segment), previous: segment === "all" || segment === undefined ? o.previous.netRevenue : undefined }),
  invoiceCount: (o) => ({ value: o.invoiceCount, previous: o.previous.invoiceCount }),
  avgTicket: (o) => ({ value: o.avgTicket, previous: o.previous.avgTicket }),
  refunds: (o) => ({ value: o.refunds, previous: o.previous.refunds }),
  pendingCod: (o) => ({ value: o.pendingCod.amount }),
  grossProfit: (o) => ({ value: o.grossProfit }),
};

export const useOverviewSource = (ctx: SourceContext): SourceResult => {
  const query = useReportOverview(reportFilter(ctx, "overview"));
  const value = computed(() => {
    const overview = query.data.value;
    const pick = OVERVIEW_PICKS[ctx.def.pick];
    return overview && pick ? ({ kind: "number", ...pick(overview, ctx.params.value.segment) } as const) : null;
  });
  return { query, value };
};

const seriesValue = (point: SeriesPoint, segment: unknown): number =>
  segment === "shop" || segment === "spa" || segment === "boarding" || segment === "medical" ? point[segment] : point.netRevenue;

export const useSeriesSource = (ctx: SourceContext): SourceResult => {
  const bucket = computed<Bucket>(() => bucketFor(ctx.range.value));
  const query = useRevenueSeries(reportFilter(ctx, "series"), bucket);
  const value = computed(() =>
    query.data.value
      ? ({
          kind: "series",
          points: query.data.value.map((point) => ({
            key: point.bucket,
            label: bucketLabel(bucket.value, point.bucket),
            value: seriesValue(point, ctx.params.value.segment),
          })),
        } as const)
      : null
  );
  return { query, value };
};

const topValue = (row: TopItem, sort: unknown): number =>
  sort === "qty" ? row.qtySold : sort === "profit" ? (row.grossProfit ?? 0) : row.netRevenue;

export const useTopItemsSource = (ctx: SourceContext): SourceResult => {
  const base = reportFilter(ctx, "topItems");
  const filter = computed<TopItemFilter | null>(() => {
    if (!base.value) return null;
    const { kind, sort } = ctx.params.value;
    return { ...base.value, kind: kind as TopItemFilter["kind"], sort: sort as TopItemFilter["sort"] };
  });
  const page = computed(() => ({ pageIndex: 1, pageSize: Number(ctx.params.value.limit) || 5 }));
  const query = useTopItems(page, filter);
  const value = computed(() =>
    query.data.value
      ? ({
          kind: "list",
          rows: query.data.value.rows.map((row) => ({
            key: `${row.itemType}-${row.itemId}`,
            label: row.name,
            value: topValue(row, ctx.params.value.sort),
            format: ctx.params.value.sort === "qty" ? ("count" as const) : ("money" as const),
          })),
        } as const)
      : null
  );
  return { query, value };
};
