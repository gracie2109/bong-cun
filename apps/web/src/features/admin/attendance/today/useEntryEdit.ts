import { computed, ref, type Ref } from "vue";
import { useAddEntry, useDeleteEntry, useEditEntry, useReviewEntry } from "@/features/admin/attendance/queries";
import type { AttendanceRow } from "@bongcun/core/attendance";
import { draftError, draftFromRow, emptyDraft, toAddInput, toEditInput } from "./entryDraft";

/** The correction dialog: edit an entry, record a missed one on a shift, or delete one. */
export const useEntryEdit = (branchId: Ref<string | undefined>) => {
  const open = ref(false);
  const row = ref<AttendanceRow | null>(null);
  const draft = ref(emptyDraft());
  const submitted = ref(false);

  const add = useAddEntry();
  const edit = useEditEntry();
  const remove = useDeleteEntry();
  const review = useReviewEntry();

  const isNew = computed(() => row.value !== null && row.value.entryId === null);
  const busy = computed(() => add.isPending.value || edit.isPending.value || remove.isPending.value);
  const error = computed(() => (submitted.value ? draftError(draft.value) : null));

  const openFor = (target: AttendanceRow) => {
    row.value = target;
    draft.value = draftFromRow(target);
    submitted.value = false;
    open.value = true;
  };

  /** From the review queue: only the entry id is known, so the row is looked up on the board. */
  const openForEntry = (entryId: string, rows: AttendanceRow[]) => {
    const target = rows.find((item) => item.entryId === entryId);
    if (target) openFor(target);
  };

  const submit = async () => {
    submitted.value = true;
    const target = row.value;
    if (!target || draftError(draft.value)) return;
    try {
      if (target.entryId) await edit.mutateAsync(toEditInput(target.entryId, target.assignmentId, draft.value));
      else if (branchId.value) await add.mutateAsync(toAddInput(branchId.value, target.userId, target.assignmentId, draft.value));
      open.value = false;
    } catch {
      // the mutation already showed why
    }
  };

  const removeEntry = async () => {
    const target = row.value;
    if (!target?.entryId) return;
    submitted.value = true;
    if (!draft.value.reason.trim()) return;
    try {
      await remove.mutateAsync({ id: target.entryId, reason: draft.value.reason.trim() });
      open.value = false;
    } catch {
      // the mutation already showed why
    }
  };

  return { open, row, draft, isNew, busy, error, openFor, openForEntry, submit, removeEntry, markReviewed: (id: string) => review.mutate(id) };
};
