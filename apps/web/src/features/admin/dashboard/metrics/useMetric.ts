import { computed, type ComputedRef } from "vue";
import type { RangeConfig } from "@bongcun/core/dashboard";
import { useWidgetAccess, useWidgetScope } from "../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../kit/widgetState";
import type { WidgetState } from "../kit/types";
import { useToday } from "../useToday";
import { resolveRange } from "../range/widgetRange";
import type { SourceContext, SourceResult } from "./sources/context";
import { useOverviewSource, useSeriesSource, useTopItemsSource } from "./sources/reportSources";
import {
  useBoardingSource,
  useMedicalSource,
  useOrdersSource,
  useSpaSource,
  useStockSource,
} from "./sources/operationSources";
import type { MetricDef, MetricParams, MetricValue, SourceKey } from "./types";

type Input = { def: MetricDef; params: MetricParams; range?: RangeConfig };

/**
 * Reads one catalogue metric for a widget. Every source is set up but only the one that serves the
 * metric has a branch or filter, so only its query runs. Access is the metric's permission at the
 * branch in view (see metricAccess); the database still checks it on every call.
 */
export const useMetric = (input: ComputedRef<Input>) => {
  const scope = useWidgetScope();
  const today = useToday();
  const def = computed(() => input.value.def);
  const { allowed, needsBranch, branchId, isAll } = useWidgetAccess(
    [input.value.def.permission],
    input.value.def.scopes,
    scope
  );

  const ctx: SourceContext = {
    def: input.value.def,
    params: computed(() => input.value.params),
    range: computed(() => resolveRange(input.value.range, def.value.defaultRange ?? "today", today.value)),
    scope,
    branchId,
    isAll,
    today,
    isActive: (source: SourceKey) => allowed.value && def.value.source === source,
  };

  const sources: Record<SourceKey, SourceResult> = {
    overview: useOverviewSource(ctx),
    series: useSeriesSource(ctx),
    topItems: useTopItemsSource(ctx),
    stock: useStockSource(ctx),
    orders: useOrdersSource(ctx),
    spa: useSpaSource(ctx),
    boarding: useBoardingSource(ctx),
    medical: useMedicalSource(ctx),
  };
  const current = computed(() => sources[def.value.source]);

  const value = computed<MetricValue | null>(() => current.value.value.value);
  const isEmpty = computed(() => {
    const v = value.value;
    if (!v) return false;
    if (v.kind === "series") return v.points.every((point) => point.value === 0);
    if (v.kind === "list") return v.rows.length === 0;
    return false;
  });
  const state = computed<WidgetState>(() =>
    resolveWidgetState({
      allowed: allowed.value,
      needsBranch: needsBranch.value,
      query: statusOf(current.value.query),
      isEmpty: isEmpty.value,
    })
  );
  return { state, value, range: ctx.range, refetch: () => current.value.query.refetch() };
};
