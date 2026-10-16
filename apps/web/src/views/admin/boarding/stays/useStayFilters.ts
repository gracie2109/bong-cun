import { computed, type Ref } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import { FILTER_ALL } from "@/lib/listing";
import type { StayFilter, StayStatus } from "@/types/boarding";

const PAGE_SIZE = 20;

/** Search, date range, status and paging of the boarding stays of one branch. */
export const useStayFilters = (branchId: Ref<string | undefined>) => {
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: { from: "", to: "", status: FILTER_ALL as string },
    resetOn: [branchId],
  });
  const { applied, debouncedSearch } = list;

  const filter = computed<StayFilter>(() => ({
    from: applied.value.from || undefined,
    to: applied.value.to || undefined,
    status: applied.value.status === FILTER_ALL ? "" : (applied.value.status as StayStatus),
    search: debouncedSearch.value,
  }));

  return { ...list, filter };
};
