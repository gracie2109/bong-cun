import { computed, ref, type Ref } from "vue";
import { useRouter } from "vue-router";
import { useMedicalQueue as useQueueQuery, useMarkNoShow, useStartVisit } from "@/features/admin/medical/queries/medicalVisits";
import { useAuthStore } from "@/stores";
import type { MedicalVisit } from "@bongcun/core/medical";
import { todayKey } from "../format";

/** Day queue of one branch: the date, the three columns, and what a click on a card does. */
export const useMedicalQueueView = (branchId: Ref<string | undefined>) => {
  const auth = useAuthStore();
  const router = useRouter();
  const canCreate = computed(() => auth.can("medical", "CREATE"));
  const canUpdate = computed(() => auth.can("medical", "UPDATE"));
  const canDelete = computed(() => auth.can("medical", "DELETE"));

  const date = ref(todayKey());
  const queueQuery = useQueueQuery(branchId, date);
  const queue = computed(() => queueQuery.data.value ?? null);
  const rows = computed(() => queue.value?.rows ?? []);

  // Booked visits of the day wait in the first column, dimmed, until the pet arrives.
  const waiting = computed(() => rows.value.filter((row) => row.status === "waiting" || row.status === "scheduled"));
  const inProgress = computed(() => rows.value.filter((row) => row.status === "in_progress"));
  const done = computed(() => rows.value.filter((row) => row.status === "done"));

  const checkInOpen = ref(false);
  /** The booked visit being checked in. */
  const checkInVisit = ref<MedicalVisit | null>(null);

  const openCheckIn = (visit: MedicalVisit | null = null) => {
    checkInVisit.value = visit;
    checkInOpen.value = true;
  };

  const openVisit = (visit: MedicalVisit) => router.push({ name: "medicalVisitDetail", params: { visitId: visit.id } });

  const start = useStartVisit();
  const takeCase = async (visit: MedicalVisit) => {
    try {
      await start.mutateAsync(visit.id);
      openVisit(visit);
    } catch {
      // the mutation already showed the failure toast
    }
  };

  const noShow = useMarkNoShow();

  return {
    queueQuery, queue, waiting, inProgress, done, date, canCreate, canUpdate, canDelete,
    checkInOpen, checkInVisit, openCheckIn, openVisit, takeCase, markNoShow: (visit: MedicalVisit) => noShow.mutate(visit.id),
  };
};
