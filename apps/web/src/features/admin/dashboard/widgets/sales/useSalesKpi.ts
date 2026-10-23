import { computed, ref, type Ref } from "vue";
import type { ReportFilter } from "@bongcun/supabase/reports";
import { presetRange, useReportOverview } from "@/features/admin/reports";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";
import type { SalesPeriod } from "./salesKpi";

/** Revenue of a period at the branch (or every allowed branch), read from the same report as the Tổng quan tab. */
export const useSalesKpi = (initialPeriod: SalesPeriod) => {
  const { allowed, needsBranch, branchId, isAll } = useWidgetAccess(["reports"], ["branch", "all"]);
  const today = useToday();
  const period: Ref<SalesPeriod> = ref(initialPeriod);

  const filter = computed<ReportFilter | null>(() => {
    if (!allowed.value || (!isAll.value && !branchId.value)) return null;
    const range = presetRange(period.value, today.value);
    return { branchId: isAll.value ? null : (branchId.value as string), ...range };
  });

  const query = useReportOverview(filter);
  const state = computed(() =>
    resolveWidgetState({ allowed: allowed.value, needsBranch: needsBranch.value, query: statusOf(query), isEmpty: false })
  );
  return { state, period, data: computed(() => query.data.value), refetch: () => query.refetch() };
};
