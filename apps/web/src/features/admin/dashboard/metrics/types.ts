import type { RangePreset } from "@bongcun/core/dashboard";
import type { ScopeKind } from "../kit/types";

export type MetricGroup = "revenue" | "stock" | "orders" | "spa" | "boarding" | "medical";
/** What a metric yields: one figure, bars over time, or a ranked list. */
export type MetricShape = "number" | "series" | "list";
export type MetricFormat = "money" | "count";
export type MetricView = "kpi" | "barChart" | "list";
/** Which reader (see metrics/sources) fetches the metric. */
export type SourceKey = "overview" | "series" | "topItems" | "stock" | "orders" | "spa" | "boarding" | "medical";

export type MetricParams = Record<string, string | number>;

export type MetricDef = {
  key: string;
  group: MetricGroup;
  labelKey: string;
  shape: MetricShape;
  format: MetricFormat;
  /** One VIEW permission, checked at the branch being viewed. */
  permission: string;
  scopes: readonly ScopeKind[];
  usesRange: boolean;
  defaultRange?: RangePreset;
  /** Allowed values per parameter; the first is the default. Anything else is refused. */
  params?: Record<string, readonly (string | number)[]>;
  /** Views offered when adding the metric; the first is the default. */
  views: readonly MetricView[];
  source: SourceKey;
  /** Which field of the source to read; the source decides what the word means. */
  pick: string;
  /** Route of the screen with the detail, if any. */
  route?: string;
  /** True when a rise is bad news (refunds, overdue): colors the change. */
  riseIsBad?: boolean;
};

/** A single figure, with the same figure for the period before when the source knows it. */
export type NumberValue = { kind: "number"; value: number; previous?: number };
export type SeriesValue = { kind: "series"; points: { key: string; label: string; value: number }[] };
export type ListValue = { kind: "list"; rows: { key: string; label: string; value: number; format: MetricFormat }[] };
export type MetricValue = NumberValue | SeriesValue | ListValue;
