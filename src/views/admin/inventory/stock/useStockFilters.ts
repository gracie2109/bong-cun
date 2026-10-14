import { computed, ref, type Ref } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import type { StockFilter, StockStatus } from "@/repositories/inventory";

const PAGE_SIZE = 20;
const DEFAULT_EXPIRY_DAYS = 60;

/** Search, status, expiry window and paging of the stock list of one branch. */
export const useStockFilters = (branchId: Ref<string | undefined>) => {
  // The status is shared with the alert cards, so it applies at once instead of through the popover.
  const status = ref<StockStatus>("all");
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: { expiryWindow: String(DEFAULT_EXPIRY_DAYS) },
    quick: { status: { value: status, default: "all" } },
    resetOn: [branchId],
  });
  const { applied, debouncedSearch } = list;
  const expiryDays = computed(() => Number(applied.value.expiryWindow));

  /** Null until a branch is known, which keeps the list query off. */
  const filter = computed<StockFilter | null>(() =>
    branchId.value
      ? { branchId: branchId.value, search: debouncedSearch.value, status: status.value, expiryDays: expiryDays.value }
      : null
  );

  return { ...list, status, expiryDays, filter };
};
