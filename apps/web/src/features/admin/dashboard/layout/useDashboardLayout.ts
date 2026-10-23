import { computed, type Ref } from "vue";
import { useQuery } from "@tanstack/vue-query";
import { fetchLayout } from "@bongcun/supabase/dashboard";
import { dashboardKeys } from "@/queries/keys";
import { supabaseClient } from "@/lib/supabase";
import { useAuthStore } from "@/stores";
import type { DashboardDef } from "../kit/types";
import { resolveLayout } from "./layoutCodec";

/** The saved layout of the signed-in person for a dashboard, or the dashboard's default. */
export const useDashboardLayout = (dashboard: Ref<Pick<DashboardDef, "key" | "defaultItems"> | null>) => {
  const auth = useAuthStore();
  const userId = computed(() => auth.currentUser?.id);

  const query = useQuery({
    queryKey: computed(() => dashboardKeys.layout(userId.value, dashboard.value?.key ?? "")),
    queryFn: () => fetchLayout(supabaseClient(), (dashboard.value as DashboardDef).key),
    enabled: computed(() => !!dashboard.value && !!userId.value),
  });

  const resolved = computed(() =>
    dashboard.value ? resolveLayout(query.data.value?.layout ?? null, dashboard.value) : null
  );
  return {
    items: computed(() => resolved.value?.items ?? []),
    isDefault: computed(() => resolved.value?.isDefault ?? true),
    broken: computed(() => resolved.value?.broken ?? 0),
    /** 0 while nothing is saved yet: the value `saveLayout` expects for a first save. */
    version: computed(() => query.data.value?.version ?? 0),
    updatedAt: computed(() => query.data.value?.updatedAt ?? null),
    isLoading: query.isPending,
    refetch: () => query.refetch(),
  };
};
