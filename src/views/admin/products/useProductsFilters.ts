import { computed, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { usePagedSearch } from "@/composables/usePagedSearch";
import type { ProductFilter } from "@/repositories/products";

const PAGE_SIZE = 20;

const queryText = (value: unknown): string => (typeof value === "string" ? value : "");

/** The search, category, brand and archive filters of the product list; category and brand stay in the URL. */
export const useProductsFilters = () => {
  const route = useRoute();
  const router = useRouter();

  const categoryId = ref(queryText(route.query.category));
  const brandId = ref(queryText(route.query.brand));
  const showArchived = ref(false);
  const { search, debouncedSearch, page } = usePagedSearch({
    pageSize: PAGE_SIZE,
    resetOn: [categoryId, brandId, showArchived],
  });

  watch([categoryId, brandId], ([category, brand]) => {
    void router.replace({ query: { ...route.query, category: category || undefined, brand: brand || undefined } });
  });

  const filter = computed<ProductFilter>(() => ({
    search: debouncedSearch.value,
    includeArchived: showArchived.value,
    categoryId: categoryId.value || undefined,
    brandId: brandId.value || undefined,
  }));

  return { search, categoryId, brandId, showArchived, page, filter };
};
