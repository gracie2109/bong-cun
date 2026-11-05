import { ref } from "vue";
import type { RosterAssignment, RosterStaff } from "@bongcun/core/attendance";

/** Which cell the shift dialog is open for: a new shift, or an existing one. */
export const useAssignDialog = () => {
  const open = ref(false);
  const staff = ref<RosterStaff | null>(null);
  const date = ref("");
  const assignment = ref<RosterAssignment | null>(null);

  const show = (person: RosterStaff, day: string, existing: RosterAssignment | null) => {
    staff.value = person;
    date.value = day;
    assignment.value = existing;
    open.value = true;
  };

  return { open, staff, date, assignment, add: (person: RosterStaff, day: string) => show(person, day, null), edit: show };
};
