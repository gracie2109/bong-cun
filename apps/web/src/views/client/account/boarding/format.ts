import { businessDate } from "@bongcun/core/spa";

export const STATUS_TONE: Record<string, string> = {
  booked: "bg-sky-100 text-sky-700",
  checked_in: "bg-amber-100 text-amber-700",
  checked_out: "bg-green-100 text-green-700",
  paid: "bg-green-100 text-green-700",
  cancelled: "bg-muted text-muted-foreground",
  no_show: "bg-red-100 text-red-700",
};

/** yyyy-MM-dd of an instant in the shop's time zone. */
export const dayOf = (iso: string): string => businessDate(new Date(iso));

/** Day and time of a log entry, e.g. "15/10 09:30", in the shop's time zone. */
export const logTime = (iso: string): string =>
  new Intl.DateTimeFormat("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(new Date(iso));
