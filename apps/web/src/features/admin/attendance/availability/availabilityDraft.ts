import type { AvailabilityItem, AvailabilityKind } from "@bongcun/core/attendance";
import { availabilityIssue, type AvailabilityIssue } from "@bongcun/core/attendance";

/** A row being edited: the item plus a key so Vue can track rows that are added and removed. */
export type AvailabilityDraftRow = AvailabilityItem & { key: number; wholeDay: boolean };

let nextKey = 1;

export const newDraftRow = (weekday: number, kind: AvailabilityKind = "unavailable"): AvailabilityDraftRow => ({
  key: nextKey++,
  weekday,
  kind,
  startTime: null,
  endTime: null,
  note: null,
  wholeDay: true,
});

export const toDraftRows = (items: AvailabilityItem[]): AvailabilityDraftRow[] =>
  items.map((item) => ({ ...item, key: nextKey++, wholeDay: !item.startTime && !item.endTime }));

/** Back to plain items: a whole-day row drops its times. */
export const fromDraftRows = (rows: AvailabilityDraftRow[]): AvailabilityItem[] =>
  rows.map((row) => ({
    weekday: row.weekday,
    kind: row.kind,
    startTime: row.wholeDay ? null : row.startTime,
    endTime: row.wholeDay ? null : row.endTime,
    note: row.note?.trim() ? row.note.trim() : null,
  }));

export const draftIssue = (rows: AvailabilityDraftRow[]): AvailabilityIssue | null => availabilityIssue(fromDraftRows(rows));

/** Turning "whole day" off starts from a sensible working range. */
export const setWholeDay = (row: AvailabilityDraftRow, wholeDay: boolean) => {
  row.wholeDay = wholeDay;
  if (!wholeDay && !row.startTime) {
    row.startTime = "08:00";
    row.endTime = "17:00";
  }
};
