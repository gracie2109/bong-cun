import { computed } from "vue";
import { useBranches } from "@/queries/branches";
import { useReportBranchIds } from "@/queries/reports";
import { useAuthStore } from "@/stores";

/** The branches the signed-in staff member may see reports for. */
export const useReportBranches = () => {
  const auth = useAuthStore();
  const branchesQuery = useBranches();
  const permittedQuery = useReportBranchIds();

  // An admin account with no branch roles yet is "all": the database lets it see every branch.
  const branches = computed(() => {
    const all = branchesQuery.data.value ?? [];
    if (auth.adminGrants === "all") return all;
    const permitted = new Set(permittedQuery.data.value ?? []);
    return all.filter((branch) => permitted.has(branch.id));
  });

  const ready = computed(() => !branchesQuery.isPending.value && !permittedQuery.isPending.value);
  /** "All branches" only makes sense with a grant at two or more. */
  const canPickAll = computed(() => branches.value.length > 1);

  return { branches, ready, canPickAll };
};
