import { computed, type Ref } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import { FILTER_ALL } from "@/lib/listing";
import type { AppointmentFilter, AppointmentStatus } from "@/repositories/spa";

const PAGE_SIZE = 20;

/** Search, date range, status and paging of the appointments of one branch. */
export const useAppointmentFilters = (branchId: Ref<string | undefined>) => {
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: { from: "", to: "", status: FILTER_ALL as string },
    resetOn: [branchId],
  });
  const { applied, debouncedSearch } = list;

  const filter = computed<AppointmentFilter>(() => ({
    from: applied.value.from || undefined,
    to: applied.value.to || undefined,
    status: applied.value.status === FILTER_ALL ? "" : (applied.value.status as AppointmentStatus),
    search: debouncedSearch.value,
  }));

  return { ...list, filter };
};
