// Number formats of the reports. Pure functions.
export { money } from "@/views/admin/pos/format";

const MILLION = 1_000_000;
const THOUSAND = 1_000;

const oneDecimal = (value: number): string => value.toFixed(1).replace(/\.0$/, "").replace(".", ",");

/** Short money for chart axes: "1,2tr", "350k", "0". */
export const compactMoney = (value: number): string => {
  const abs = Math.abs(value);
  const sign = value < 0 ? "-" : "";
  if (abs >= MILLION) return `${sign}${oneDecimal(abs / MILLION)}tr`;
  if (abs >= THOUSAND) return `${sign}${Math.round(abs / THOUSAND)}k`;
  return `${sign}${Math.round(abs)}`;
};

export const percent = (value: number): string => `${oneDecimal(value)}%`;

export type Delta = { percent: number; direction: "up" | "down" | "flat" };

/** Change against the previous period; null when there is nothing to compare with. */
export const delta = (current: number, previous: number): Delta | null => {
  if (previous === 0) return null;
  const change = ((current - previous) / Math.abs(previous)) * 100;
  const rounded = Math.round(change * 10) / 10;
  return { percent: Math.abs(rounded), direction: rounded > 0 ? "up" : rounded < 0 ? "down" : "flat" };
};
