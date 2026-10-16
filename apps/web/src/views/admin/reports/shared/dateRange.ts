// Date ranges of the reports. Pure functions on yyyy-MM-dd strings (Vietnam calendar days).
import { addDays, differenceInCalendarDays, endOfMonth, format, parseISO, startOfMonth, subMonths } from "date-fns";
import { MAX_REPORT_DAYS } from "@/repositories/reports";

export const PRESETS = ["today", "yesterday", "last7", "thisMonth", "lastMonth", "custom"] as const;
export type Preset = (typeof PRESETS)[number];

export const DEFAULT_PRESET: Preset = "thisMonth";

export type DateRange = { from: string; to: string };

const ISO = "yyyy-MM-dd";

export const toIsoDate = (date: Date): string => format(date, ISO);

/** Today's date in Vietnam, whatever the device's time zone. */
export const todayInVietnam = (now = new Date()): string =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Ho_Chi_Minh" }).format(now);

export const isIsoDate = (value: unknown): value is string =>
  typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) && !Number.isNaN(parseISO(value).getTime());

export const isPreset = (value: unknown): value is Preset =>
  typeof value === "string" && (PRESETS as readonly string[]).includes(value);

/** The range of a quick preset; "custom" reads as the month so far. */
export const presetRange = (preset: Preset, today: string): DateRange => {
  const day = parseISO(today);
  switch (preset) {
    case "today":
      return { from: today, to: today };
    case "yesterday": {
      const yesterday = toIsoDate(addDays(day, -1));
      return { from: yesterday, to: yesterday };
    }
    case "last7":
      return { from: toIsoDate(addDays(day, -6)), to: today };
    case "lastMonth": {
      const last = subMonths(day, 1);
      return { from: toIsoDate(startOfMonth(last)), to: toIsoDate(endOfMonth(last)) };
    }
    default:
      return { from: toIsoDate(startOfMonth(day)), to: today };
  }
};

/** Number of days in a range, both ends counted. */
export const rangeDays = ({ from, to }: DateRange): number =>
  differenceInCalendarDays(parseISO(to), parseISO(from)) + 1;

/** The range of the same length right before this one. */
export const previousRange = (range: DateRange): DateRange => {
  const days = rangeDays(range);
  return {
    from: toIsoDate(addDays(parseISO(range.from), -days)),
    to: toIsoDate(addDays(parseISO(range.from), -1)),
  };
};

export type RangeProblem = "order" | "tooLong" | null;

export const rangeProblem = (range: DateRange): RangeProblem => {
  const days = rangeDays(range);
  if (days < 1) return "order";
  return days > MAX_REPORT_DAYS ? "tooLong" : null;
};

export const formatDay = (iso: string): string => format(parseISO(iso), "dd/MM/yyyy");

export const formatShortDay = (iso: string): string => format(parseISO(iso), "dd/MM");

export const formatMonth = (iso: string): string => format(parseISO(iso), "MM/yyyy");

/** Label of a series bucket: the day, the Monday of the week, or the month. */
export const bucketLabel = (bucket: "day" | "week" | "month", iso: string): string =>
  bucket === "month" ? formatMonth(iso) : formatShortDay(iso);
