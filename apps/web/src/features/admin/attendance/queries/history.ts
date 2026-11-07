import { keepPreviousData, useQuery } from "@tanstack/vue-query";
import { computed, unref, type MaybeRef } from "vue";
import { supabaseClient } from "@/lib/supabase";
import { getScheduleHistoryOf, listScheduleHistory } from "@bongcun/supabase/attendance";
import type { HistoryFilter } from "@bongcun/supabase/attendance";
import { attendanceKeys } from "@/queries/keys";

export const useScheduleHistory = (filter: MaybeRef<HistoryFilter>, page: MaybeRef<number>, pageSize: number) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.historyList(unref(filter), unref(page))),
    queryFn: () => listScheduleHistory(supabaseClient(), unref(filter), unref(page), pageSize),
    placeholderData: keepPreviousData,
  });

/** What happened to one shift or request; `enabled` is off until the dialog opens. */
export const useScheduleHistoryOf = (entity: MaybeRef<string>, entityId: MaybeRef<string | undefined>, enabled: MaybeRef<boolean>) =>
  useQuery({
    queryKey: computed(() => attendanceKeys.historyOf(unref(entity), unref(entityId) ?? "")),
    queryFn: () => getScheduleHistoryOf(supabaseClient(), unref(entity), unref(entityId) as string),
    enabled: computed(() => unref(enabled) && !!unref(entityId)),
  });
