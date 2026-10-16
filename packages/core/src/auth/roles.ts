export const DEFAULT_ROLE = {
  CUSTOMER: "customer",
  ADMIN: "admin",
  SUPER_ADMIN: "superAdmin",
  CASHIER: "cashier",
} as const;

export type IROLE = (typeof DEFAULT_ROLE)[keyof typeof DEFAULT_ROLE];
