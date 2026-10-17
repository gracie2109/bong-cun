// ------------------------------------------------------------ care and money
export type CareKind = "meal" | "walk" | "potty" | "medication" | "note";
export const CARE_KINDS: readonly CareKind[] = ["meal", "walk", "potty", "medication", "note"];

export type MealEaten = "all" | "some" | "none";
export const MEAL_EATEN: readonly MealEaten[] = ["all", "some", "none"];

export type CareLog = {
  id: string;
  stayPetId: string;
  petName: string;
  kind: CareKind;
  mealEaten: MealEaten | null;
  content: string | null;
  visibleToCustomer: boolean;
  loggedAt: string;
  createdByName: string | null;
  canDelete: boolean;
};

export type CareLogInput = {
  kind: CareKind;
  mealEaten?: MealEaten;
  content: string;
  visibleToCustomer: boolean;
};

export type ChargeKind = "night" | "late" | "extra";

export type StayCharge = {
  id: string;
  stayPetId: string | null;
  petName: string | null;
  kind: ChargeKind;
  name: string;
  qty: number;
  unitPrice: number;
  amount: number;
  invoiceLineId: string | null;
};

export type CheckoutLine = Pick<StayCharge, "stayPetId" | "petName" | "kind" | "name" | "qty" | "unitPrice" | "amount">;

export type CheckoutBelonging = { stayPetId: string; petName: string; belongings: string; returned: boolean };

export type CheckoutPreview = { at: string; items: CheckoutLine[]; total: number; belongings: CheckoutBelonging[] };

/** A charge of a checked-out stay that is not on an invoice yet. */
export type BillableCharge = { id: string; name: string; petName: string | null; petPhotoUrl: string | null; qty: number; unitPrice: number; amount: number };

/** A checked-out stay with the charges still to pay, for the POS cart. */
export type BillableBoardingStay = { stayId: string; code: string; total: number; charges: BillableCharge[] };
