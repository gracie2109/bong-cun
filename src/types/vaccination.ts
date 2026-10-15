// The e-book of shots and the call list of reminders.
export type BookState = "ok" | "due_soon" | "overdue";

export type VaccineDose = {
  id: string;
  doseNo: number;
  givenOn: string;
  lotNo: string | null;
  expiryDate: string | null;
  isExternal: boolean;
  externalPlace: string | null;
  vetName: string | null;
  nextDueOn: string | null;
  branchName: string | null;
  visitId: string | null;
  voidedAt: string | null;
};

/** One vaccine type in a pet's e-book, with every shot of it. */
export type VaccineBookEntry = {
  vaccineTypeId: string;
  name: string;
  kind: string;
  state: BookState;
  nextDueOn: string | null;
  lastGivenOn: string;
  doses: VaccineDose[];
};

export type VaccineLot = { id: string; lotNo: string; expiryDate: string | null; qtyOnHand: number };

export type GiveVaccineInput = {
  vaccineTypeId: string;
  lotId: string | null;
  doseNo: number | null;
  nextDueOn: string | null;
};

export type ExternalVaccineInput = {
  vaccineTypeId: string;
  givenOn: string;
  externalPlace: string;
  lotNo: string;
  expiryDate: string;
  doseNo: number | null;
  nextDueOn: string | null;
};

export type GiveVaccineResult = { id: string; warnings: string[] };

export type ReminderScope = "due" | "overdue" | "recheck";
export const REMINDER_SCOPES: readonly ReminderScope[] = ["due", "overdue", "recheck"];

export type Reminder = {
  kind: "vaccination" | "recheck";
  vaccinationId: string | null;
  visitId: string | null;
  petId: string;
  petName: string;
  speciesName: string;
  customerId: string;
  customerName: string;
  customerPhone: string;
  /** The vaccine, or the reason of the re-check. */
  vaccineName: string | null;
  dueOn: string;
  lastGivenOn: string | null;
  remindedAt: string | null;
  remindNote: string | null;
  remindedByName: string | null;
};

export type ReminderFilter = { scope: ReminderScope; search?: string };
