import { computed, ref, type Ref } from "vue";
import { useBoardingTimeline as useTimelineQuery } from "@/queries/boarding";
import type { TimelineKennel } from "@bongcun/core/boarding";
import { addDays, todayKey } from "../format";
import { windowDays } from "./timelineLayout";

export const TIMELINE_DAYS = 14;

/** The kennel calendar of one branch: the first day shown, the columns, and the kennels grouped by type. */
export const useBoardingTimelineView = (branchId: Ref<string | undefined>) => {
  const from = ref(todayKey());
  const query = useTimelineQuery(branchId, from, TIMELINE_DAYS);
  const timeline = computed(() => query.data.value ?? null);

  const dayKeys = computed(() => windowDays(from.value, TIMELINE_DAYS));

  const groups = computed(() => {
    const byType = new Map<string, { id: string; name: string; kennels: TimelineKennel[] }>();
    for (const kennel of timeline.value?.kennels ?? []) {
      const group = byType.get(kennel.kennelTypeId) ?? { id: kennel.kennelTypeId, name: kennel.kennelTypeName, kennels: [] };
      group.kennels.push(kennel);
      byType.set(kennel.kennelTypeId, group);
    }
    return [...byType.values()];
  });

  const step = (direction: 1 | -1) => (from.value = addDays(from.value, direction * TIMELINE_DAYS));

  return { from, query, timeline, dayKeys, groups, step, today: todayKey() };
};
