import { computed, ref, watch, type Ref } from "vue";
import { useScheduleHistory } from "@/features/admin/attendance/queries";
import type { HistoryEntity, HistoryFilter } from "@bongcun/core/attendance";

const PAGE_SIZE = 30;

/** The manager's history: one branch, an optional person, kind, date range and "after publishing" switch. */
export const useHistoryList = (branchId: Ref<string | undefined>) => {
  const from = ref("");
  const to = ref("");
  const userId = ref("");
  const entity = ref<HistoryEntity | "">("");
  const publishedOnly = ref(false);
  const page = ref(1);

  watch([branchId, from, to, userId, entity, publishedOnly], () => (page.value = 1));

  const filter = computed<HistoryFilter>(() => ({
    branchId: branchId.value ?? null,
    from: from.value || null,
    to: to.value || null,
    userId: userId.value || null,
    entity: entity.value || null,
    publishedOnly: publishedOnly.value,
  }));

  const query = useScheduleHistory(filter, page, PAGE_SIZE);
  const rows = computed(() => query.data.value?.rows ?? []);
  const pageCount = computed(() => Math.max(1, Math.ceil((query.data.value?.total ?? 0) / PAGE_SIZE)));

  return { from, to, userId, entity, publishedOnly, page, query, rows, pageCount };
};
