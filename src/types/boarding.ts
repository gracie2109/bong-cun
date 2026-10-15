// Pet hotel (boarding): kennels, kennel types with their prices, and the rules of a branch.
export type KennelStatus = "ready" | "cleaning" | "maintenance";
export const KENNEL_STATUSES: readonly KennelStatus[] = ["ready", "cleaning", "maintenance"];

export type KennelPurpose = "boarding" | "medical" | "isolation";
export const KENNEL_PURPOSES: readonly KennelPurpose[] = ["boarding", "medical", "isolation"];

/** A price that replaces the shared one at one branch. */
export type BranchKennelPrice = {
  branchId: string;
  branchName: string;
  nightPrice: number;
  /** Each further pet in the kennel; null = the normal night price. */
  extraPetNightPrice: number | null;
};

export type KennelType = {
  id: string;
  name: string;
  description: string | null;
  photoUrl: string | null;
  speciesIds: string[];
  speciesNames: string[];
  /** Heaviest pet; null = no limit. */
  maxWeightKg: number | null;
  /** Pets of one stay that may share a kennel. */
  maxPets: number;
  purpose: KennelPurpose;
  isActive: boolean;
  isPublic: boolean;
  sortOrder: number;
  /** The price that applies at the branch the list was read for. */
  nightPrice: number | null;
  extraPetNightPrice: number | null;
  hasBranchPrice: boolean;
  sharedNightPrice: number | null;
  sharedExtraPetNightPrice: number | null;
  branchPrices: BranchKennelPrice[];
  /** Kennels of this type at that branch. */
  kennelCount: number;
};

export type KennelTypeInput = {
  name: string;
  description: string | null;
  photoUrl: string | null;
  speciesIds: string[];
  maxWeightKg: number | null;
  maxPets: number;
  isActive: boolean;
  isPublic: boolean;
  sortOrder: number;
  sharedNightPrice: number;
  sharedExtraPetNightPrice: number | null;
  branchPrices: Pick<BranchKennelPrice, "branchId" | "nightPrice" | "extraPetNightPrice">[];
};

export type Kennel = {
  id: string;
  branchId: string;
  kennelTypeId: string;
  kennelTypeName: string;
  code: string;
  name: string | null;
  status: KennelStatus;
  isActive: boolean;
  sortOrder: number;
};

export type KennelInput = {
  branchId: string;
  kennelTypeId: string;
  code: string;
  name: string | null;
  isActive: boolean;
  sortOrder: number;
};

/** Check-in and check-out rules of a branch. Times are "HH:mm". */
export type BoardingRules = {
  checkInFrom: string;
  checkOutBy: string;
  lateHalfUntil: string;
  maxNights: number;
  /** Nights charged for a pet dropped and collected on the same day (0.5 or 1). */
  dayStayNights: number;
};

export type KennelTypeFilter = { search?: string; activeOnly?: boolean };
export type KennelFilter = { search?: string; typeId?: string };

// ------------------------------------------------------------------ stays
export type StayStatus = "booked" | "checked_in" | "checked_out" | "paid" | "cancelled" | "no_show";
export const STAY_STATUSES: readonly StayStatus[] = ["booked", "checked_in", "checked_out", "paid", "cancelled", "no_show"];

export type StaySource = "counter" | "phone" | "web";

/** One pet of a stay, with its kennel and the nights it holds it. */
export type StayPet = {
  id: string;
  lineNo: number;
  petId: string;
  petName: string;
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

/** What the booking dialog sends for one pet. */
export type StayPetInput = {
  petId: string;
  kennelTypeId: string;
  /** Leave out to let the database pick a free kennel of the type. */
  kennelId?: string | null;
  /** 1-based line of an earlier pet whose kennel this one shares. */
  shareWith?: number | null;
  feeding?: string;
  medication?: string;
  belongings?: string;
};

export type StayInput = {
  customerId: string;
  /** ISO instants. */
  plannedInAt: string;
  plannedOutAt: string;
  source: "counter" | "phone";
  emergencyPhone: string;
  note: string;
  pets: StayPetInput[];
};

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

// ------------------------------------------------------------------ board
export type KennelState = "free" | "arriving" | "occupied" | "departing" | "overdue" | "cleaning" | "maintenance";

export type BoardPet = {
  stayId: string;
  stayCode: string;
  stayStatus: StayStatus;
  stayPetId: string;
  petId: string;
  petName: string;
  customerName: string;
  plannedInAt: string;
  plannedOutAt: string;
  hasNotes: boolean;
  overdue: boolean;
};

export type BoardKennel = {
  id: string;
  code: string;
  name: string | null;
  kennelTypeId: string;
  kennelTypeName: string;
  status: KennelStatus;
  state: KennelState;
  /** A pet is overdue in a kennel that has a booked arrival: someone has to move. */
  conflict: boolean;
  pets: BoardPet[];
  arriving: BoardPet[];
};

export type BoardCounts = { arriving: number; departing: number; occupied: number; overdue: number; free: number };

export type DayBoard = { date: string; counts: BoardCounts; kennels: BoardKennel[] };

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

/** What the check-in dialog sends for one pet. */
export type CheckInPetInput = {
  stayPetId: string;
  weightKg: number;
  vaccineChecked: boolean;
  vaccineNote: string;
  belongings: string;
  feeding: string;
  medication: string;
};

export type CheckoutLine = Pick<StayCharge, "stayPetId" | "petName" | "kind" | "name" | "qty" | "unitPrice" | "amount">;

export type CheckoutBelonging = { stayPetId: string; petName: string; belongings: string; returned: boolean };

export type CheckoutPreview = { at: string; items: CheckoutLine[]; total: number; belongings: CheckoutBelonging[] };

/** A charge of a checked-out stay that is not on an invoice yet. */
export type BillableCharge = { id: string; name: string; petName: string | null; qty: number; unitPrice: number; amount: number };

/** A checked-out stay with the charges still to pay, for the POS cart. */
export type BillableBoardingStay = { stayId: string; code: string; total: number; charges: BillableCharge[] };
