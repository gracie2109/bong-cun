import { computed, ref, type Ref } from "vue";
import type { SavedItem } from "@bongcun/core/dashboard";
import { useAuthStore } from "@/stores";
import { widgetAccess } from "../dashboardRules";
import type { DashboardDef, DashboardScope } from "../kit/types";
import type { MetricDef } from "../metrics/types";
import { metaOf } from "../widgetTypes/meta";
import { addFixedItem, addMetricItem, applySettings, canAddMore, type MetricForm } from "./addWidgetItem";
import { resolveMetricConfig } from "../widgets/metric/metricConfig";

type Draft = { items: Ref<SavedItem[]>; update: (next: SavedItem[]) => void };

/** State of the "Add widget" and "Settings" dialogs and what they do to the draft layout. */
export const useWidgetDialogs = (draft: Draft, dashboard: Ref<DashboardDef | null>, scope: Ref<DashboardScope>) => {
  const auth = useAuthStore();
  const addOpen = ref(false);
  const settingsId = ref<string | null>(null);

  const settingsItem = computed(() => draft.items.value.find((item) => item.id === settingsId.value) ?? null);
  const canAdd = computed(() => canAddMore(draft.items.value));

  /** Fixed widgets of this dashboard that were removed and may be put back. */
  const missingFixed = computed(() => {
    const present = new Set(draft.items.value.map((item) => item.type));
    return (dashboard.value?.defaultItems ?? [])
      .map((item) => item.type)
      .filter((type) => {
        const meta = metaOf(type);
        return !!meta && !present.has(type) && widgetAccess(meta, scope.value, auth.canAt) !== "hidden";
      });
  });

  const addMetric = (def: MetricDef, form: MetricForm) => {
    draft.update(addMetricItem(draft.items.value, def, form));
    addOpen.value = false;
  };
  const addFixed = (type: string) => {
    draft.update(addFixedItem(draft.items.value, type));
    addOpen.value = false;
  };
  const applyToSettingsItem = (form: MetricForm) => {
    const item = settingsItem.value;
    const def = item ? resolveMetricConfig(item.config)?.def : null;
    if (item && def) draft.update(applySettings(draft.items.value, item.id, def, form));
    settingsId.value = null;
  };

  return { addOpen, canAdd, settingsId, settingsItem, missingFixed, addMetric, addFixed, applyToSettingsItem };
};
