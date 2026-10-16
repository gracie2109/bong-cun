import { computed, type Ref } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import { FILTER_ALL } from "@/lib/listing";
import type { VisitFilter, VisitStatus } from "@bongcun/core/medical";

const PAGE_SIZE = 20;

/** Search, date range, status, vet and paging of the medical visits of one branch. */
export const useVisitFilters = (branchId: Ref<string | undefined>) => {
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: { from: "", to: "", status: FILTER_ALL as string, vetId: FILTER_ALL as string },
    resetOn: [branchId],
  });
  const { applied, debouncedSearch } = list;

  const filter = computed<VisitFilter>(() => ({
    from: applied.value.from || undefined,
    to: applied.value.to || undefined,
    status: applied.value.status === FILTER_ALL ? "" : (applied.value.status as VisitStatus),
    vetId: applied.value.vetId === FILTER_ALL ? undefined : applied.value.vetId,
    search: debouncedSearch.value,
  }));

  return { ...list, filter };
};
