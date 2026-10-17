import { computed, ref, type Ref } from "vue";
import { useRouter } from "vue-router";
import { useBoardingBoard as useBoardQuery, useSetKennelStatus } from "@/features/admin/boarding/queries";
import { useAuthStore } from "@/stores";
import type { BoardKennel } from "@bongcun/core/boarding";
import { todayKey } from "../format";
import type { StayPrefill } from "../stay-dialog/stayDraft";

/** Day board of one branch: the date, the kennels grouped by type, and what a click on a kennel opens. */
export const useBoardingBoardView = (branchId: Ref<string | undefined>) => {
  const auth = useAuthStore();
  const router = useRouter();
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

  // The booking dialog, opened on a free kennel with the day and kennel filled in.
  const dialogOpen = ref(false);
  const prefill = ref<StayPrefill>();

  const openNew = (kennel?: BoardKennel) => {
    prefill.value = { date: date.value, kennelId: kennel?.id, kennelTypeId: kennel?.kennelTypeId };
    dialogOpen.value = true;
  };

  const canViewMedical = computed(() => auth.can("medical", "VIEW"));

  /**
   * A kennel with a pet or a booked arrival opens that stay (an inpatient opens the Inpatient screen when the
   * staff may see it); a free, ready hotel kennel starts a booking. A free medical kennel opens nothing:
   * inpatients are admitted from the visit.
   */
  const openKennel = (kennel: BoardKennel) => {
    const stay = kennel.pets[0] ?? kennel.arriving[0];
    if (stay?.kind === "inpatient" && canViewMedical.value) {
      router.push({ name: "medicalWard" });
      return;
    }
    if (stay) {
      router.push({ name: "boardingStayDetail", params: { stayId: stay.stayId } });
      return;
    }
    if (kennel.purpose === "boarding" && kennel.state === "free" && kennel.status === "ready" && canCreate.value) openNew(kennel);
  };

  const setStatus = useSetKennelStatus();
  const markClean = (kennel: BoardKennel) => setStatus.mutate({ id: kennel.id, status: "ready" });

  return { date, board, boardQuery, groups, canCreate, canUpdate, dialogOpen, prefill, openNew, openKennel, markClean };
};
