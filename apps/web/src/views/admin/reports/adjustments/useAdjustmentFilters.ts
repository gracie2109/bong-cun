import { computed, ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import type { AdjustmentFilter, AdjustmentKind } from "@/repositories/reports";
import { useReportFilters } from "../shared/useReportFilters";

const PAGE_SIZE = 20;

/** The shared branch/date filter plus the kind (returns / cancellations), search and paging. */
export const useAdjustmentFilters = () => {
  const { filter: base, branches } = useReportFilters();
  const kind = ref<AdjustmentKind>("all");
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [kind, base] });

  const filter = computed<AdjustmentFilter | null>(() =>
    base.value ? { ...base.value, kind: kind.value, search: debouncedSearch.value } : null
  );

  return { branches, kind, search, page, filter };
};
