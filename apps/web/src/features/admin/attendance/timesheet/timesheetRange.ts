import { addDays } from "@bongcun/core/attendance";

/** The summary function refuses longer ranges (about three months). */
export const MAX_RANGE_DAYS = 93;

const MS_PER_DAY = 86_400_000;

/** First day of the month a `yyyy-MM-dd` date falls in. */
export const monthStart = (date: string): string => `${date.slice(0, 7)}-01`;

export const addMonths = (month: string, count: number): string => {
  const total = Number(month.slice(0, 4)) * 12 + (Number(month.slice(5, 7)) - 1) + count;
  return `${Math.floor(total / 12)}-${String((total % 12) + 1).padStart(2, "0")}-01`;
};

export const monthEnd = (month: string): string => addDays(addMonths(month, 1), -1);

/** Days from `from` to `to`, both included. */
export const rangeDays = (from: string, to: string): number => Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / MS_PER_DAY) + 1;

export const isUsableRange = (from: string, to: string): boolean => !!from && !!to && from <= to && rangeDays(from, to) <= MAX_RANGE_DAYS;
