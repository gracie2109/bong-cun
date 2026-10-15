import { computed, ref } from "vue";
import { useRoute } from "vue-router";
import { useCancelVisit, useMedicalVisit, useMarkNoShow, useStartVisit } from "@/queries/medicalVisits";
import { useAuthStore } from "@/stores";

/** The visit of the route with what the signed-in staff may do to it, and the actions on it. */
export const useVisitDetail = () => {
  const route = useRoute();
  const auth = useAuthStore();
  const visitId = computed(() => String(route.params.visitId));

  const visitQuery = useMedicalVisit(visitId);
  const visit = computed(() => visitQuery.data.value ?? null);

  const canCreate = computed(() => auth.can("medical", "CREATE"));
  const canUpdate = computed(() => auth.can("medical", "UPDATE"));
  const canCancel = computed(() => auth.can("medical", "DELETE"));

  const status = computed(() => visit.value?.status);
  /** The record can be written while the case is open and unsigned. */
  const canEditRecord = computed(() => canUpdate.value && status.value === "in_progress" && !visit.value?.signedAt);

  const cancelOpen = ref(false);

  const start = useStartVisit();
  const startVisit = () => visit.value && start.mutate(visit.value.id);

  const cancel = useCancelVisit();
  const cancelVisit = async (reason: string) => {
    if (!visit.value) return;
    try {
      await cancel.mutateAsync({ id: visit.value.id, reason });
      cancelOpen.value = false;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  const noShow = useMarkNoShow();
  const markNoShow = () => visit.value && noShow.mutate(visit.value.id);

  return {
    visitQuery, visit, canCreate, canUpdate, canCancel, canEditRecord,
    cancelOpen, startVisit, cancelVisit, cancelling: cancel.isPending, markNoShow,
  };
};
