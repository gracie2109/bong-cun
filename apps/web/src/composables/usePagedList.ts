import { computed, type Ref } from "vue";
import type { Page } from "@/repositories/shared";

/** Rows, total and page count of a paginated query, with empty values until it has data. */
export const usePagedList = <T>(query: { data: Ref<Page<T> | undefined> }, page: { pageSize: number }) => {
  const rows = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.total ?? 0);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / page.pageSize)));
  return { rows, total, pageCount };
};
