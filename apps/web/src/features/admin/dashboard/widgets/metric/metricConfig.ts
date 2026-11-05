// Reads the saved settings of a metric widget into what the widget needs; null when the metric is gone.
import { parseMetricConfig, type MetricConfig, type RangeConfig } from "@bongcun/core/dashboard";
import { metricOf } from "../../metrics/catalogue";
import { resolveParams } from "../../metrics/params";
import type { MetricDef, MetricParams, MetricView } from "../../metrics/types";

export type ResolvedMetric = {
  def: MetricDef;
  params: MetricParams;
  range: RangeConfig | undefined;
  title: string | undefined;
  compare: boolean;
  /** The chart style the person chose; undefined = the metric's first view. */
  view: MetricView | undefined;
};

export const resolveMetricConfig = (config: unknown): ResolvedMetric | null => {
  const parsed: MetricConfig | null = parseMetricConfig(config);
  const def = parsed ? metricOf(parsed.metric) : null;
  if (!parsed || !def) return null;
  const params = resolveParams(def, parsed.params);
  if (!params) return null;
  return { def, params, range: parsed.range, title: parsed.title || undefined, compare: parsed.compare === true, view: parsed.view && def.views.includes(parsed.view) ? parsed.view : undefined };
};
