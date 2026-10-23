// Date range of a metric widget: pure functions on yyyy-MM-dd strings (Vietnam calendar days).
import { addDays, format, parseISO } from "date-fns";
import type { RangeConfig, RangePreset } from "@bongcun/core/dashboard";
import { MAX_RANGE_DAYS } from "@bongcun/core/dashboard";
import { presetRange, rangeDays, rangeProblem, type DateRange } from "@/features/admin/reports/shared/dateRange";

/** The range of a preset; "last30" is the 30 days up to and including today. */
export const presetToRange = (preset: RangePreset, today: string): DateRange =>
  preset === "last30"
    ? { from: format(addDays(parseISO(today), -29), "yyyy-MM-dd"), to: today }
    : presetRange(preset, today);

/** A fixed range is usable when it runs forward and is no longer than the reports accept. */
export const isUsableRange = (range: DateRange): boolean => rangeProblem(range) === null && rangeDays(range) <= MAX_RANGE_DAYS;

/**
 * The days a widget reads: its own setting, else the metric's default. A saved fixed range that
 * is no longer valid falls back to the default instead of failing.
 */
export const resolveRange = (config: RangeConfig | undefined, fallback: RangePreset, today: string): DateRange => {
  if (config?.kind === "fixed" && isUsableRange(config)) return { from: config.from, to: config.to };
  if (config?.kind === "preset") return presetToRange(config.preset, today);
  return presetToRange(fallback, today);
};

/** What to show under the title: the preset key (translated by the caller) or the two dates. */
export type RangeLabel = { kind: "preset"; preset: RangePreset } | { kind: "fixed"; from: string; to: string };

export const rangeLabel = (config: RangeConfig | undefined, fallback: RangePreset): RangeLabel => {
  if (config?.kind === "fixed" && isUsableRange(config)) return { kind: "fixed", from: config.from, to: config.to };
  return { kind: "preset", preset: config?.kind === "preset" ? config.preset : fallback };
};

/** Bar chart buckets by length when the person picked none: a day up to a month, a week up to ~4 months. */
export const bucketFor = (range: DateRange): "day" | "week" | "month" => {
  const days = rangeDays(range);
  return days <= 31 ? "day" : days <= 120 ? "week" : "month";
};
