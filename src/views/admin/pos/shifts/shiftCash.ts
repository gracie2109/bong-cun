import type { CashShift } from "@/repositories/pos";

/** Counted minus expected: positive = over, negative = short; null until the shift is counted. */
export const cashDifference = (shift: CashShift): number | null =>
  shift.countedCash === null || shift.expectedCash === null ? null : shift.countedCash - shift.expectedCash;

export const cashDifferenceClass = (shift: CashShift): string => {
  const value = cashDifference(shift);
  if (value === null || value === 0) return "";
  return value > 0 ? "text-amber-600" : "text-red-600";
};
