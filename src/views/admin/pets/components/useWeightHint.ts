import { computed, type Ref } from "vue";
import { useI18n } from "vue-i18n";
import { useWeightBrackets } from "@/queries/weightBrackets";
import { findBracket } from "@/repositories/weightBrackets";

/** Parses the typed weight and says which weight bracket of the species it falls in. */
export const useWeightHint = (speciesId: Ref<string | undefined>, weight: Ref<string>) => {
  const { t } = useI18n();

  const bracketsQuery = useWeightBrackets(speciesId, { enabled: computed(() => !!speciesId.value) });
  const weightKg = computed(() => (weight.value === "" ? null : Number(weight.value)));
  const weightInvalid = computed(
    () => weightKg.value !== null && (Number.isNaN(weightKg.value) || weightKg.value <= 0)
  );
  const bracket = computed(() =>
    weightKg.value !== null && !weightInvalid.value && speciesId.value
      ? findBracket(bracketsQuery.data.value ?? [], weightKg.value)
      : undefined
  );
  const bracketText = computed(() => {
    if (weightKg.value === null || weightInvalid.value || !speciesId.value) return "";
    return bracket.value
      ? t("petCare.pets.fields.weightBracket", { label: bracket.value.label })
      : t("petCare.pets.fields.noBracket");
  });

  return { weightKg, weightInvalid, bracket, bracketText };
};
