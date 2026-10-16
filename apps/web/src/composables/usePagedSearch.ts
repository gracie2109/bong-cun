import { reactive, ref, watch, type WatchSource } from "vue";
import { refDebounced } from "@vueuse/core";
import { INITIAL_PAGE_INDEX } from "@/lib/constants";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";

type Options = {
  pageSize: number;
  debounceMs?: number;
  /** Other filters of the list: changing one goes back to the first page, like a new search. */
  resetOn?: WatchSource[];
};

/** A search box (debounced) and the paging of a list; the page returns to the first when the search or a filter changes. */
export const usePagedSearch = ({ pageSize, debounceMs = SEARCH_DEBOUNCE_MS, resetOn = [] }: Options) => {
  const search = ref("");
  const debouncedSearch = refDebounced(search, debounceMs);
  const page = reactive({ pageIndex: INITIAL_PAGE_INDEX, pageSize });

  watch([debouncedSearch, ...resetOn], () => {
    page.pageIndex = INITIAL_PAGE_INDEX;
  });

  return { search, debouncedSearch, page };
};
