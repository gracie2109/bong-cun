import { computed, watchEffect } from "vue";
import { useLocalStorage } from "@vueuse/core";
import { branchesWithAnyRole } from "@bongcun/core/auth";
import { useBranches } from "@/features/shared/branches/queries/branches";
import { useAuthStore } from "@/stores";

const STORAGE_KEY = "admin.branchId";

/**
 * The branch the staff member is working at, for per-branch screens (POS, invoices, shifts).
 * Remembered on this device; falls back to the first branch the staff member has a role at (every
 * active branch until the roles are loaded, or for an admin account). The database still checks
 * the role at that branch on every call.
 */
export function useCurrentBranch() {
  const branchesQuery = useBranches();
  const stored = useLocalStorage<string>(STORAGE_KEY, "");
  const auth = useAuthStore();
  const branches = computed(() => {
    const all = branchesQuery.data.value ?? [];
    if (!auth.adminGrants) return all;
    const allowed = new Set(branchesWithAnyRole(auth.adminGrants, auth.branchGrants, all.map((item) => item.id)));
    return all.filter((item) => allowed.has(item.id));
  });

  watchEffect(() => {
    const list = branches.value;
    if (list.length && !list.some((branch) => branch.id === stored.value)) stored.value = list[0].id;
  });

  const branch = computed(() => branches.value.find((item) => item.id === stored.value) ?? null);
  const branchId = computed(() => branch.value?.id);

  return { branches, branch, branchId, selectBranch: (id: string) => (stored.value = id) };
}
