import { computed, reactive, ref, watch, type Ref } from "vue";
import { watchDebounced } from "@vueuse/core";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";
import { countActiveFilters, isSameFilterValue } from "./listFilters";

/** A filter shown next to the search box that applies at once; Clear and the badge count it too. */
type QuickFilter = { value: Ref<unknown>; default: unknown };

type Options<F extends Record<string, unknown>> = {
  pageSize: number;
  /** What each popover filter holds when not filtering; Clear returns to exactly these. */
  defaults: F;
  debounceMs?: number;
  quick?: Record<string, QuickFilter>;
};

/**
 * Search box, popover filters and paging of a list, for use with `SearchView`.
 * The popover edits `draft`; `apply` copies it to `applied`, which the screen puts in its query filter.
 */
export const useListFilters = <F extends Record<string, unknown>>({
  pageSize,
  defaults,
  debounceMs = SEARCH_DEBOUNCE_MS,
  quick = {},
}: Options<F>) => {
  const applied = ref({ ...defaults }) as Ref<F>;
  const draft = reactive({ ...defaults }) as F;
  const quickValues = Object.values(quick).map((item) => item.value);

  // Like usePagedSearch, but `debouncedSearch` can also be committed at once (Enter, Clear).
  const search = ref("");
  const debouncedSearch = ref("");
  const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize });
  watchDebounced(search, (value) => (debouncedSearch.value = value), { debounce: debounceMs });
  watch([debouncedSearch, applied, ...quickValues], () => {
    page.pageIndex = INITIAL_PAGE_INDEX;
  });

  const activeCount = computed(
    () =>
      countActiveFilters(applied.value, defaults) +
      Object.values(quick).filter((item) => !isSameFilterValue(item.value.value, item.default)).length
  );
  const isFiltered = computed(() => activeCount.value > 0 || search.value !== "");

  const syncDraft = () => Object.assign(draft, applied.value);
  const resetDraft = () => Object.assign(draft, defaults);
  const apply = () => {
    applied.value = { ...draft };
    // Enter on the search box: search now, do not wait for the debounce.
    debouncedSearch.value = search.value;
  };
  const clearAll = () => {
    search.value = "";
    debouncedSearch.value = "";
    resetDraft();
    applied.value = { ...defaults };
    for (const item of Object.values(quick)) item.value.value = item.default;
  };

  return { search, debouncedSearch, page, applied, draft, activeCount, isFiltered, apply, resetDraft, clearAll, syncDraft };
};
