import { computed, shallowRef } from "vue";
import { CalendarDate, type DateValue } from "@internationalized/date";
import { addDays, mondayOf } from "@bongcun/core/attendance";

const toCalendarDate = (date: string) => new CalendarDate(Number(date.slice(0, 4)), Number(date.slice(5, 7)), Number(date.slice(8, 10)));

/** The Monday to Sunday range the calendar highlights for `monday`, and the snap back from a picked day. */
export const useWeekRange = (monday: () => string) => {
  const range = computed(() => ({ start: toCalendarDate(monday()), end: toCalendarDate(addDays(monday(), 6)) }));
  const placeholder = shallowRef<DateValue>(range.value.start);
  const pick = (day?: DateValue) => (day ? mondayOf(day.toString()) : null);
  return { range, placeholder, pick };
};
