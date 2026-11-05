import { computed, ref, watch, type Ref } from "vue";
import { useAttendanceRules, useSaveAttendanceRules } from "@/features/admin/attendance/queries";
import type { AttendanceRules } from "@bongcun/core/attendance";

const inRange = (value: number, min: number, max: number): boolean => Number.isInteger(value) && value >= min && value <= max;

/** The rules are valid when each number stays in the range the database accepts. */
export const rulesValid = (rules: AttendanceRules): boolean =>
  inRange(rules.lateGraceMinutes, 0, 60) &&
  inRange(rules.earlyGraceMinutes, 0, 60) &&
  inRange(rules.checkinEarlyMinutes, 0, 240) &&
  inRange(rules.overtimeMinMinutes, 0, 240) &&
  inRange(rules.reviewAfterHours, 4, 24);

/** Form state of the branch rules: starts from the database, tracks changes, saves. */
export const useAttendanceRulesForm = (branchId: Ref<string | undefined>) => {
  const query = useAttendanceRules(branchId);
  const mutation = useSaveAttendanceRules();

  const rules = ref<AttendanceRules | null>(null);
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
  const valid = computed(() => !!rules.value && rulesValid(rules.value));

  const save = () => {
    if (!branchId.value || !rules.value || !valid.value) return;
    mutation.mutate({ branchId: branchId.value, input: { ...rules.value } });
  };

  return { rules, dirty, valid, save, saving: mutation.isPending, loading: query.isPending };
};
