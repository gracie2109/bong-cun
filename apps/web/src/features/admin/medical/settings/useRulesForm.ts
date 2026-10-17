import { computed, ref, watch, type Ref } from "vue";
import { useMedicalRules, useSaveMedicalRules } from "@/features/admin/medical/queries/medical";
import type { MedicalRules } from "@bongcun/core/medical";

/** Form state of the medical rules: starts from the database, tracks changes, saves. */
export const useRulesForm = (branchId: Ref<string | undefined>) => {
  const query = useMedicalRules(branchId);
  const mutation = useSaveMedicalRules();

  const rules = ref<MedicalRules | null>(null);
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

  const valid = computed(() => {
    const value = rules.value;
    return !!value && value.remindAheadDays >= 0 && value.remindAheadDays <= 90 && value.contagiousDays >= 1 && value.contagiousDays <= 365;
  });

  const save = () => {
    if (!branchId.value || !rules.value || !valid.value) return;
    mutation.mutate({ branchId: branchId.value, rules: rules.value });
  };

  return { rules, dirty, valid, save, saving: mutation.isPending, loading: query.isPending };
};
