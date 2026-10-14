import { computed } from "vue";
import { useI18n } from "vue-i18n";
import type { FilterChip } from "@/types/catalog";
import type { useCatalog } from "./useCatalog";

/** The removable "filtering by" pills and the props the filter panel needs, derived from the catalog state. */
export const useCatalogChips = (catalog: ReturnType<typeof useCatalog>) => {
  const { t } = useI18n();

  const chips = computed<FilterChip[]>(() => {
    const { search, categoryId, brandId } = catalog.filters.value;
    const list: FilterChip[] = [];
    if (search) list.push({ key: "q", label: `"${search}"`, remove: catalog.clearSearch });
    if (categoryId) {
      list.push({
        key: "category",
        label: catalog.activeCategoryName.value ?? t("client.catalog.categories"),
        remove: () => catalog.setCategory(null),
      });
    }
    if (brandId) {
      list.push({
        key: "brand",
        label: catalog.activeBrandName.value ?? t("client.catalog.brands"),
        remove: () => catalog.setBrand(null),
      });
    }
    return list;
  });

  const filterProps = computed(() => ({
    categoryTree: catalog.categoryTree.value,
    brands: catalog.brandOptions.value,
    categoryId: catalog.filters.value.categoryId,
    brandId: catalog.filters.value.brandId,
    isFiltered: catalog.isFiltered.value,
  }));

  return { chips, filterProps };
};
