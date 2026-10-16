import { computed, reactive, watch, type Ref } from "vue";
import { useBranches } from "@/queries/branches";
import { usePriceEditableBranchIds, useProductBranchPrices, type ProductPriceChanges } from "@/queries/branchPrices";
import { useAuthStore } from "@/stores";
import type { VariantRow } from "../productVariantForm";
import { cellKey, cellPrice, priceText } from "./priceGrid";

/**
 * The variants x branches grid of the product sheet. Only shown when there is more than one
 * branch. A cell holds the typed branch price; empty means the general price applies.
 * `changes` lists just the cells edited since the sheet opened.
 */
export const useBranchPriceGrid = (open: Ref<boolean>, rows: Ref<VariantRow[]>) => {
  const auth = useAuthStore();
  const branchesQuery = useBranches();
  const list = computed(() => branchesQuery.data.value ?? []);
  const visible = computed(() => list.value.length > 1);

  const savedIds = computed(() => rows.value.flatMap((row) => (row.id ? [row.id] : [])));
  const pricesQuery = useProductBranchPrices(savedIds, computed(() => open.value && visible.value));
  const editableQuery = usePriceEditableBranchIds(computed(() => open.value && visible.value && !auth.isAdmin));

  const cells = reactive<Record<string, string>>({});
  const baseline: Record<string, string> = {};

  // Fill the grid from what is saved each time the sheet opens or the saved prices reload.
  watch(
    () => [open.value, pricesQuery.data.value] as const,
    ([isOpen, saved]) => {
      if (!isOpen) return;
      for (const key of Object.keys(cells)) delete cells[key];
      for (const key of Object.keys(baseline)) delete baseline[key];
      for (const id of savedIds.value) {
        for (const branch of list.value) {
          const key = cellKey(id, branch.id);
          cells[key] = baseline[key] = priceText(saved?.[id]?.[branch.id]);
        }
      }
    },
    { immediate: true }
  );

  /** An admin account may set any branch's price; others need "products: Sửa" at that branch. */
  const canEdit = (branchId: string) => auth.isAdmin || (editableQuery.data.value ?? []).includes(branchId);

  const changes = (): ProductPriceChanges[] =>
    savedIds.value.flatMap((productId) => {
      const edited = list.value.filter((branch) => {
        const key = cellKey(productId, branch.id);
        return canEdit(branch.id) && (cells[key] ?? "") !== (baseline[key] ?? "");
      });
      return edited.length
        ? [{ productId, changes: edited.map((branch) => ({ branchId: branch.id, price: cellPrice(cells[cellKey(productId, branch.id)]) })) }]
        : [];
    });

  return { branches: list, visible, cells, loading: computed(() => pricesQuery.isPending.value && savedIds.value.length > 0), canEdit, changes };
};
