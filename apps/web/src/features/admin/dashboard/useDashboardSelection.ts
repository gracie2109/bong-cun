import { computed } from "vue";
import { useLocalStorage } from "@vueuse/core";
import { useRoute, useRouter } from "vue-router";
import { useAuthStore } from "@/stores";
import { DASHBOARDS } from "./dashboards";
import { pickDashboard, visibleDashboards } from "./dashboardRules";
import type { DashboardScope } from "./kit/types";

const STORAGE_KEY = "admin.dashboard";

/** Which dashboard is open: ?view= in the URL (shareable, Back works), else the last one used here. */
export const useDashboardSelection = (scope: { value: DashboardScope }) => {
  const auth = useAuthStore();
  const route = useRoute();
  const router = useRouter();
  const stored = useLocalStorage<string>(STORAGE_KEY, "today");

  const visible = computed(() => visibleDashboards(DASHBOARDS, scope.value, auth.canAt));
  const activeKey = computed(() =>
    pickDashboard(visible.value.map((item) => item.key), route.query.view, stored.value)
  );
  const active = computed(() => visible.value.find((item) => item.key === activeKey.value) ?? null);

  const open = (key: string) => {
    stored.value = key;
    void router.push({ name: "dashboard", query: { ...route.query, view: key } });
  };
  return { visible, active, open };
};
