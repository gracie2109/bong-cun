import type { MetricDef, MetricGroup } from "../metrics/types";

/** Lower case without accents, so "doanh thu" finds "Doanh thu" and "ton kho" finds "tồn kho". */
export const fold = (text: string): string =>
  text.normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/đ/gi, "d").toLowerCase().trim();

export type MetricGroupList = { group: MetricGroup; metrics: MetricDef[] };

const GROUP_ORDER: readonly MetricGroup[] = ["revenue", "orders", "stock", "spa", "boarding", "medical"];

/** Metrics matching the query, grouped in a fixed order; empty groups are left out. */
export const groupMetrics = (
  metrics: readonly MetricDef[],
  query: string,
  labelOf: (def: MetricDef) => string
): MetricGroupList[] => {
  const needle = fold(query);
  const matching = metrics.filter((def) => !needle || fold(labelOf(def)).includes(needle));
  return GROUP_ORDER.map((group) => ({ group, metrics: matching.filter((def) => def.group === group) })).filter(
    (entry) => entry.metrics.length > 0
  );
};
