import { ref } from "vue";
import type { RosterAssignment, RosterStaff } from "@bongcun/core/attendance";

/** Which cell the shift dialog is open for: a new shift, or an existing one. */
export const useAssignDialog = () => {
  const open = ref(false);
  const staff = ref<RosterStaff | null>(null);
  const date = ref("");
  const assignment = ref<RosterAssignment | null>(null);
  /** The template to start from when the shift was added from a shift row. */
  const templateId = ref<string | null>(null);

  const show = (person: RosterStaff, day: string, existing: RosterAssignment | null, template: string | null = null) => {
    staff.value = person;
    date.value = day;
    assignment.value = existing;
    templateId.value = template;
    open.value = true;
  };

  return {
    open,
    staff,
    date,
    assignment,
    templateId,
    add: (person: RosterStaff, day: string, template: string | null = null) => show(person, day, null, template),
    edit: (person: RosterStaff, day: string, existing: RosterAssignment) => show(person, day, existing),
  };
};
