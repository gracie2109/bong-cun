import { computed, ref, watch, type Ref } from "vue";
import i18n from "@/i18n";
import { sendMessageToast } from "@/lib/utils";
import { useGiveVaccine as useGiveMutation, useVaccineLots } from "@/features/admin/medical/queries/vaccinations";
import type { VaccineBookEntry } from "@bongcun/core/medical";
import { useVaccineTypeOptions } from "../../book/useVaccineTypeOptions";
import { todayKey } from "../../format";
import { nextDue, suggestedDoseNo } from "../../nextDue";
import { emptyGiveDraft, toGiveInput, type GiveDraft } from "./giveDraft";

type Options = {
  open: Ref<boolean>;
  visitId: Ref<string>;
  branchId: Ref<string>;
  book: Ref<VaccineBookEntry[]>;
  close: () => void;
};

/** State of the "give a shot" dialog: the type, the batch, the shot number and the next due day. */
export const useGiveVaccine = ({ open, visitId, branchId, book, close }: Options) => {
  const draft = ref<GiveDraft>(emptyGiveDraft());
  watch(open, (isOpen) => isOpen && (draft.value = emptyGiveDraft()));

  const types = useVaccineTypeOptions(branchId);
  const type = computed(() => types.value.find((item) => item.id === draft.value.typeId));

  const lotsQuery = useVaccineLots(branchId, computed(() => (type.value?.productId ? draft.value.typeId : "")));
  const lots = computed(() => lotsQuery.data.value ?? []);

  // A new type brings its own shot number, its first batch (the one that expires first) and due day.
  watch(
    () => draft.value.typeId,
    (typeId) => {
      if (!typeId) return;
      draft.value.doseNo = String(suggestedDoseNo(typeId, book.value));
      draft.value.lotId = "";
      draft.value.dueEdited = false;
    }
  );
  watch(lots, (list) => {
    if (type.value?.productId && !draft.value.lotId) draft.value.lotId = list[0]?.id ?? "";
  });
  watch(
    () => [draft.value.typeId, draft.value.doseNo, type.value] as const,
    () => {
      if (draft.value.dueEdited) return;
      draft.value.nextDueOn = nextDue(type.value, Number(draft.value.doseNo) || 1, todayKey()) ?? "";
    }
  );

  const needsLot = computed(() => !!type.value?.productId);
  const noLots = computed(() => needsLot.value && !lotsQuery.isFetching.value && lots.value.length === 0);
  const valid = computed(() => !!draft.value.typeId && (!needsLot.value || !!draft.value.lotId));

  const mutation = useGiveMutation();
  const submit = async () => {
    if (!valid.value || mutation.isPending.value) return;
    try {
      const result = await mutation.mutateAsync({ visitId: visitId.value, input: toGiveInput(draft.value) });
      for (const warning of result.warnings) {
        sendMessageToast("fail", "create", "error", i18n.global.t(`medical.book.warnings.${warning}`));
      }
      close();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { draft, types, type, lots, needsLot, noLots, valid, saving: mutation.isPending, submit };
};
