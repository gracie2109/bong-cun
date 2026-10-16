import { computed, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { useListFilters } from "@/composables/useListFilters";
import type { ProductFilter } from "@bongcun/supabase/products";

const PAGE_SIZE = 20;

const queryText = (value: unknown): string => (typeof value === "string" ? value : "");

/** The search, category, brand and archive filters of the product list; category and brand stay in the URL. */
export const useProductsFilters = () => {
  const route = useRoute();
  const router = useRouter();

  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: { categoryId: "", brandId: "", showArchived: false },
    initial: { categoryId: queryText(route.query.category), brandId: queryText(route.query.brand) },
  });
  const { applied, debouncedSearch } = list;

  watch(
    () => [applied.value.categoryId, applied.value.brandId],
    ([category, brand]) => {
      void router.replace({ query: { ...route.query, category: category || undefined, brand: brand || undefined } });
    }
  );

  const filter = computed<ProductFilter>(() => ({
    search: debouncedSearch.value,
    includeArchived: applied.value.showArchived,
    categoryId: applied.value.categoryId || undefined,
    brandId: applied.value.brandId || undefined,
  }));

  return { ...list, filter };
};
