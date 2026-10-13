import { computed } from "vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useReportOverview } from "@/queries/reports";
import type { ReportFilter } from "@/repositories/reports";
import { useAuthStore } from "@/stores";
import { todayInVietnam } from "../reports/shared/dateRange";
import { useReportBranches } from "../reports/shared/useReportBranches";

/** Today's figures at the branch the staff member works at, for those allowed to see reports. */
export const useTodaySales = () => {
  const auth = useAuthStore();
  const { branches } = useReportBranches();
  const { branchId } = useCurrentBranch();

  // The working branch when reports are allowed there, otherwise the first branch that allows them.
  const branch = computed(() => branches.value.find((item) => item.id === branchId.value) ?? branches.value[0] ?? null);

  const filter = computed<ReportFilter | null>(() => {
    if (!auth.can("reports", "VIEW") || !branch.value) return null;
    const today = todayInVietnam();
    return { branchId: branch.value.id, from: today, to: today };
  });

  const query = useReportOverview(filter);
  return { branch, visible: computed(() => !!filter.value && !query.isError.value), data: computed(() => query.data.value) };
};
