import { computed, ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import type { ItemKind, ItemSort, TopItemFilter } from "@/repositories/reports";
import { useReportFilters } from "../shared/useReportFilters";

const PAGE_SIZE = 20;

/** The shared branch/date filter plus this tab's kind, sort, search and paging. */
export const useItemsFilters = () => {
  const { filter: base, ready, branchValue } = useReportFilters();
  const kind = ref<ItemKind>("all");
  const sort = ref<ItemSort>("revenue");
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [kind, sort, base] });

  const filter = computed<TopItemFilter | null>(() =>
    base.value ? { ...base.value, kind: kind.value, sort: sort.value, search: debouncedSearch.value } : null
  );

  return { ready, branchValue, kind, sort, search, page, filter };
};
