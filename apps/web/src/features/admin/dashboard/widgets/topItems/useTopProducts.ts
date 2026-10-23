import { computed } from "vue";
import type { TopItemFilter } from "@bongcun/supabase/reports";
import { presetRange, useTopItems } from "@/features/admin/reports";
import { useWidgetAccess } from "../../kit/widgetScope";
import { resolveWidgetState, statusOf } from "../../kit/widgetState";
import { useToday } from "../../useToday";

const PAGE = { pageIndex: 1, pageSize: 5 };

/** The five best-selling goods this month. kind "product" is required: lodging lines carry no item id. */
export const useTopProducts = () => {
  const { allowed, needsBranch, branchId, isAll } = useWidgetAccess(["reports"], ["branch", "all"]);
  const today = useToday();

  const filter = computed<TopItemFilter | null>(() => {
    if (!allowed.value || (!isAll.value && !branchId.value)) return null;
    return {
      branchId: isAll.value ? null : (branchId.value as string),
      ...presetRange("thisMonth", today.value),
      kind: "product",
      sort: "revenue",
    };
  });

  const query = useTopItems(PAGE, filter);
  const rows = computed(() => query.data.value?.rows ?? []);
  const state = computed(() =>
    resolveWidgetState({
      allowed: allowed.value,
      needsBranch: needsBranch.value,
      query: statusOf(query),
      isEmpty: !!query.data.value && rows.value.length === 0,
    })
  );
  return { state, rows, refetch: () => query.refetch() };
};
