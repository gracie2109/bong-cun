import i18n from "@/i18n";
import { useConfirmAction } from "@/components/common/useConfirmAction";
import { computed, ref, watch } from "vue";
import { useCancelShiftRequest, useClockStatus, useRegistrationBoard, useSubmitShiftRequests } from "@/features/admin/attendance/queries";
import type { SubmitResult } from "@bongcun/core/attendance";
import { remainingQuota } from "./registerGrid";
import { useRegisterSelection } from "./useRegisterSelection";
import { useRegisterWeek } from "./useRegisterWeek";

/** Everything the registration page needs: branch, week, the board, the ticks and the send action. */
export const useRegisterPage = () => {
  const status = useClockStatus();
  // The picker shows the branches the person works at; the contact fields are not needed here.
  const branches = computed(() => (status.data.value?.branches ?? []).map((branch) => ({ ...branch, address: null, phone: null, isActive: true })));
  const chosen = ref<string>();
  const branchId = computed(() => chosen.value ?? branches.value[0]?.id);

  const week = useRegisterWeek();
  const query = useRegistrationBoard(branchId, week.monday);
  const board = computed(() => query.data.value);

  const selection = useRegisterSelection(computed(() => `${branchId.value}|${week.monday.value}`));
  const note = ref("");
  watch(() => week.monday.value, () => (note.value = ""));

  const quota = computed(() => (board.value && branchId.value ? remainingQuota(board.value, branchId.value) : null));
  const overQuota = computed(() => quota.value !== null && selection.count.value > quota.value);

  const confirm = useConfirmAction();
  const submit = useSubmitShiftRequests();
  const cancel = useCancelShiftRequest();
  const result = ref<SubmitResult | null>(null);
  const resultOpen = ref(false);

  const send = async () => {
    if (!branchId.value || !selection.count.value || overQuota.value) return;
    try {
      result.value = await submit.mutateAsync({
        branchId: branchId.value,
        monday: week.monday.value,
        cells: selection.cells.value,
        note: note.value.trim() || null,
      });
      selection.clear();
      note.value = "";
      resultOpen.value = true;
    } catch {
      // the mutation already showed why
    }
  };

  return {
    branches,
    branchId,
    selectBranch: (id: string) => (chosen.value = id),
    week,
    query,
    board,
    selection,
    note,
    quota,
    overQuota,
    sending: submit.isPending,
    confirm,
    cancel: async (id: string) => {
      const answer = await confirm.ask({
        title: i18n.global.t("attendance.confirm.cancelRequest.title"),
        message: i18n.global.t("attendance.confirm.cancelRequest.message"),
        danger: true,
      });
      if (answer.ok) cancel.mutate(id);
    },
    send,
    result,
    resultOpen,
  };
};
