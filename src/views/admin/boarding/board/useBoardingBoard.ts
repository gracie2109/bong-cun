import { computed, ref, watch, type Ref } from "vue";
import { useBoardingBoard as useBoardQuery, useBoardingStay, useSetKennelStatus } from "@/queries/boarding";
import { useAuthStore } from "@/stores";
import type { BoardKennel } from "@/types/boarding";
import { todayKey } from "../format";
import type { StayPrefill } from "../stay-dialog/stayDraft";

/** Day board of one branch: the date, the kennels grouped by type, and what a click on a kennel opens. */
export const useBoardingBoardView = (branchId: Ref<string | undefined>) => {
  const auth = useAuthStore();
  const canCreate = computed(() => auth.can("boarding", "CREATE"));
  const canUpdate = computed(() => auth.can("boarding", "UPDATE"));

  const date = ref(todayKey());
  const boardQuery = useBoardQuery(branchId, date);
  const board = computed(() => boardQuery.data.value ?? null);

  const groups = computed(() => {
    const byType = new Map<string, { id: string; name: string; kennels: BoardKennel[] }>();
    for (const kennel of board.value?.kennels ?? []) {
      const group = byType.get(kennel.kennelTypeId) ?? { id: kennel.kennelTypeId, name: kennel.kennelTypeName, kennels: [] };
      group.kennels.push(kennel);
      byType.set(kennel.kennelTypeId, group);
    }
    return [...byType.values()];
  });

  // The booking dialog: new (with the kennel and date prefilled) or editing a booked stay.
  const dialogOpen = ref(false);
  const editingId = ref<string>();
  const prefill = ref<StayPrefill>();
  const stayQuery = useBoardingStay(editingId);
  const editing = computed(() => (editingId.value ? (stayQuery.data.value ?? null) : null));
  // Wait for the stay before opening the editor so the draft starts from it.
  const pendingEdit = ref(false);
  watch([() => stayQuery.data.value, pendingEdit], ([stay, pending]) => {
    if (pending && stay) {
      pendingEdit.value = false;
      dialogOpen.value = true;
    }
  });

  const openNew = (kennel?: BoardKennel) => {
    editingId.value = undefined;
    prefill.value = { date: date.value, kennelId: kennel?.id, kennelTypeId: kennel?.kennelTypeId };
    dialogOpen.value = true;
  };

  /** Free kennels start a booking, a booked arrival opens it for editing; stays in the kennel open in step 3. */
  const openKennel = (kennel: BoardKennel) => {
    const arriving = kennel.arriving[0];
    if (arriving && canUpdate.value && arriving.stayStatus === "booked") {
      editingId.value = arriving.stayId;
      pendingEdit.value = true;
      if (stayQuery.data.value?.id === arriving.stayId) {
        pendingEdit.value = false;
        dialogOpen.value = true;
      }
      return;
    }
    if (kennel.state === "free" && kennel.status === "ready" && canCreate.value) openNew(kennel);
  };

  const setStatus = useSetKennelStatus();
  const markClean = (kennel: BoardKennel) => setStatus.mutate({ id: kennel.id, status: "ready" });

  return { date, board, boardQuery, groups, canCreate, canUpdate, dialogOpen, editing, prefill, openNew, openKennel, markClean };
};
