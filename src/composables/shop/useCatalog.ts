import { computed } from "vue";
import { useProductBrands, useProductCategories } from "@/queries/productCategories";
import { useShopCatalog } from "@/queries/shopCatalog";
import { buildCategoryTree, categoryName } from "@/utils/shop/catalog";
import { useCatalogFilters } from "./useCatalogFilters";
import { useServerPrefetch } from "./useServerPrefetch";

/** Small fixed lookups (categories, brands) load once; the list pages through the RPC. */
const LOOKUP_PAGE = { pageIndex: 1, pageSize: 200 };

/** Everything the shop list screen needs: URL filters, the groups, and the filter lookups. */
export const useCatalog = () => {
  const state = useCatalogFilters();
  const catalog = useShopCatalog(state.filters);
  const categories = useProductCategories(LOOKUP_PAGE);
  const brands = useProductBrands(LOOKUP_PAGE);
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
    loadMore: catalog.loadMore,
    loading: computed(() => catalog.query.isPending.value),
    // New filters are loading while the previous list stays on screen.
    refreshing: computed(
      () => catalog.query.isFetching.value && !catalog.query.isPending.value && !catalog.query.isFetchingNextPage.value
    ),
    loadingMore: catalog.query.isFetchingNextPage,
    hasMore: catalog.query.hasNextPage,
    failed: catalog.query.isError,
    retry: () => void catalog.query.refetch(),
    categoryTree,
    brandOptions,
    activeCategoryName,
    activeBrandName,
  };
};
