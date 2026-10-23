import { computed, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { useMetric } from "../../metrics/useMetric";
import type { ResolvedMetric } from "./metricConfig";

/** A metric widget's data, title and state. Call it only with a metric that exists in the catalogue. */
export const useMetricWidget = (resolved: Ref<ResolvedMetric>) => {
  const { t } = useI18n();
  const metric = useMetric(computed(() => ({ def: resolved.value.def, params: resolved.value.params, range: resolved.value.range })));
  const title = computed(() => resolved.value.title || t(resolved.value.def.labelKey, resolved.value.params));
  return { ...metric, title };
};
