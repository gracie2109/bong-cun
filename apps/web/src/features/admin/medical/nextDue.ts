import type { VaccineType } from "@bongcun/core/medical";
import { addDays } from "./format";

/**
 * The day the next shot is due, worked out the way the database does (so it can be shown before
 * saving): another shot of the basic series after `seriesIntervalDays`, the booster after the last
 * one. Null when the type has no reminder.
 */
export const nextDue = (type: VaccineType | undefined, doseNo: number, givenOn: string): string | null => {
  if (!type || !givenOn) return null;
  if (doseNo < type.seriesDoses) return type.seriesIntervalDays ? addDays(givenOn, type.seriesIntervalDays) : null;
  return type.boosterIntervalDays ? addDays(givenOn, type.boosterIntervalDays) : null;
};

/** The shot number a pet is due for: valid shots of the type it has, plus one. */
export const suggestedDoseNo = (typeId: string, book: { vaccineTypeId: string; doses: { voidedAt: string | null }[] }[]): number =>
  (book.find((entry) => entry.vaccineTypeId === typeId)?.doses.filter((dose) => !dose.voidedAt).length ?? 0) + 1;
