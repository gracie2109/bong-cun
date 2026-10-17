import { computed, ref, watch, type Ref } from "vue";
import { useBoardingRules, useSaveBoardingRules } from "@/features/admin/boarding/queries";
import type { BoardingRules } from "@bongcun/core/boarding";

/** The nights a same-day stay can be charged as. */
export const DAY_STAY_OPTIONS = [0.5, 1] as const;

/** Form state of the check-in / check-out rules: starts from the database, tracks changes, saves. */
export const useRulesForm = (branchId: Ref<string | undefined>) => {
  const query = useBoardingRules(branchId);
  const mutation = useSaveBoardingRules();

  const rules = ref<BoardingRules | null>(null);
  const saved = ref("");

  // A branch switch or a refetch resets the form.
  watch(
    () => query.data.value,
    (data) => {
      rules.value = data ? { ...data } : null;
      saved.value = JSON.stringify(rules.value);
    },
    { immediate: true }
  );

  const dirty = computed(() => JSON.stringify(rules.value) !== saved.value);

  /** The rules are consistent when the free check-out time comes before the half-night limit. */
  const valid = computed(() => {
    const value = rules.value;
    return !!value && value.checkOutBy < value.lateHalfUntil && value.maxNights >= 1 && value.maxNights <= 365;
  });

  const save = () => {
    if (!branchId.value || !rules.value || !valid.value) return;
    mutation.mutate({ branchId: branchId.value, rules: rules.value });
  };

  return { rules, dirty, valid, save, saving: mutation.isPending, loading: query.isPending };
};
