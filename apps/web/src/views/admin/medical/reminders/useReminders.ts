import { computed, ref, type Ref } from "vue";
import { useListFilters } from "@/composables/useListFilters";
import { useMarkReminded, useMedicalReminders } from "@/queries/vaccinations";
import { usePagedList } from "@/composables/usePagedList";
import { useAuthStore } from "@/stores";
import type { Reminder, ReminderFilter, ReminderScope } from "@bongcun/core/medical";

const PAGE_SIZE = 20;

/** The call list of a branch: the tab, the search, paging and the "called" note. */
export const useReminders = (branchId: Ref<string | undefined>) => {
  const auth = useAuthStore();
  const canMark = computed(() => auth.can("medical", "CREATE"));

  const scope = ref<ReminderScope>("due");
  const list = useListFilters({ pageSize: PAGE_SIZE, defaults: {}, resetOn: [branchId, scope] });
  const filter = computed<ReminderFilter>(() => ({ scope: scope.value, search: list.debouncedSearch.value }));

  const listQuery = useMedicalReminders(branchId, list.page, filter);
  const { rows, total, pageCount } = usePagedList(listQuery, list.page);

  // The reminder being marked as called.
  const marking = ref<Reminder | null>(null);
  const markMutation = useMarkReminded();
  const confirmMark = async (note: string) => {
    if (!marking.value?.vaccinationId) return;
    try {
      await markMutation.mutateAsync({ id: marking.value.vaccinationId, note });
      marking.value = null;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { ...list, scope, filter, listQuery, rows, total, pageCount, canMark, marking, confirmMark, markBusy: markMutation.isPending };
};
