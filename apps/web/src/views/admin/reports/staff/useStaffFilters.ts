import { computed, ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import type { StaffFilter, StaffRole } from "@/repositories/reports";
import { useReportFilters } from "../shared/useReportFilters";

const PAGE_SIZE = 20;

/** The shared branch/date filter plus the staff role tab, search and paging. */
export const useStaffFilters = () => {
  const { filter: base } = useReportFilters();
  const role = ref<StaffRole>("cashier");
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [role, base] });

  const filter = computed<StaffFilter | null>(() =>
    base.value ? { ...base.value, role: role.value, search: debouncedSearch.value } : null
  );

  return { role, search, page, filter };
};
