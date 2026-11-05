const timeFormat = new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Ho_Chi_Minh", hour: "2-digit", minute: "2-digit", hour12: false });

/** `HH:mm` of an instant on the salon's clock, whatever the device's time zone. */
export const timeOf = (iso: string): string => timeFormat.format(new Date(iso));

const dateFormat = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Ho_Chi_Minh" });

/** `dd/MM` of an instant (or of a `yyyy-MM-dd` date) on the salon's calendar. */
export const dayMonth = (value: string): string => {
  const date = /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : dateFormat.format(new Date(value));
  return `${date.slice(8, 10)}/${date.slice(5, 7)}`;
};

/** `1g05p`, `45p`, `0p`: minutes as the screens show them. */
export const formatMinutes = (minutes: number): string => {
  const total = Math.max(0, Math.round(minutes));
  const hours = Math.floor(total / 60);
  return hours > 0 ? `${hours}g${String(total % 60).padStart(2, "0")}p` : `${total}p`;
};

/** Value for `<input type="datetime-local">` from an instant, on the salon's clock. */
export const toLocalInput = (iso: string): string => `${dateFormat.format(new Date(iso))}T${timeOf(iso)}`;

/** The reverse: Vietnam has no daylight saving, so the offset is always +07:00. */
export const fromLocalInput = (value: string): string => new Date(`${value}:00+07:00`).toISOString();
