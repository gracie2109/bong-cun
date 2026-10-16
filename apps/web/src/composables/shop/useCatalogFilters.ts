import { refDebounced } from "@vueuse/core";
import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { SEARCH_DEBOUNCE_MS } from "@/lib/listing";
import type { CatalogFilters } from "@/types/catalog";
import { filtersFromQuery, filtersToQuery, hasActiveFilters } from "@/utils/shop/catalog";

/**
 * The shop list filters, kept in the URL query (?q=&category=&brand=&sort=) so a link or the back
 * button restores them. The search box types locally and writes to the URL after a pause.
 */
export const useCatalogFilters = () => {
  const route = useRoute();
  const router = useRouter();

  const filters = computed(() => filtersFromQuery(route.query));
  const searchText = ref(filters.value.search);
  const debouncedSearch = refDebounced(searchText, SEARCH_DEBOUNCE_MS);

  const update = (patch: Partial<CatalogFilters>, replace = false) => {
    const next = { ...filters.value, ...patch };
    void router[replace ? "replace" : "push"]({ query: filtersToQuery(next) });
  };

  watch(debouncedSearch, (text) => {
    if (text.trim() !== filters.value.search) update({ search: text.trim() }, true);
  });
  // The URL changed by the back button or a link: show its search text in the box.
  watch(
    () => filters.value.search,
    (text) => {
      if (text !== searchText.value.trim()) searchText.value = text;
    }
  );

  const clear = () => {
    searchText.value = "";
    void router.push({ query: {} });
  };

  return {
    filters,
    searchText,
    isFiltered: computed(() => hasActiveFilters(filters.value)),
    setCategory: (id: string | null) => update({ categoryId: id }),
    setBrand: (id: string | null) => update({ brandId: id }),
    setSort: (sort: CatalogFilters["sort"]) => update({ sort }),
    clearSearch: () => {
      searchText.value = "";
      update({ search: "" }, true);
    },
    clear,
  };
};
