import { computed, type Ref } from "vue";
import { useShiftRoster } from "@/features/admin/attendance/queries";
import type { Roster } from "@bongcun/core/attendance";
import { buildRosterGrid } from "./rosterGrid";

const EMPTY: Roster = { staff: [], templates: [], assignments: [], leaves: [] };

/** The roster of one branch for the week shown, as the grid's rows. */
export const useRoster = (branchId: Ref<string | undefined>, monday: Ref<string>, sunday: Ref<string>, days: Ref<string[]>) => {
  const query = useShiftRoster(branchId, monday, sunday);
  const roster = computed(() => query.data.value ?? EMPTY);
  const rows = computed(() => buildRosterGrid(roster.value, days.value));
  return { query, roster, rows, templates: computed(() => roster.value.templates) };
};
