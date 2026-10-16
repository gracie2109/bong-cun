import { SLOT_MINUTES, type AppointmentStatus, type TicketStatus } from "@bongcun/supabase/spa";

// The salon works on Vietnam time whatever the device clock says, and Vietnam has no daylight
// saving, so a fixed +07:00 offset converts a local date and time to an instant.
const BUSINESS_TZ = "Asia/Ho_Chi_Minh";
const BUSINESS_OFFSET = "+07:00";
const MINUTES_PER_HOUR = 60;
const DAY_MS = 24 * 60 * 60 * 1000;

const dateKeyFormat = new Intl.DateTimeFormat("en-CA", { timeZone: BUSINESS_TZ });
const timeFormat = new Intl.DateTimeFormat("en-GB", {
  timeZone: BUSINESS_TZ,
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

/** yyyy-MM-dd of an instant on the salon's calendar. */
export const dateKeyOf = (date: Date | string): string => dateKeyFormat.format(new Date(date));

export const todayKey = (): string => dateKeyOf(new Date());

/** HH:mm of an instant on the salon's clock. */
export const timeOf = (iso: string): string => timeFormat.format(new Date(iso));

/** The instant of a salon date (yyyy-MM-dd) and time (HH:mm), as an ISO string. */
export const toIso = (dateKey: string, time: string): string =>
  new Date(`${dateKey}T${time}:00${BUSINESS_OFFSET}`).toISOString();

export const addDays = (dateKey: string, days: number): string =>
  dateKeyOf(new Date(new Date(`${dateKey}T12:00:00${BUSINESS_OFFSET}`).getTime() + days * DAY_MS));

/** ISO weekday of a salon date: Monday = 1 ... Sunday = 7. */
export const isoWeekday = (dateKey: string): number => {
  const day = new Date(`${dateKey}T12:00:00${BUSINESS_OFFSET}`).getUTCDay();
  return day === 0 ? 7 : day;
};

export const minutesOfTime = (time: string): number => {
  const [hours = 0, minutes = 0] = time.split(":").map(Number);
  return hours * MINUTES_PER_HOUR + minutes;
};

export const timeOfMinutes = (minutes: number): string =>
  `${String(Math.floor(minutes / MINUTES_PER_HOUR)).padStart(2, "0")}:${String(minutes % MINUTES_PER_HOUR).padStart(2, "0")}`;

/** Start times offered between opening and closing (the last one leaves a whole step before closing). */
export const timeSlots = (openTime: string, closeTime: string): string[] => {
  const slots: string[] = [];
  for (let at = minutesOfTime(openTime); at < minutesOfTime(closeTime); at += SLOT_MINUTES) slots.push(timeOfMinutes(at));
  return slots;
};

export const dateTime = (iso: string | null | undefined): string =>
  iso ? `${timeOf(iso)} ${dateKeyOf(iso).split("-").reverse().join("/")}` : "";

/** Badge colors of an appointment's status. */
export const APPOINTMENT_TONE: Record<AppointmentStatus, string> = {
  booked: "bg-sky-50 text-sky-700",
  checked_in: "bg-amber-50 text-amber-700",
  in_progress: "bg-violet-50 text-violet-700",
  done: "bg-primary/10 text-primary",
  paid: "bg-emerald-50 text-emerald-700",
  cancelled: "bg-red-50 text-red-600",
  no_show: "bg-slate-100 text-slate-600",
};

/** Block colors of a ticket on the day board. */
export const TICKET_TONE: Record<TicketStatus, string> = {
  waiting: "border-sky-300 bg-sky-50 text-sky-900",
  in_progress: "border-violet-300 bg-violet-50 text-violet-900",
  done: "border-primary/40 bg-primary/10 text-primary",
  cancelled: "border-red-200 bg-red-50 text-red-700 line-through",
};
