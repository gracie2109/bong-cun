import { computed, ref } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import type { ItemKind, ItemSort, TopItemFilter } from "@bongcun/supabase/reports";
import { useReportFilters } from "../shared/useReportFilters";

const PAGE_SIZE = 20;

/** The shared branch/date filter plus this tab's kind, sort, search and paging. */
export const useItemsFilters = () => {
  const { filter: base, ready, branchValue } = useReportFilters();
  // The kind switch sits next to the search box and applies at once; the sort is in the popover.
  const kind = ref<ItemKind>("all");
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: { sort: "revenue" as ItemSort },
    quick: { kind: { value: kind, default: "all" } },
    resetOn: [base],
  });
  const { applied, debouncedSearch } = list;

  const filter = computed<TopItemFilter | null>(() =>
    base.value ? { ...base.value, kind: kind.value, sort: applied.value.sort, search: debouncedSearch.value } : null
  );

  return { ...list, ready, branchValue, kind, filter };
};
