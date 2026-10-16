import { computed, ref, watch } from "vue";
import { useMyPets, useMyProfile } from "@/queries/account";
import { useBranches } from "@/queries/branches";
import { useBookAppointment, useSpaWebQuote, useSpaWebRules, useSpaWebSlots } from "@/queries/spaWeb";
import { useSpaPublicCatalog } from "@/queries/spaCatalog";
import type { BookingPick, BookingResult, BookingStep } from "@/types/spaWeb";
import {
  bookingSteps,
  businessDate,
  togglePick,
  toBookingItems,
  type PicksByPet,
} from "@/utils/spa/booking";

/** State and rules of the four-step booking wizard: branch, pets and services, time, confirm. */
export const useBookingWizard = () => {
  const profile = useMyProfile();
  const hasCustomer = computed(() => Boolean(profile.data.value?.customerId));
  const petsQuery = useMyPets(hasCustomer);
  const branchesQuery = useBranches();
  const rules = useSpaWebRules();

  const branches = computed(() => branchesQuery.data.value ?? []);
  const steps = computed(() => bookingSteps(branches.value.length));
  const step = ref<BookingStep | null>(null);
  const current = computed<BookingStep>(() => step.value ?? steps.value[0]);
  const stepIndex = computed(() => steps.value.indexOf(current.value));

  const pickedBranch = ref<string | null>(null);
  const branchId = computed(() => pickedBranch.value ?? branches.value[0]?.id ?? null);
  const catalogQuery = useSpaPublicCatalog(branchId);

  const pets = computed(() => petsQuery.data.value ?? []);
  const picks = ref<PicksByPet>({});
  const petOrder = computed(() => pets.value.map((pet) => pet.id).filter((id) => picks.value[id]));
  const items = computed(() => toBookingItems(picks.value, petOrder.value));

  const quoteQuery = useSpaWebQuote(branchId, items);
  const quote = computed(() => quoteQuery.data.value ?? null);
  const totalMinutes = computed(() => quote.value?.totalMinutes ?? 0);

  const date = ref(businessDate());
  const slotsQuery = useSpaWebSlots(branchId, date, totalMinutes);
  const slots = computed(() => slotsQuery.data.value ?? []);
  const startAt = ref<string | null>(null);
  const note = ref("");

  const mutation = useBookAppointment();
  const result = ref<BookingResult | null>(null);

  // A different day, branch or length invalidates the chosen time.
  watch([date, branchId, totalMinutes], () => (startAt.value = null));
  // Another branch has its own prices and (possibly) its own services.
  watch(branchId, () => (picks.value = {}));

  const canNext = computed(() => {
    if (current.value === "branch") return Boolean(branchId.value);
    if (current.value === "pets") return items.value.length > 0 && Boolean(quote.value) && !quoteQuery.isError.value;
    if (current.value === "slot") return Boolean(startAt.value);
    return false;
  });

  const go = (delta: number) => {
    const next = steps.value[stepIndex.value + delta];
    if (next) step.value = next;
  };

  const submit = async () => {
    if (!branchId.value || !startAt.value) return;
    try {
      result.value = await mutation.mutateAsync({
        branchId: branchId.value,
        startAt: startAt.value,
        note: note.value,
        items: items.value,
      });
    } catch {
      // the mutation already showed the failure toast; the slots were refreshed
      startAt.value = null;
      step.value = "slot";
    }
  };

  return {
    // readiness
    loading: computed(() => profile.isLoading.value || branchesQuery.isLoading.value || (hasCustomer.value && petsQuery.isLoading.value)),
    hasCustomer,
    pets,
    branches,
    rules,
    catalog: computed(() => catalogQuery.data.value ?? null),
    // steps
    steps,
    current,
    stepIndex,
    canNext,
    next: () => go(1),
    back: () => go(-1),
    // choices
    branchId,
    pickBranch: (id: string) => (pickedBranch.value = id),
    picks,
    toggle: (petId: string, pick: BookingPick) => (picks.value = togglePick(picks.value, petId, pick)),
    quote,
    quoting: quoteQuery.isFetching,
    quoteFailed: quoteQuery.isError,
    date,
    slots,
    slotsLoading: slotsQuery.isFetching,
    startAt,
    note,
    // result
    saving: mutation.isPending,
    submit,
    result,
  };
};
