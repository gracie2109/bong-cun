import { businessDate } from "@/repositories/inventory";

/** A stock quantity: up to two decimals, Vietnamese grouping. */
export const qty = (value: number | null | undefined): string =>
  (value ?? 0).toLocaleString("vi-VN", { maximumFractionDigits: 2 });

/** A YYYY-MM-DD date as dd/mm/yyyy; empty for none. */
export const day = (iso: string | null | undefined): string => {
  if (!iso) return "";
  const [year, month, date] = iso.slice(0, 10).split("-");
  return `${date}/${month}/${year}`;
};

/** Whole days from today (Vietnam) to an expiry date; negative once expired. */
export const daysUntil = (expiryDate: string): number => {
  const today = new Date(`${businessDate()}T00:00:00Z`).getTime();
  return Math.round((new Date(`${expiryDate}T00:00:00Z`).getTime() - today) / 86_400_000);
};

/** A typed quantity: "1,5" and "1.5" both read 1.5; NaN when not a number. */
export const parseQty = (text: string | number | null | undefined): number => {
  const value = String(text ?? "").trim().replace(",", ".");
  return value === "" ? Number.NaN : Number(value);
};
