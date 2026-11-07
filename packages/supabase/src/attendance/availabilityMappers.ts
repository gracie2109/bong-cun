// Availability rows <-> the shape the screens edit. Pure: no client, no Vue.
import type { AvailabilityItem, AvailabilityRow } from "@bongcun/core/attendance";

export const toAvailabilityItem = (row: AvailabilityRow): AvailabilityItem => ({
  weekday: row.weekday,
  kind: row.kind,
  startTime: row.start_time ?? null,
  endTime: row.end_time ?? null,
  note: row.note ?? null,
});

export const toAvailabilityPayload = (items: AvailabilityItem[]) =>
  items.map((item) => ({
    weekday: item.weekday,
    kind: item.kind,
    start_time: item.startTime,
    end_time: item.endTime,
    note: item.note?.trim() ? item.note.trim() : null,
  }));
