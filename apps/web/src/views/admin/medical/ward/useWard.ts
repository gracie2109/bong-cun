import { computed, ref } from "vue";
import { useCurrentBranch } from "@/composables/useCurrentBranch";
import { useDischarge, useGiveDose, useInpatientWard, useStopOrder } from "@/queries/inpatient";
import { useAuthStore } from "@/stores";
import type { WardDose, WardRow } from "@/types/inpatient";
import { todayKey } from "../../boarding/format";

/** The ward of today: who is in, the doses to give, and the actions on a pet. */
export const useWard = () => {
  const auth = useAuthStore();
  const { branchId } = useCurrentBranch();
  const date = ref(todayKey());
  const query = useInpatientWard(branchId, date);
  const rows = computed(() => query.data.value?.rows ?? []);
  const canUpdate = computed(() => auth.can("medical", "UPDATE"));

  const give = useGiveDose();
  const stop = useStopOrder();
  const discharge = useDischarge();

  const orderFor = ref<WardRow | null>(null);
  const logFor = ref<WardRow | null>(null);
  const skipDose = ref<WardDose | null>(null);
  const dischargeRow = ref<WardRow | null>(null);

  const confirmDischarge = async () => {
    if (!dischargeRow.value) return;
    try {
      await discharge.mutateAsync(dischargeRow.value.stayId);
      dischargeRow.value = null;
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    branchId,
    date,
    query,
    rows,
    canUpdate,
    orderFor,
    logFor,
    skipDose,
    dischargeRow,
    giveDose: (dose: WardDose) => give.mutate(dose.id),
    stopOrder: (id: string) => stop.mutate(id),
    confirmDischarge,
    discharging: discharge.isPending,
  };
};
