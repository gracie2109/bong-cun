import { addDays, mondayOf, monthDays } from "@bongcun/core/attendance";

export type CalendarWeek = { monday: string; days: string[] };

/** The weeks (Monday first) a month grid shows: every week that touches the month of `date`. */
export const weeksOfMonth = (date: string): CalendarWeek[] => {
  const days = monthDays(date);
  const first = days[0] ?? date;
  const last = days[days.length - 1] ?? date;
  const weeks: CalendarWeek[] = [];
  for (let monday = mondayOf(first); monday <= last; monday = addDays(monday, 7)) {
    weeks.push({ monday, days: Array.from({ length: 7 }, (_, index) => addDays(monday, index)) });
  }
  return weeks;
};
