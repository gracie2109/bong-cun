import { computed, ref } from "vue";
import { useProductCategories } from "@/queries/productCategories";

/** Categories are few; this page holds them all for the chip bar. */
const CATEGORY_PAGE = { pageIndex: 1, pageSize: 200 };

export type CategoryChip = { id: string; name: string; count: number };

/** Top-level categories that have products, as chips, and the category ids the chosen chip covers. */
export const useCategoryChips = () => {
  const query = useProductCategories(CATEGORY_PAGE);
  const selected = ref("");

  const chips = computed<CategoryChip[]>(() =>
    (query.data.value?.rows ?? [])
      .filter((row) => row.parentId === null && row.productCount > 0)
      .map((row) => ({ id: row.id, name: row.name, count: row.productCount }))
  );

  /** The chosen top-level category and its sub-categories; empty means no filter. */
  const categoryIds = computed<string[]>(() => {
    if (!selected.value) return [];
    const children = (query.data.value?.rows ?? []).filter((row) => row.parentId === selected.value);
    return [selected.value, ...children.map((row) => row.id)];
  });

  return { chips, selected, categoryIds };
};
