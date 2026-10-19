import { computed } from "vue";
import { usePublicBrands, usePublicCategories } from "@/features/shared/public-api";
import { SHOP_PAGE_SIZE, useShopCatalog } from "@/features/shop/catalog/queries/shopCatalog";
import { buildCategoryTree, categoryName, filtersToQuery } from "@/utils/shop/catalog";
import { useCatalogFilters } from "@/features/shop/catalog/composables/useCatalogFilters";
import { useServerPrefetch } from "@/composables/shop/useServerPrefetch";

/** Small fixed lookups (categories, brands) load once; the list pages through the RPC. */
const LOOKUP_PAGE = { pageIndex: 1, pageSize: 200 };

/** Everything the shop list screen needs: URL filters and page, the groups, and the filter lookups. */
export const useCatalog = () => {
  const state = useCatalogFilters();
  const catalog = useShopCatalog(state.filters, SHOP_PAGE_SIZE, state.page);
  const categories = usePublicCategories(LOOKUP_PAGE);
  const brands = usePublicBrands(LOOKUP_PAGE);
  useServerPrefetch(catalog.query, categories, brands);

  const categoryTree = computed(() => buildCategoryTree(categories.data.value?.rows ?? []));
  const brandOptions = computed(() => (brands.data.value?.rows ?? []).map((brand) => ({ id: brand.id, name: brand.name })));

  const activeCategoryName = computed(() => categoryName(categoryTree.value, state.filters.value.categoryId));
  const activeBrandName = computed(
    () => brandOptions.value.find((brand) => brand.id === state.filters.value.brandId)?.name ?? null
  );

  return {
    ...state,
    groups: catalog.groups,
    total: catalog.total,
    pageSize: SHOP_PAGE_SIZE,
    pageQuery: computed(() => filtersToQuery(state.filters.value)),
    loading: computed(() => catalog.query.isPending.value),
    failed: catalog.query.isError,
    retry: () => void catalog.query.refetch(),
    categoryTree,
    brandOptions,
    activeCategoryName,
    activeBrandName,
  };
};
