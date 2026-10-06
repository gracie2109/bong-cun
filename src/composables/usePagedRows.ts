import { computed, type Ref } from "vue";
import type { PaginationState } from "@tanstack/vue-table";
import { getIndex } from "@/lib/utils";
import type { Page } from "@/repositories/shared";

/** Rows (numbered across pages) and the total for a paginated query, as the admin tables expect. */
export default function <T extends object>(
  query: { data: Ref<Page<T> | undefined> },
  pageData: Ref<PaginationState>
) {
  const rows = computed(() =>
    (query.data.value?.rows ?? []).map((row, index) => ({
      ...row,
      index: getIndex({
        dataPage: { page: pageData.value.pageIndex, page_size: pageData.value.pageSize },
        index,
      }),
    }))
  );
  const total = computed(() => query.data.value?.total ?? 0);
  return { rows, total };
}
