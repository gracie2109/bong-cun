import { computed, ref, type Ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { FILTER_ALL } from "@/lib/listing";
import type { DocStatus, DocType, StockDocumentFilter } from "@/repositories/inventory";

const PAGE_SIZE = 20;

/** Search, type/status filters and paging of the stock documents of one branch. */
export const useDocumentsFilters = (branchId: Ref<string | undefined>) => {
  const docType = ref<string>(FILTER_ALL);
  const status = ref<string>(FILTER_ALL);
  const { search, debouncedSearch, page } = usePagedSearch({
    pageSize: PAGE_SIZE,
    resetOn: [docType, status, branchId],
  });

  /** Null until a branch is known, which keeps the list query off. */
  const filter = computed<StockDocumentFilter | null>(() =>
    branchId.value
      ? {
          branchId: branchId.value,
          docType: docType.value === FILTER_ALL ? undefined : (docType.value as DocType),
          status: status.value === FILTER_ALL ? undefined : (status.value as DocStatus),
          search: debouncedSearch.value,
        }
      : null
  );

  return { search, docType, status, page, filter };
};
