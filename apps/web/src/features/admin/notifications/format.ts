// Pure helpers for showing a notification.
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

/** "Vừa xong", "5 phút", "3 giờ", "2 ngày", or the date once it is older than a week. */
export const timeAgo = (iso: string, now: number = Date.now()): { unit: "now" | "minutes" | "hours" | "days" | "date"; value: number } => {
  const diff = Math.max(0, now - new Date(iso).getTime());
  if (diff < MINUTE) return { unit: "now", value: 0 };
  if (diff < HOUR) return { unit: "minutes", value: Math.floor(diff / MINUTE) };
  if (diff < DAY) return { unit: "hours", value: Math.floor(diff / HOUR) };
  if (diff < 7 * DAY) return { unit: "days", value: Math.floor(diff / DAY) };
  return { unit: "date", value: 0 };
};
