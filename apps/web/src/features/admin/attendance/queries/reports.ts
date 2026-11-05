import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getMyTimesheet, getTimesheet, getTimesheetGrid } from "@bongcun/supabase/attendance";
import type { TimesheetFilter } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";

/** Totals per person over a date range; `enabled` stays false while the range is empty or too long. */
export const useTimesheet = (filter: MaybeRef<TimesheetFilter>, page: MaybeRef<number>, pageSize: number, enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.timesheet(unref(filter), unref(page))),
    queryFn: () => getTimesheet(supabaseClient(), unref(filter), pageSize, (unref(page) - 1) * pageSize),
    enabled: computed(() => unref(enabled)),
    placeholderData: keepPreviousData,
  });

/** One cell per person per day of a month. */
export const useTimesheetGrid = (branchId: MaybeRef<string | undefined>, month: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.timesheetGrid(unref(branchId) ?? "", unref(month))),
    queryFn: () => getTimesheetGrid(supabaseClient(), unref(branchId) as string, unref(month)),
    enabled: computed(() => !!unref(branchId)),
    placeholderData: keepPreviousData,
  });

export const useMyTimesheet = (from: MaybeRef<string>, to: MaybeRef<string>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.myTimesheet(unref(from), unref(to))),
    queryFn: () => getMyTimesheet(supabaseClient(), unref(from), unref(to)),
  });
