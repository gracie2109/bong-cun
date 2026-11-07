// Calendar helpers on `yyyy-MM-dd` strings. Pure: no Date in the local time zone, so a week is the
// same week on every machine.
const MS_PER_DAY = 86_400_000;

const toUtc = (date: string): Date => {
  const [year, month, day] = date.split("-").map(Number);
  return new Date(Date.UTC(year ?? 1970, (month ?? 1) - 1, day ?? 1));
};

const fromUtc = (value: Date): string => value.toISOString().slice(0, 10);

export const addDays = (date: string, days: number): string => fromUtc(new Date(toUtc(date).getTime() + days * MS_PER_DAY));

/** 1 = Monday ... 7 = Sunday (ISO), the same numbering as `branch_hours.weekday`. */
export const isoWeekday = (date: string): number => toUtc(date).getUTCDay() || 7;

export const mondayOf = (date: string): string => addDays(date, 1 - isoWeekday(date));

/** The seven days of the week that starts on `monday`. */
export const weekDays = (monday: string): string[] => Array.from({ length: 7 }, (_, index) => addDays(monday, index));

/** Every day of the month that `date` falls in. */
export const monthDays = (date: string): string[] => {
  const first = `${date.slice(0, 7)}-01`;
  const next = toUtc(first);
  next.setUTCMonth(next.getUTCMonth() + 1);
  const length = Math.round((next.getTime() - toUtc(first).getTime()) / MS_PER_DAY);
  return Array.from({ length }, (_, index) => addDays(first, index));
};

/** The first day of the month `months` away from the month of `date`. */
export const addMonths = (date: string, months: number): string => {
  const value = toUtc(`${date.slice(0, 7)}-01`);
  value.setUTCMonth(value.getUTCMonth() + months);
  return fromUtc(value);
};

/** The ISO 8601 week number (1-53) of the week that holds `date`, and the year that week belongs to. */
export const isoWeekOf = (date: string): { year: number; week: number } => {
  const thursday = addDays(mondayOf(date), 3);
  const year = Number(thursday.slice(0, 4));
  const firstThursday = addDays(mondayOf(`${year}-01-04`), 3);
  return { year, week: Math.round((toUtc(thursday).getTime() - toUtc(firstThursday).getTime()) / (7 * MS_PER_DAY)) + 1 };
};
