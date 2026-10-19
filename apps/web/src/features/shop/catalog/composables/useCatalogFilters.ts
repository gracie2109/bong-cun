import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import type { CatalogFilters } from "@bongcun/core/shop";
import { filtersFromQuery, filtersToQuery, hasActiveFilters } from "@/utils/shop/catalog";
import { pageFromQuery } from "@/utils/shop/pagination";

/**
 * The shop list filters and page, kept in the URL query (?q=&category=&brand=&sort=&page=) so a link or the
 * back button restores them. Each change loads the page from the server. The search box types locally and
 * writes to the URL when the visitor presses Enter (a reload on every keystroke would drop the focus).
 */
export const useCatalogFilters = () => {
  const route = useRoute();
  const router = useRouter();

  const filters = computed(() => filtersFromQuery(route.query));
  const searchText = ref(filters.value.search);
  const page = computed(() => pageFromQuery(route.query.page));

  const update = (patch: Partial<CatalogFilters>, replace = false) => {
    const next = { ...filters.value, ...patch };
    void router[replace ? "replace" : "push"]({ query: filtersToQuery(next) });
  };

  const submitSearch = () => {
    const text = searchText.value.trim();
    if (text !== filters.value.search) update({ search: text });
  };
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
    page,
    searchText,
    submitSearch,
    isFiltered: computed(() => hasActiveFilters(filters.value)),
    setCategory: (id: string | null) => update({ categoryId: id }),
    setBrand: (id: string | null) => update({ brandId: id }),
    setSort: (sort: CatalogFilters["sort"]) => update({ sort }),
    clearSearch: () => {
      searchText.value = "";
      update({ search: "" });
    },
    clear,
  };
};
