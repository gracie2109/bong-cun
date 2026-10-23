import { computed } from "vue";
import { useLocalStorage } from "@vueuse/core";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import type { DashboardScope, ScopeKind } from "./kit/types";

const STORAGE_KEY = "admin.dashboard.scope";

/**
 * The dashboard's scope: the working branch (shared with every other admin screen through
 * useCurrentBranch) or "all branches", which only this page uses and only with two or more branches.
 */
export const useDashboardScope = () => {
  const { branches, branchId, selectBranch } = useCurrentBranch();
  const stored = useLocalStorage<ScopeKind>(STORAGE_KEY, "branch");

  const branchIds = computed(() => branches.value.map((branch) => branch.id));
  const canPickAll = computed(() => branches.value.length > 1);
  const kind = computed<ScopeKind>(() => (canPickAll.value && stored.value === "all" ? "all" : "branch"));
  const scope = computed<DashboardScope>(() => ({ kind: kind.value, branchId: branchId.value, branchIds: branchIds.value }));

  const select = (value: string) => {
    if (value === "all") stored.value = "all";
    else {
      stored.value = "branch";
      selectBranch(value);
    }
  };
  return { scope, branches, canPickAll, select };
};
