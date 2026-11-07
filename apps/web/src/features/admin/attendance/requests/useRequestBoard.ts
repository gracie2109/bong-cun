import { computed, ref, type Ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { useShiftRequestList } from "@/features/admin/attendance/queries";
import type { ShiftRequestFilter } from "@bongcun/core/attendance";

const PAGE_SIZE = 20;

export type RequestTab = ShiftRequestFilter["status"];
export const REQUEST_TABS: RequestTab[] = ["pending", "approved", "rejected", "cancelled", "all"];

/** The manager's list: one branch, a status tab, a date range, a name search and paging. */
export const useRequestBoard = (branchId: Ref<string | undefined>) => {
  const status = ref<RequestTab>("pending");
  const from = ref("");
  const to = ref("");
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [status, branchId, from, to] });

  const filter = computed<ShiftRequestFilter>(() => ({
    branchId: branchId.value ?? null,
    status: status.value,
    from: from.value || null,
    to: to.value || null,
    search: debouncedSearch.value.trim() || undefined,
  }));

  const query = useShiftRequestList(filter, computed(() => page.pageIndex), PAGE_SIZE);
  const rows = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.total ?? 0);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

  return { status, from, to, search, page, query, rows, total, pageCount };
};
