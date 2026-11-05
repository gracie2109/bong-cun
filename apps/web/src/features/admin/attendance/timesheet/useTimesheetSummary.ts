import { computed, ref, type Ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { useTimesheet } from "@/features/admin/attendance/queries";
import { todayInVietnam } from "@/lib/businessDate";
import type { TimesheetFilter } from "@bongcun/core/attendance";
import { isUsableRange, monthStart } from "./timesheetRange";

export const SUMMARY_PAGE_SIZE = 20;

/** Totals per person for one branch (or all the branches the caller may see) over a date range. */
export const useTimesheetSummary = (branchId: Ref<string | undefined>) => {
  const today = todayInVietnam();
  const from = ref(monthStart(today));
  const to = ref(today);
  const { search, debouncedSearch, page } = usePagedSearch({ pageSize: SUMMARY_PAGE_SIZE, resetOn: [from, to, branchId] });

  const rangeOk = computed(() => isUsableRange(from.value, to.value));
  const filter = computed<TimesheetFilter>(() => ({
    branchId: branchId.value ?? null,
    from: from.value,
    to: to.value,
    search: debouncedSearch.value.trim() || undefined,
  }));

  const query = useTimesheet(filter, computed(() => page.pageIndex), SUMMARY_PAGE_SIZE, rangeOk);
  const rows = computed(() => query.data.value?.rows ?? []);
  const total = computed(() => query.data.value?.total ?? 0);
  const pageCount = computed(() => Math.max(1, Math.ceil(total.value / SUMMARY_PAGE_SIZE)));

  return { from, to, search, page, filter, rangeOk, query, rows, pageCount };
};
