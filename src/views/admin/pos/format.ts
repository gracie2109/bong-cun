import { formatPrice } from "@/lib/utils";

/** Money in VND, "0 ₫" for zero. */
export const money = (value: number | null | undefined): string => formatPrice(value ?? 0) ?? "";

export const dateTime = (iso: string | null | undefined): string =>
  iso ? new Date(iso).toLocaleString("vi-VN", { dateStyle: "short", timeStyle: "short" }) : "";

/** A typed amount: digits only ("150.000" and "150000" both read 150000), 0 when empty. */
export const parseAmount = (text: string | number | null | undefined): number => {
  const digits = String(text ?? "").replace(/\D/g, "");
  return digits ? Number(digits) : 0;
};

/** Quick cash amounts for a total: exact, then the next round notes above it. */
export const cashSuggestions = (total: number): number[] => {
  const steps = [10_000, 50_000, 100_000, 500_000];
  const values = new Set<number>([total]);
  for (const step of steps) values.add(Math.ceil(total / step) * step);
  return [...values].filter((value) => value >= total && value > 0).sort((a, b) => a - b).slice(0, 4);
};
