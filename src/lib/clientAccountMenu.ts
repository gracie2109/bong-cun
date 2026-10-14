/** Entries of the account dropdown in the public header. `label` is an i18n key under `client.menu`. */
export type AccountMenuItem = { label: string; name: string; icon: string };

export const ACCOUNT_MENU_ITEMS: AccountMenuItem[] = [
  { label: "client.menu.account", name: "profile", icon: "User" },
];
