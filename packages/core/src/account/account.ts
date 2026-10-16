/** The signed-in customer as the account area shows and edits them. */
export type MyProfile = {
  email: string | null;
  fullName: string;
  phone: string;
  /** yyyy-mm-dd, or empty when not set. */
  birthDate: string;
  /** Null until the customer record exists (created on the first profile save). */
  customerId: string | null;
};

/** What the profile form sends. */
export type ProfileInput = { fullName: string; phone: string; birthDate: string };

/** An entry of the account side menu. `label` is an i18n key under `client.account.nav`. */
export type AccountNavItem = { label: string; name: string; icon: string };

export const PET_SEXES = ["male", "female", "unknown"] as const;
export type PetSex = (typeof PET_SEXES)[number];

/** One pet the signed-in customer owns. */
export type MyPet = {
  id: string;
  name: string;
  speciesId: string;
  speciesName: string;
  breed: string;
  photoUrl: string | null;
  sex: PetSex;
  neutered: boolean;
  /** yyyy-mm-dd, or empty when unknown. */
  birthDate: string;
  allergies: string;
  behaviorNotes: string;
  weightKg: number | null;
  /** The vaccine due next, from the e-book of shots. */
  nextVaccine: { name: string; dueOn: string } | null;
};

/** The health book a customer reads for one of their pets (my_pet_health). No SOAP, no vitals, no prices. */
export type HealthDose = { doseNo: number | null; givenOn: string; isExternal: boolean; externalPlace: string };
export type HealthVaccine = {
  vaccineTypeId: string;
  name: string;
  kind: string;
  lastGivenOn: string;
  nextDueOn: string | null;
  state: "ok" | "due_soon" | "overdue";
  doses: HealthDose[];
};
export type HealthTakeHome = { name: string; dose: string; frequency: string; days: number | null; route: string; instructions: string };
export type HealthVisit = {
  id: string;
  date: string;
  reason: string;
  diagnoses: string[];
  ownerInstructions: string;
  recheckOn: string | null;
  branchName: string;
  takeHome: HealthTakeHome[];
};
export type PetHealth = { petId: string; petName: string; petPhotoUrl: string | null; phone: string; vaccines: HealthVaccine[]; visits: HealthVisit[] };

/** A web account without a customer record, as staff see it when linking. */
export type UnlinkedAccount = { userId: string; fullName: string; phone: string; email: string };

export const APPOINTMENT_SCOPES = ["upcoming", "past"] as const;
export type AppointmentScope = (typeof APPOINTMENT_SCOPES)[number];

export type MyAppointmentItem = {
  name: string;
  petName: string;
  petPhotoUrl: string | null;
  startAt: string;
  /** waiting | in_progress | done | cancelled */
  status: string;
  estPrice: number | null;
};

/** One of the customer's spa appointments. The staff who do the work are never part of it. */
export type MyAppointment = {
  id: string;
  code: string;
  /** booked | checked_in | in_progress | done | paid | cancelled | no_show */
  status: string;
  startAt: string;
  endAt: string;
  note: string;
  branchName: string;
  branchPhone: string;
  /** Booked and more than the cancel window ahead: decided by the server. */
  canCancel: boolean;
  estTotal: number;
  hasUnpriced: boolean;
  items: MyAppointmentItem[];
};

export const BOARDING_SCOPES = ["upcoming", "current", "past"] as const;
export type BoardingScope = (typeof BOARDING_SCOPES)[number];

export type MyBoardingPet = {
  petName: string;
  petPhotoUrl: string | null;
  /** active | cancelled */
  status: string;
  kennelTypeName: string;
  /** First night and day of leaving, yyyy-MM-dd. */
  nightsFrom: string;
  nightsTo: string;
  chargedNights: number;
  feeding: string;
  medication: string;
};

/** One of the customer's pet hotel stays. The staff and the kennel code are never part of it. */
export type MyBoardingStay = {
  id: string;
  code: string;
  /** booked | checked_in | checked_out | paid | cancelled | no_show */
  status: string;
  plannedInAt: string;
  plannedOutAt: string;
  checkedInAt: string | null;
  checkedOutAt: string | null;
  branchName: string;
  branchPhone: string;
  /** The estimate, or the final amount once the stay is checked out. */
  estTotal: number;
  isFinal: boolean;
  pets: MyBoardingPet[];
};

export type MyBoardingLog = {
  id: string;
  petName: string;
  /** meal | walk | potty | medication | note */
  kind: string;
  /** all | some | none, for meals */
  mealEaten: string | null;
  content: string;
  loggedAt: string;
};

export type MyBoardingCharge = {
  id: string;
  petName: string;
  /** night | late | extra */
  kind: string;
  name: string;
  qty: number;
  unitPrice: number;
  amount: number;
};

export type MyBoardingDetail = MyBoardingStay & { careLogs: MyBoardingLog[]; charges: MyBoardingCharge[] };
