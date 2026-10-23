import type { ComputedRef, Ref } from "vue";
import type { DateRange } from "@/features/admin/reports";
import type { DashboardScope } from "../../kit/types";
import type { MetricDef, MetricParams, MetricValue, SourceKey } from "../types";

/** Everything a source needs to read one metric for one widget. */
export type SourceContext = {
  def: MetricDef;
  params: ComputedRef<MetricParams>;
  range: ComputedRef<DateRange>;
  scope: ComputedRef<DashboardScope>;
  /** The branch to ask about; undefined when the metric may not be read for the scope in force. */
  branchId: ComputedRef<string | undefined>;
  /** True when a report adds up every allowed branch. */
  isAll: ComputedRef<boolean>;
  today: ComputedRef<string>;
  /** True only for the source that serves this metric; the others stay idle (their queries off). */
  isActive: (source: SourceKey) => boolean;
};

/** The parts of a vue-query result the widget state needs. */
export type SourceQuery = {
  isPending: Ref<boolean>;
  isError: Ref<boolean>;
  isPlaceholderData?: Ref<boolean>;
  error?: Ref<unknown>;
  refetch: () => unknown;
};

export type SourceResult = { query: SourceQuery; value: ComputedRef<MetricValue | null> };
