import { computed, ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import type { ShiftReconFilter, ShiftStatusFilter } from "@bongcun/supabase/reports";
import { useReportFilters } from "../shared/useReportFilters";

const PAGE_SIZE = 20;

/** The shared branch/date filter plus the shift status, search and paging. */
export const useShiftReconFilters = () => {
  const { filter: base } = useReportFilters();
  const status = ref<ShiftStatusFilter>("all");
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [status, base] });

  const filter = computed<ShiftReconFilter | null>(() =>
    base.value ? { ...base.value, status: status.value, search: debouncedSearch.value } : null
  );

  return { status, search, page, filter };
};
