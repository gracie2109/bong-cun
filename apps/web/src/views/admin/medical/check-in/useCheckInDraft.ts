import { computed, ref, watch, type Ref } from "vue";
import { useCustomerPets } from "@/queries/pos";
import { useCheckInVisit, useMedicalVets, useScheduleVisit } from "@/queries/medicalVisits";
import type { MedicalVisit } from "@bongcun/core/medical";
import type { Buyer } from "@/views/admin/pos/components/CustomerPanel.vue";
import {
  draftFromVisit,
  emptyCheckInDraft,
  isCheckInDraftComplete,
  toCheckInInput,
  toScheduleInput,
  type CheckInDraft,
} from "./checkInDraft";

type Options = {
  open: Ref<boolean>;
  branchId: Ref<string>;
  /** The booked visit that is arriving; null = a new visit. */
  visit: Ref<MedicalVisit | null>;
  close: () => void;
};

/** State and actions of the check-in dialog: who comes with which pet, and the visit it creates. */
export const useCheckInDraft = ({ open, branchId, visit, close }: Options) => {
  const buyer = ref<Buyer | null>(null);
  const draft = ref<CheckInDraft>(emptyCheckInDraft());

  const customerId = computed(() => visit.value?.customerId ?? buyer.value?.customerId ?? null);
  const petsQuery = useCustomerPets(customerId);
  const pets = computed(() => petsQuery.data.value ?? []);
  const needsPets = computed(
    () => !!buyer.value && !visit.value && (!buyer.value.customerId || (!petsQuery.isFetching.value && pets.value.length === 0))
  );
  const vetsQuery = useMedicalVets(branchId);
  const vets = computed(() => vetsQuery.data.value ?? []);

  // Every opening starts from the arriving booked visit, or from an empty form.
  watch(
    open,
    (isOpen) => {
      if (!isOpen) return;
      buyer.value = null;
      draft.value = visit.value ? draftFromVisit(visit.value) : emptyCheckInDraft();
    },
    { immediate: true }
  );

  // The pet's last weight is a good first guess for the scale.
  watch(
    () => draft.value.petId,
    (petId) => {
      if (visit.value || draft.value.weight) return;
      const weight = pets.value.find((pet) => pet.id === petId)?.weightKg;
      if (weight) draft.value.weight = String(weight);
    }
  );

  const valid = computed(() => !!customerId.value && !needsPets.value && isCheckInDraftComplete(draft.value));

  const checkIn = useCheckInVisit();
  const schedule = useScheduleVisit();
  const saving = computed(() => checkIn.isPending.value || schedule.isPending.value);

  const submit = async () => {
    if (!valid.value || !customerId.value || saving.value) return;
    try {
      if (draft.value.mode === "book" && !visit.value) {
        await schedule.mutateAsync({ input: toScheduleInput(branchId.value, customerId.value, draft.value) });
      } else {
        await checkIn.mutateAsync(toCheckInInput(branchId.value, customerId.value, draft.value, visit.value?.id));
      }
      close();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return { buyer, draft, customerId, pets, needsPets, vets, valid, saving, submit };
};
