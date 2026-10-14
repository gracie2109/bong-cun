import { computed, type Ref } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import { FILTER_ALL } from "@/lib/listing";
import type { DocStatus, DocType, StockDocumentFilter } from "@/repositories/inventory";

const PAGE_SIZE = 20;

/** Search, type/status filters and paging of the stock documents of one branch. */
export const useDocumentsFilters = (branchId: Ref<string | undefined>) => {
  const list = useListFilters({
    pageSize: PAGE_SIZE,
    defaults: { docType: FILTER_ALL as string, status: FILTER_ALL as string },
    resetOn: [branchId],
  });
  const { applied, debouncedSearch } = list;

  /** Null until a branch is known, which keeps the list query off. */
  const filter = computed<StockDocumentFilter | null>(() =>
    branchId.value
      ? {
          branchId: branchId.value,
          docType: applied.value.docType === FILTER_ALL ? undefined : (applied.value.docType as DocType),
          status: applied.value.status === FILTER_ALL ? undefined : (applied.value.status as DocStatus),
          search: debouncedSearch.value,
        }
      : null
  );

  return { ...list, filter };
};
