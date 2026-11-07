/** "00:00 thứ Bảy 15/11" in Vietnam time, from the ISO instant the database returns. */
export const closesLabel = (iso: string): string => {
  const parts = new Intl.DateTimeFormat("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    weekday: "long",
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(new Date(iso));
  const get = (type: string) => parts.find((part) => part.type === type)?.value ?? "";
  return `${get("hour")}:${get("minute")} ${get("weekday")} ${get("day")}/${get("month")}`;
};
