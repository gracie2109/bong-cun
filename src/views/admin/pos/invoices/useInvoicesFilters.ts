import { computed, ref, type Ref } from "vue";
import { usePagedSearch } from "@/composables/usePagedSearch";
import { FILTER_ALL } from "@/lib/listing";
import type { InvoiceFilter, InvoiceStatus } from "@/repositories/pos";

export const PERIODS = ["today", "week", "month", "all"] as const;
export type Period = (typeof PERIODS)[number];

const PAGE_SIZE = 20;
const WEEK_DAYS = 7;
const MONTH_DAYS = 30;

/** Start of the period as an ISO time, or undefined for no lower bound. */
const periodStart = (value: Period): string | undefined => {
  if (value === "all") return undefined;
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  if (value === "week") start.setDate(start.getDate() - (WEEK_DAYS - 1));
  if (value === "month") start.setDate(start.getDate() - (MONTH_DAYS - 1));
  return start.toISOString();
};

/** Search, period/status filters and paging of the invoices of one branch. */
export const useInvoicesFilters = (branchId: Ref<string | undefined>) => {
  const period = ref<Period>("today");
  const status = ref<string>(FILTER_ALL);
  const { search, debouncedSearch, page } = usePagedSearch({
    pageSize: PAGE_SIZE,
    resetOn: [period, status, branchId],
  });

  /** Null until a branch is known, which keeps the list query off. */
  const filter = computed<InvoiceFilter | null>(() =>
    branchId.value
      ? {
          branchId: branchId.value,
          from: periodStart(period.value),
          status: status.value === FILTER_ALL ? undefined : (status.value as InvoiceStatus),
          search: debouncedSearch.value,
        }
      : null
  );

  return { search, period, status, page, filter };
};
