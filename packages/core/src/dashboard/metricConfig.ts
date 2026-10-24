// The settings of a widget that shows one catalogue metric. The metric key and its parameters are
// checked against the app's catalogue when the widget is drawn; here only the shape is fixed.
import { z } from "zod";

export const RANGE_PRESETS = ["today", "yesterday", "last7", "last30", "thisMonth", "lastMonth"] as const;
export type RangePreset = (typeof RANGE_PRESETS)[number];

/** The longest fixed range, the same limit the report RPCs enforce. */
export const MAX_RANGE_DAYS = 366;

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/);

export const rangeConfigSchema = z.discriminatedUnion("kind", [
  z.object({ kind: z.literal("preset"), preset: z.enum(RANGE_PRESETS) }),
  z.object({ kind: z.literal("fixed"), from: isoDate, to: isoDate }),
]);
export type RangeConfig = z.infer<typeof rangeConfigSchema>;

export const metricConfigSchema = z.object({
  metric: z.string().min(1).max(64),
  params: z.record(z.union([z.string().max(32), z.number()])).optional(),
  title: z.string().trim().max(60).optional(),
  range: rangeConfigSchema.optional(),
  /** KPI only: show the change against the period before. */
  compare: z.boolean().optional(),
  /** How the metric is drawn: a KPI card, a bar chart or a list. */
  view: z.enum(["kpi", "barChart", "list"]).optional(),
});
export type MetricConfig = z.infer<typeof metricConfigSchema>;

/** Reads a widget's `config` as a metric config; null when it is missing or malformed. */
export const parseMetricConfig = (config: unknown): MetricConfig | null => {
  const parsed = metricConfigSchema.safeParse(config);
  return parsed.success ? parsed.data : null;
};
