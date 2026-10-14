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
  /** Only the primary owner may edit. */
  canEdit: boolean;
  /** An appointment that is not finished yet includes the pet, so it cannot be hidden. */
  hasOpenAppointment: boolean;
};

/** What the pet form sends; weight is text so an empty box means "unchanged". */
export type PetInput = {
  name: string;
  speciesId: string;
  breed: string;
  sex: PetSex;
  neutered: boolean;
  birthDate: string;
  allergies: string;
  behaviorNotes: string;
  weightKg: string;
};

/** A web account without a customer record, as staff see it when linking. */
export type UnlinkedAccount = { userId: string; fullName: string; phone: string; email: string };
