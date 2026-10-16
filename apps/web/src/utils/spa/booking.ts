import type { SpaCombo, SpaService } from "@/types/spaCatalog";
import type { BookingItem, BookingPick, BookingStep, SpaSlot } from "@/types/spaWeb";

const TZ = "Asia/Ho_Chi_Minh";

/** Picks per pet id, in the order the customer ticked them. */
export type PicksByPet = Record<string, BookingPick[]>;

/** yyyy-mm-dd of a moment in the shop's time zone (not the browser's). */
export const businessDate = (now: Date = new Date(), addDays = 0): string => {
  const parts = new Intl.DateTimeFormat("en-CA", { timeZone: TZ, year: "numeric", month: "2-digit", day: "2-digit" }).format(now);
  if (addDays === 0) return parts;
  const [y, m, d] = parts.split("-").map(Number);
  return new Date(Date.UTC(y, m - 1, d + addDays)).toISOString().slice(0, 10);
};

/** "09:30" for an ISO moment, in the shop's time zone. */
export const slotTimeLabel = (iso: string): string =>
  new Intl.DateTimeFormat("en-GB", { timeZone: TZ, hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date(iso));

/** "Thứ bảy, 17/10/2026" in the given locale for a yyyy-mm-dd day. */
export const dayLabel = (date: string, locale: string): string =>
  new Intl.DateTimeFormat(locale, { timeZone: "UTC", weekday: "long", day: "2-digit", month: "2-digit", year: "numeric" }).format(
    new Date(`${date}T00:00:00Z`)
  );

/** "09:30 - 11:00" for a start and a length. */
export const rangeLabel = (startIso: string, minutes: number): string =>
  `${slotTimeLabel(startIso)} - ${slotTimeLabel(new Date(new Date(startIso).getTime() + minutes * 60000).toISOString())}`;

export const pickOfService = (service: SpaService): BookingPick => ({
  kind: "service",
  id: service.id,
  name: service.name,
  minutes: service.durationMinutes || 30,
});

export const pickOfCombo = (combo: SpaCombo): BookingPick => ({
  kind: "combo",
  id: combo.id,
  name: combo.name,
  minutes: combo.durationMinutes || 30,
});

export const hasPick = (picks: BookingPick[] | undefined, kind: BookingPick["kind"], id: string): boolean =>
  (picks ?? []).some((pick) => pick.kind === kind && pick.id === id);

/** Tick or untick a pick, returning a new map. A pet with no picks left disappears from it. */
export const togglePick = (current: PicksByPet, petId: string, pick: BookingPick): PicksByPet => {
  const own = current[petId] ?? [];
  const next = hasPick(own, pick.kind, pick.id)
    ? own.filter((item) => !(item.kind === pick.kind && item.id === pick.id))
    : [...own, pick];
  const { [petId]: _removed, ...rest } = current;
  return next.length > 0 ? { ...rest, [petId]: next } : rest;
};

/** The ticket list the RPCs take: pets in the order given, each pet's picks in the order ticked. */
export const toBookingItems = (picks: PicksByPet, petOrder: string[]): BookingItem[] =>
  petOrder.flatMap((petId) => (picks[petId] ?? []).map((pick) => ({ petId, kind: pick.kind, id: pick.id })));

/** Steps shown, leaving out the branch step when the shop has one branch only. */
export const bookingSteps = (branchCount: number): BookingStep[] =>
  branchCount > 1 ? ["branch", "pets", "slot", "confirm"] : ["pets", "slot", "confirm"];

/** The free slots of a day only. */
export const freeSlots = (slots: SpaSlot[]): SpaSlot[] => slots.filter((slot) => slot.free);
