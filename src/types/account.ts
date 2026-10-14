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
