// Display helpers for the customers screen.
import { format } from "date-fns";
import type { IUser } from "@/types/user.type";

const VISIT_DATE_FORMAT = "dd/MM/yyyy";
const INITIALS_LENGTH = 2;

export const customerName = (customer: IUser) =>
  customer.fullName || customer.displayName || customer.email;

export const initials = (customer: IUser) =>
  customerName(customer)
    .split(/\s+/)
    .filter(Boolean)
    .slice(-INITIALS_LENGTH)
    .map((word) => word[0])
    .join("")
    .toUpperCase();

export const formatVisit = (iso: string) => format(new Date(iso), VISIT_DATE_FORMAT);

/** "BC-" + the first 6 characters of the account id, uppercased. */
export const customerCode = (customer: IUser) => `BC-${customer.userId.slice(0, 6).toUpperCase()}`;

const MONTH_MS = 30 * 24 * 60 * 60 * 1000;
export const monthsSince = (date: string | Date | undefined, now = Date.now()) =>
  date ? Math.max(0, Math.floor((now - new Date(date).getTime()) / MONTH_MS)) : 0;

export const formatAddress = (customer: IUser) => {
  const address = customer.province;
  if (!address) return "";
  return [address.address, address.ward?.WardName, address.district?.DistrictName, address.province?.ProvinceName]
    .filter(Boolean)
    .join(", ");
};
