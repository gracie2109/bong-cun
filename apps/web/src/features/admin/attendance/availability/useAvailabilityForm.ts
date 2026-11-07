import { computed, ref, watch, type Ref } from "vue";
import { useAvailability, useSaveAvailability } from "@/features/admin/attendance/queries";
import { draftIssue, fromDraftRows, newDraftRow, toDraftRows } from "./availabilityDraft";

type Options = { open: Ref<boolean>; userId: Ref<string | undefined>; onDone: () => void; confirm?: () => Promise<boolean> };

/** Editing the weekly pattern: load when the dialog opens, add and remove rows, save everything at once. */
export const useAvailabilityForm = ({ open, userId, onDone, confirm }: Options) => {
  const query = useAvailability(userId);
  const save = useSaveAvailability();
  const rows = ref(toDraftRows([]));
  const submitted = ref(false);

  watch(
    [open, () => query.data.value],
    ([isOpen, data]) => {
      if (!isOpen || !data) return;
      rows.value = toDraftRows(data);
      submitted.value = false;
    },
    { immediate: true }
  );

  const issue = computed(() => (submitted.value ? draftIssue(rows.value) : null));
  const add = (weekday: number) => rows.value.push(newDraftRow(weekday));
  const remove = (key: number) => {
    rows.value = rows.value.filter((row) => row.key !== key);
  };

  const submit = async () => {
    submitted.value = true;
    if (draftIssue(rows.value)) return;
    if (confirm && !(await confirm())) return;
    try {
      await save.mutateAsync({ userId: userId.value, items: fromDraftRows(rows.value) });
      onDone();
    } catch {
      // the mutation already showed why
    }
  };

  return { rows, issue, busy: save.isPending, loading: query.isLoading, add, remove, submit };
};
