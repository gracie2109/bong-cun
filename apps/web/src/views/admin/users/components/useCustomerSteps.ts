import { computed, ref } from "vue";
import type { FormContext } from "vee-validate";
import { MapPin, User, Users } from "lucide-vue-next";
import type { IUser } from "@/types/user.type";

export const STEP = { INFO: "info", GROUPS: "groups", ADDRESS: "address" } as const;
export type Step = (typeof STEP)[keyof typeof STEP];

export const STEPS = [
  { id: STEP.INFO, icon: User },
  { id: STEP.GROUPS, icon: Users },
  { id: STEP.ADDRESS, icon: MapPin },
];

/** Fields that must be valid before leaving the first step. */
const INFO_FIELDS = ["fullName", "displayName", "phoneNumber", "email", "password"] as const;

/** The steps of the customer form; moving on from the first needs its fields to be valid. */
export const useCustomerSteps = (form: FormContext<IUser>) => {
  const step = ref<Step>(STEP.INFO);
  const stepIndex = computed(() => STEPS.findIndex((s) => s.id === step.value));
  const isLastStep = computed(() => stepIndex.value === STEPS.length - 1);

  const validateInfo = async (): Promise<boolean> => {
    const results = await Promise.all(INFO_FIELDS.map((field) => form.validateField(field)));
    return results.every((result) => result.valid);
  };

  const goTo = async (next: unknown) => {
    const target = next as Step;
    const targetIndex = STEPS.findIndex((s) => s.id === target);
    if (targetIndex > 0 && stepIndex.value === 0 && !(await validateInfo())) return;
    step.value = target;
  };
  const goNext = () => goTo(STEPS[stepIndex.value + 1].id);
  const goBack = () => {
    step.value = STEPS[stepIndex.value - 1].id;
  };

  return { step, stepIndex, isLastStep, validateInfo, goTo, goNext, goBack };
};
