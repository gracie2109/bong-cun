import { computed } from "vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import type { DashboardScope } from "../kit/types";
import { useActionItems } from "../widgets/actionItems/useActionItems";

/** What needs doing at the working branch, for the bell in the header (the same sources as the to-do widget). */
export const useBellItems = () => {
  const { branches, branchId } = useCurrentBranch();
  const scope = computed<DashboardScope>(() => ({
    kind: "branch",
    branchId: branchId.value,
    branchIds: branches.value.map((branch) => branch.id),
  }));
  const { rows, state } = useActionItems(scope);

  const todo = computed(() => rows.value.filter((row) => (row.count ?? 0) > 0));
  const total = computed(() => todo.value.reduce((sum, row) => sum + (row.count ?? 0), 0));
  return { todo, total, hidden: computed(() => state.value === "hidden" || state.value === "needsBranch") };
};
