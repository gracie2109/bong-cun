import { computed, ref, type Ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import type { StockFilter, StockStatus } from "@/repositories/inventory";

const PAGE_SIZE = 20;
const DEFAULT_EXPIRY_DAYS = 60;

/** Search, status, expiry window and paging of the stock list of one branch. */
export const useStockFilters = (branchId: Ref<string | undefined>) => {
  const status = ref<StockStatus>("all");
  const expiryWindow = ref(String(DEFAULT_EXPIRY_DAYS));
  const expiryDays = computed(() => Number(expiryWindow.value));
  const { search, debouncedSearch, page } = usePagedSearch({
    pageSize: PAGE_SIZE,
    resetOn: [status, expiryDays, branchId],
  });

  /** Null until a branch is known, which keeps the list query off. */
  const filter = computed<StockFilter | null>(() =>
    branchId.value
      ? { branchId: branchId.value, search: debouncedSearch.value, status: status.value, expiryDays: expiryDays.value }
      : null
  );

  return { search, status, expiryWindow, expiryDays, page, filter };
};
