import { ref, type Ref } from "vue";
import { dayMonth, timeOf } from "@/features/admin/attendance/shared/attendanceFormat";
import type { RosterRequest, RosterStaff } from "@bongcun/core/attendance";
import type { RosterRowData } from "./rosterGrid";

/** The two dialogs opened from the roster grid: deciding one pending request, and editing somebody's availability. */
export const useRosterReview = (rows: Ref<RosterRowData[]>) => {
  const decideOpen = ref(false);
  const decideIds = ref<string[]>([]);
  const decideDescription = ref("");
  const decideNames = ref<Record<string, string>>({});

  const openDecide = (request: RosterRequest) => {
    const name = rows.value.find((row) => row.staff.userId === request.userId)?.staff.name ?? "";
    decideIds.value = [request.id];
    decideNames.value = { [request.id]: name };
    decideDescription.value = `${name} · ${request.name} · ${dayMonth(request.workDate)} ${timeOf(request.startAt)}–${timeOf(request.endAt)}`;
    decideOpen.value = true;
  };

  const availabilityOpen = ref(false);
  const availabilityUser = ref<RosterStaff | null>(null);
  const openAvailability = (staff: RosterStaff) => {
    availabilityUser.value = staff;
    availabilityOpen.value = true;
  };

  return { decideOpen, decideIds, decideDescription, decideNames, openDecide, availabilityOpen, availabilityUser, openAvailability };
};
