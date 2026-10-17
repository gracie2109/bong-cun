import type { CareLog, StayCharge } from "./care";

// ------------------------------------------------------------------ stays
/** A hotel stay, or the stay of an inpatient pet (tied to a medical visit). */
export type StayKind = "boarding" | "inpatient";
export type StayStatus = "booked" | "checked_in" | "checked_out" | "paid" | "cancelled" | "no_show";
export const STAY_STATUSES: readonly StayStatus[] = ["booked", "checked_in", "checked_out", "paid", "cancelled", "no_show"];

export type StaySource = "counter" | "phone" | "web";

/** One pet of a stay, with its kennel and the nights it holds it. */
export type StayPet = {
  id: string;
  lineNo: number;
  petId: string;
  petName: string;
  petPhotoUrl: string | null;
  status: "active" | "cancelled";
  kennelTypeId: string;
  kennelTypeName: string;
  kennelId: string;
  kennelCode: string;
  /** First night (yyyy-MM-dd), and the day after the last night. */
  nightsFrom: string;
  nightsTo: string;
  chargedNights: number;
  isExtraPet: boolean;
  estNightPrice: number;
  /** Fixed at check-in; null before. */
  nightPrice: number | null;
  weightKg: number | null;
  vaccineChecked: boolean;
  vaccineNote: string | null;
  belongings: string | null;
  belongingsReturned: boolean;
  feeding: string | null;
  medication: string | null;
  /** The pet has behaviour or allergy notes. */
  hasNotes: boolean;
};

export type BoardingStay = {
  id: string;
  code: string;
  branchId: string;
  status: StayStatus;
  customerId: string;
  customerName: string;
  customerPhone: string;
  plannedInAt: string;
  plannedOutAt: string;
  checkedInAt: string | null;
  checkedOutAt: string | null;
  source: StaySource;
  kind: StayKind;
  visitId: string | null;
  visitCode: string | null;
  emergencyPhone: string | null;
  note: string | null;
  cancelReason: string | null;
  /** Estimated (or fixed) price of all nights of the active pets. */
  estTotal: number;
  pets: StayPet[];
  /** Only the detail carries these; the list leaves them empty. */
  careLogs: CareLog[];
  charges: StayCharge[];
};

export type StayFilter = { from?: string; to?: string; status?: StayStatus | ""; search?: string };

export type QuoteWarning = "overweight" | "behavior";

export type QuoteItem = {
  lineNo: number;
  petId: string;
  petName: string;
  kennelTypeId: string;
  kennelTypeName: string;
  kennelId: string;
  kennelCode: string;
  isExtraPet: boolean;
  nightPrice: number;
  amount: number;
  warnings: QuoteWarning[];
};

export type StayQuote = { nights: number; total: number; items: QuoteItem[] };

/** Kennels of a type that are free for every night of a range. */
export type TypeAvailability = { kennelTypeId: string; name: string; total: number; free: number; nightPrice: number | null };
