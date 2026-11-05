// Display-only helpers. Every number on a screen comes from SQL; nothing here recomputes pay or hours.

/** `HH:mm` to minutes since midnight; NaN for text that is not a time. */
export const toMinutes = (time: string): number => {
  const [hours, minutes] = time.split(":").map(Number);
  return (hours ?? Number.NaN) * 60 + (minutes ?? Number.NaN);
};

/** The shift ends the next morning when it ends at or before it starts. */
export const isOvernight = (startTime: string, endTime: string): boolean => toMinutes(endTime) <= toMinutes(startTime);

/** Length of a shift in minutes, overnight aware (same rule as `shift_minutes` in SQL). */
export const shiftLengthMinutes = (startTime: string, endTime: string): number => {
  const length = toMinutes(endTime) - toMinutes(startTime);
  return length <= 0 ? length + 1440 : length;
};

/** 192 -> "3g12p", 60 -> "1g", 0 -> "0p". */
export const formatMinutes = (total: number): string => {
  const minutes = Math.max(0, Math.round(total));
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) return `${rest}p`;
  return rest === 0 ? `${hours}g` : `${hours}g${rest}p`;
};
