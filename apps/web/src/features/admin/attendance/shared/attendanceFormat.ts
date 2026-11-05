const timeFormat = new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Ho_Chi_Minh", hour: "2-digit", minute: "2-digit", hour12: false });

/** `HH:mm` of an instant on the salon's clock, whatever the device's time zone. */
export const timeOf = (iso: string): string => timeFormat.format(new Date(iso));
