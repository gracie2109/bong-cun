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
  sex: PetSex;
  neutered: boolean;
  /** yyyy-mm-dd, or empty when unknown. */
  birthDate: string;
  allergies: string;
  behaviorNotes: string;
  weightKg: number | null;
};

/** A web account without a customer record, as staff see it when linking. */
export type UnlinkedAccount = { userId: string; fullName: string; phone: string; email: string };

export const APPOINTMENT_SCOPES = ["upcoming", "past"] as const;
export type AppointmentScope = (typeof APPOINTMENT_SCOPES)[number];

export type MyAppointmentItem = {
  name: string;
  petName: string;
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
