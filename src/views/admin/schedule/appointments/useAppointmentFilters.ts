import { computed, ref, type Ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { FILTER_ALL } from "@/lib/listing";
import type { AppointmentFilter, AppointmentStatus } from "@/repositories/spa";

const PAGE_SIZE = 20;

/** Search, date range, status and paging of the appointments of one branch. */
export const useAppointmentFilters = (branchId: Ref<string | undefined>) => {
  const from = ref("");
  const to = ref("");
  const status = ref<string>(FILTER_ALL);
  const { search, debouncedSearch, page } = usePagedSearch({
    pageSize: PAGE_SIZE,
    resetOn: [from, to, status, branchId],
  });

  const filter = computed<AppointmentFilter>(() => ({
    from: from.value || undefined,
    to: to.value || undefined,
    status: status.value === FILTER_ALL ? "" : (status.value as AppointmentStatus),
    search: debouncedSearch.value,
  }));

  return { search, from, to, status, page, filter };
};
