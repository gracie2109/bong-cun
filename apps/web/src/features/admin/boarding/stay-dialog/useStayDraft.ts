import { computed, ref, watch, type Ref } from "vue";
import { refDebounced } from "@vueuse/core";
import {
  useBoardingQuote,
  useBoardingRules,
  useCancelBoardingStay,
  useSaveBoardingStay,
  useTypeAvailability,
} from "@/features/admin/boarding/queries";
import { useCustomerPets } from "@/features/admin/pos/queries/pos";
import { boardingErrorDetail, boardingErrorHint } from "@bongcun/supabase/boarding";
import type { BoardingStay } from "@bongcun/core/boarding";
import type { Buyer } from "@/features/admin/pos/components/CustomerPanel.vue";
import { useKennelTypeOptions } from "../useKennelTypeOptions";
import {
  draftFromStay,
  emptyStayDraft,
  isStayDraftComplete,
  newPetDraft,
  NONE,
  toStayInput,
  type StayDraft,
  type StayPrefill,
} from "./stayDraft";

const QUOTE_DEBOUNCE_MS = 400;

type Options = {
  open: Ref<boolean>;
  branchId: Ref<string>;
  stay: Ref<BoardingStay | null>;
  prefill: Ref<StayPrefill | undefined>;
  close: () => void;
};

/** State and actions of the booking dialog: the draft, the live quote, saving and cancelling. */
export const useStayDraft = ({ open, branchId, stay, prefill, close }: Options) => {
  const buyer = ref<Buyer | null>(null);
  const draft = ref<StayDraft>(emptyStayDraft(undefined));
  const confirmCancel = ref(false);

  const customerId = computed(() => stay.value?.customerId ?? buyer.value?.customerId ?? null);

  const petsQuery = useCustomerPets(customerId);
  const pets = computed(() => petsQuery.data.value ?? []);
  const needsPets = computed(
    () => !!buyer.value && !stay.value && (!buyer.value.customerId || (!petsQuery.isFetching.value && pets.value.length === 0))
  );

  const rulesQuery = useBoardingRules(branchId);
  const types = useKennelTypeOptions(computed(() => branchId.value));
  const availabilityQuery = useTypeAvailability(
    branchId,
    computed(() => draft.value.inDate),
    computed(() => draft.value.outDate)
  );
  const availability = computed(() => availabilityQuery.data.value ?? []);

  // Every opening starts from the stay being edited, or from an empty form with the branch's hours.
  watch(
    [open, () => rulesQuery.data.value],
    ([isOpen], [wasOpen]) => {
      if (!isOpen) return;
      if (wasOpen && isOpen) return;
      confirmCancel.value = false;
      buyer.value = null;
      draft.value = stay.value ? draftFromStay(stay.value) : emptyStayDraft(rulesQuery.data.value, prefill.value);
    },
    { immediate: true }
  );

  const complete = computed(() => !!customerId.value && !needsPets.value && isStayDraftComplete(draft.value));
  const input = computed(() => (complete.value && customerId.value ? toStayInput(customerId.value, draft.value) : null));
  const debouncedInput = refDebounced(input, QUOTE_DEBOUNCE_MS);

  const quoteQuery = useBoardingQuote(branchId, computed(() => stay.value?.id), debouncedInput);
  const quote = computed(() => (debouncedInput.value ? quoteQuery.data.value ?? null : null));
  const quoting = computed(() => !!input.value && (input.value !== debouncedInput.value || quoteQuery.isFetching.value));
  const quoteError = computed(() => {
    if (!debouncedInput.value || !quoteQuery.error.value) return null;
    const hint = boardingErrorHint(quoteQuery.error.value);
    return { hint, name: boardingErrorDetail(quoteQuery.error.value), message: (quoteQuery.error.value as Error).message };
  });

  const valid = computed(() => complete.value && !!quote.value && !quoteError.value && !quoting.value);

  const addPet = () => {
    const last = draft.value.pets.at(-1);
    draft.value.pets.push(newPetDraft({ kennelTypeId: last?.kennelTypeId ?? "" }));
  };

  const removePet = (index: number) => {
    draft.value.pets.splice(index, 1);
    // A line that shared a kennel with the removed (or a later) line loses that link.
    for (const pet of draft.value.pets) {
      if (pet.shareWith !== NONE && Number(pet.shareWith) > draft.value.pets.length) pet.shareWith = NONE;
    }
  };

  const saveMutation = useSaveBoardingStay();
  const cancelMutation = useCancelBoardingStay();
  const saving = computed(() => saveMutation.isPending.value || cancelMutation.isPending.value);

  const submit = async () => {
    if (!valid.value || !input.value) return;
    try {
      await saveMutation.mutateAsync({ branchId: branchId.value, input: input.value, id: stay.value?.id });
      close();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  const cancelStay = async () => {
    if (!stay.value) return;
    try {
      await cancelMutation.mutateAsync({ id: stay.value.id });
      close();
    } catch {
      // the mutation already showed the failure toast
    }
  };

  return {
    buyer, draft, confirmCancel, customerId, pets, needsPets, types, availability, rules: computed(() => rulesQuery.data.value),
    quote, quoting, quoteError, valid, saving, addPet, removePet, submit, cancelStay,
  };
};
