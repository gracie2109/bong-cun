import { computed, ref } from "vue";
import { attendanceErrorHint } from "@bongcun/supabase/attendance";
import { useClockIn, useClockOut, useClockStatus } from "@/features/admin/attendance/queries";
import { useElapsedMinutes } from "./useElapsed";

/** State and actions of the clock button: clock status, the pending "no shift, clock in anyway?" question. */
export const useClock = () => {
  const status = useClockStatus();
  const clockIn = useClockIn();
  const clockOut = useClockOut();

  const data = computed(() => status.data.value);
  const openEntry = computed(() => data.value?.openEntry ?? null);
  const branches = computed(() => data.value?.branches ?? []);
  const elapsed = useElapsedMinutes(computed(() => openEntry.value?.checkInAt));
  /** Someone with no branch row can neither clock in nor out, so the button stays away. */
  const available = computed(() => !!openEntry.value || branches.value.length > 0);
  const busy = computed(() => clockIn.isPending.value || clockOut.isPending.value);

  /** The branch waiting for an answer to "you have no shift now, clock in anyway?". */
  const unscheduledFor = ref<string | null>(null);

  const start = async (branchId: string, note?: string, unscheduledOk = false): Promise<boolean> => {
    try {
      await clockIn.mutateAsync({ branchId, note, unscheduledOk });
      unscheduledFor.value = null;
      return true;
    } catch (error) {
      if (attendanceErrorHint(error) === "confirm_unscheduled") unscheduledFor.value = branchId;
      return false;
    }
  };

  const stop = async (note?: string): Promise<boolean> => {
    try {
      await clockOut.mutateAsync(note);
      return true;
    } catch {
      return false;
    }
  };

  return { data, openEntry, branches, elapsed, available, busy, unscheduledFor, start, stop };
};
