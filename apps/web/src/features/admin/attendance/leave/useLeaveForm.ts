import { computed, ref, watch, type Ref } from "vue";
import { todayInVietnam } from "@/lib/businessDate";
import { useRequestLeave, useRequestLeaveFor } from "@/features/admin/attendance/queries";
import { emptyLeaveDraft, leaveDraftError, toRequestForInput, toRequestInput } from "./leaveDraft";

type Options = { open: Ref<boolean>; forStaff: Ref<boolean>; defaultBranchId: Ref<string | undefined>; onDone: () => void };

/** The "ask for leave" form: a person for themselves, or a manager filing for somebody (approved at once). */
export const useLeaveForm = ({ open, forStaff, defaultBranchId, onDone }: Options) => {
  const draft = ref(emptyLeaveDraft("", todayInVietnam()));
  const submitted = ref(false);
  const own = useRequestLeave();
  const other = useRequestLeaveFor();

  watch(open, (isOpen) => {
    if (!isOpen) return;
    draft.value = emptyLeaveDraft(defaultBranchId.value ?? "", todayInVietnam());
    submitted.value = false;
  });

  const busy = computed(() => own.isPending.value || other.isPending.value);
  const error = computed(() => (submitted.value ? leaveDraftError(draft.value, forStaff.value) : null));
  const singleDay = computed(() => draft.value.fromDate !== "" && draft.value.fromDate === draft.value.toDate);

  // Moving the start past the end drags the end along, as a date range picker does.
  watch(
    () => draft.value.fromDate,
    (from) => {
      if (from && draft.value.toDate < from) draft.value.toDate = from;
    }
  );

  const submit = async () => {
    submitted.value = true;
    if (leaveDraftError(draft.value, forStaff.value)) return;
    try {
      if (forStaff.value) await other.mutateAsync(toRequestForInput(draft.value));
      else await own.mutateAsync(toRequestInput(draft.value));
      onDone();
    } catch {
      // the mutation already showed why
    }
  };

  return { draft, busy, error, singleDay, submit };
};
