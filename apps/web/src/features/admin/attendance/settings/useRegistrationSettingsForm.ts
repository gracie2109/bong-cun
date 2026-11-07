import { computed, ref, watch, type Ref } from "vue";
import { useRegistrationRules, useSaveRegistrationSettings } from "@/features/admin/attendance/queries";
import type { RegistrationSettingsInput } from "@bongcun/core/attendance";

type Form = { isOpen: boolean; weeksAhead: number; closeDaysBefore: number; limited: boolean; maxShiftsPerWeek: number; staffNote: string; requirePublish: boolean; publishExisting: boolean };

const inRange = (value: number, min: number, max: number) => Number.isInteger(value) && value >= min && value <= max;

export const registrationFormValid = (form: Form): boolean =>
  inRange(form.weeksAhead, 1, 6) &&
  inRange(form.closeDaysBefore, 0, 14) &&
  (!form.limited || inRange(form.maxShiftsPerWeek, 1, 21)) &&
  form.staffNote.length <= 300;

export const toRegistrationInput = (form: Form): RegistrationSettingsInput => ({
  isOpen: form.isOpen,
  weeksAhead: form.weeksAhead,
  closeDaysBefore: form.closeDaysBefore,
  maxShiftsPerWeek: form.limited ? form.maxShiftsPerWeek : null,
  staffNote: form.staffNote.trim() || null,
  requirePublish: form.requirePublish,
  // Only meaningful while switching publishing on.
  publishExisting: form.requirePublish && form.publishExisting,
});

/** Form state of the registration window of a branch: starts from the database, tracks changes, saves. */
export const useRegistrationSettingsForm = (branchId: Ref<string | undefined>, confirm?: () => Promise<boolean>) => {
  const query = useRegistrationRules(branchId);
  const mutation = useSaveRegistrationSettings();
  const form = ref<Form | null>(null);
  const saved = ref("");

  watch(
    () => query.data.value,
    (rules) => {
      form.value = rules
        ? {
            isOpen: rules.isOpen,
            weeksAhead: rules.weeksAhead,
            closeDaysBefore: rules.closeDaysBefore,
            limited: rules.maxShiftsPerWeek !== null,
            maxShiftsPerWeek: rules.maxShiftsPerWeek ?? 5,
            staffNote: rules.staffNote ?? "",
            requirePublish: rules.requirePublish,
            publishExisting: true,
          }
        : null;
      saved.value = JSON.stringify(form.value);
    },
    { immediate: true }
  );

  /** Publishing is being switched on by this edit (it was off in the database). */
  const switchingOn = computed(() => !!form.value && form.value.requirePublish && query.data.value?.requirePublish === false);

  const dirty = computed(() => JSON.stringify(form.value) !== saved.value);
  const valid = computed(() => !!form.value && registrationFormValid(form.value));
  const save = async () => {
    if (!branchId.value || !form.value || !valid.value) return;
    if (confirm && !(await confirm())) return;
    mutation.mutate({ branchId: branchId.value, input: toRegistrationInput(form.value) });
  };

  return { form, switchingOn, dirty, valid, save, saving: mutation.isPending, loading: query.isPending };
};
