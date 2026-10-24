import { computed, type Ref } from "vue";
import type { SavedItem } from "@bongcun/core/dashboard";
import { useAuthStore } from "@/stores";
import { widgetAccess } from "../dashboardRules";
import type { DashboardScope } from "../kit/types";
import { metricAccess } from "../metrics/metricAccess";
import { resolveMetricConfig } from "../widgets/metric/metricConfig";
import { metaOf } from "../widgetTypes/meta";

/**
 * The items this person may see at the branch in view. Hidden ones stay in the saved layout (so
 * another branch still shows them) but are not drawn; unknown types stay visible as a "no longer
 * available" card the person can remove.
 */
export const useVisibleItems = (items: Ref<SavedItem[]>, scope: Ref<DashboardScope>) => {
  const auth = useAuthStore();
  const visible = computed(() =>
    items.value.filter((item) => {
      const meta = metaOf(item.type);
      if (!meta) return true;
      if (meta.byMetric) {
        const resolved = resolveMetricConfig(item.config);
        return !resolved || metricAccess(resolved.def, scope.value, auth.canAt) !== "hidden";
      }
      return widgetAccess(meta, scope.value, auth.canAt) !== "hidden";
    })
  );
  /** Puts positions reported for the visible items back into the full list. */
  const merge = (changed: SavedItem[]): SavedItem[] => {
    const byId = new Map(changed.map((item) => [item.id, item]));
    return items.value.map((item) => byId.get(item.id) ?? item);
  };
  return { visible, merge };
};
