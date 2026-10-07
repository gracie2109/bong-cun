import { computed, watchEffect } from "vue";
import { useLocalStorage } from "@vueuse/core";
import { useBranches } from "@/queries/branches";

const STORAGE_KEY = "admin.branchId";

/**
 * The branch the staff member is working at, for per-branch screens (POS, invoices, shifts).
 * Remembered on this device; falls back to the first active branch. The database still checks
 * the staff member's role at that branch on every call.
 */
export function useCurrentBranch() {
  const branchesQuery = useBranches();
  const stored = useLocalStorage<string>(STORAGE_KEY, "");
  const branches = computed(() => branchesQuery.data.value ?? []);

  watchEffect(() => {
    const list = branches.value;
    if (list.length && !list.some((branch) => branch.id === stored.value)) stored.value = list[0].id;
  });

  const branch = computed(() => branches.value.find((item) => item.id === stored.value) ?? null);
  const branchId = computed(() => branch.value?.id);

  return { branches, branch, branchId, selectBranch: (id: string) => (stored.value = id) };
}
