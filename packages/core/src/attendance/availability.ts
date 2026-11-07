// Pure helpers for the availability pattern (display and editing only; the database decides conflicts).
import type { AvailabilityItem } from "./contract/availability";

const toMinutes = (value: string) => Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5));

/** Whole day when both ends are empty. */
export const isWholeDay = (item: Pick<AvailabilityItem, "startTime" | "endTime">) => !item.startTime && !item.endTime;

/** End before start means the range runs past midnight. */
export const crossesMidnight = (item: Pick<AvailabilityItem, "startTime" | "endTime">) =>
  !!item.startTime && !!item.endTime && toMinutes(item.endTime) < toMinutes(item.startTime);

export type AvailabilityIssue = "time_incomplete" | "time_same" | "too_many";

/** What is wrong with a draft list, or null. Mirrors the checks of save_my_availability. */
export const availabilityIssue = (items: AvailabilityItem[]): AvailabilityIssue | null => {
  if (items.length > 21) return "too_many";
  for (const item of items) {
    if (!!item.startTime !== !!item.endTime) return "time_incomplete";
    if (item.startTime && item.startTime === item.endTime) return "time_same";
  }
  return null;
};

/** Items grouped by weekday (1..7), each day sorted whole-day first, then by start. */
export const groupByWeekday = (items: AvailabilityItem[]): Map<number, AvailabilityItem[]> => {
  const map = new Map<number, AvailabilityItem[]>();
  for (let day = 1; day <= 7; day += 1) map.set(day, []);
  for (const item of items) map.get(item.weekday)?.push(item);
  for (const list of map.values()) list.sort((a, b) => (a.startTime ?? "").localeCompare(b.startTime ?? ""));
  return map;
};
