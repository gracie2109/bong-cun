import { computed, ref } from "vue";
import type { ReportFilter, SeriesPoint } from "@bongcun/supabase/reports";
import { useRevenueSeries } from "@/features/admin/reports";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";
import { isTrendEmpty, trendRange, type TrendDays } from "./trend";

const NO_POINTS: SeriesPoint[] = [];

export const useRevenueTrend = () => {
  const { allowed, needsBranch, branchId, isAll } = useWidgetAccess(["reports"], ["branch", "all"]);
  const today = useToday();
  const days = ref<TrendDays>(7);

  const filter = computed<ReportFilter | null>(() => {
    if (!allowed.value || (!isAll.value && !branchId.value)) return null;
    return { branchId: isAll.value ? null : (branchId.value as string), ...trendRange(today.value, days.value) };
  });

  const query = useRevenueSeries(filter, "day");
  const points = computed(() => query.data.value ?? NO_POINTS);
  const state = computed(() =>
    resolveWidgetState({
      allowed: allowed.value,
      needsBranch: needsBranch.value,
      query: statusOf(query),
      isEmpty: !!query.data.value && isTrendEmpty(points.value),
    })
  );
  return { state, days, points, refetch: () => query.refetch() };
};
