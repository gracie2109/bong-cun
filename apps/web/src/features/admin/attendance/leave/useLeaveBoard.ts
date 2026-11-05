import { computed, ref, type Ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { useLeaveList } from "@/features/admin/attendance/queries";
import type { LeaveFilter } from "@bongcun/core/attendance";

const PAGE_SIZE = 20;

export type LeaveTab = LeaveFilter["status"];
export const LEAVE_TABS: LeaveTab[] = ["pending", "approved", "rejected", "cancelled", "all"];

/** The manager's list: one branch, one status tab, a name search and paging. */
export const useLeaveBoard = (branchId: Ref<string | undefined>) => {
  const status = ref<LeaveTab>("pending");
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: PAGE_SIZE, resetOn: [status, branchId] });

  const filter = computed<LeaveFilter>(() => ({
    branchId: branchId.value ?? null,
    status: status.value,
    from: null,
    to: null,
    search: debouncedSearch.value.trim() || undefined,
  }));

  const query = useLeaveList(filter, computed(() => page.pageIndex), PAGE_SIZE);
  const rows = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.total ?? 0);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / PAGE_SIZE)));

  return { status, search, page, query, rows, total, pageCount };
};
