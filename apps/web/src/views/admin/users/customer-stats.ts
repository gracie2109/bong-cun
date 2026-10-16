// Per-customer figures derived from their orders. Cancelled lines do not count
// as spending or as a visit.
import type { CustomerOrder } from "@/repositories/orders";

/** An account created within this many days is shown as a new customer. */
export const NEW_CUSTOMER_DAYS = 30;
/** How many past orders the detail panel lists. */
export const RECENT_HISTORY_LIMIT = 5;

const CANCELLED = "CANCEL";
const DAY_MS = 24 * 60 * 60 * 1000;

export type CustomerStats = {
  totalSpent: number;
  serviceCount: number;
  /** ISO date of the latest non-cancelled order, or null. */
  lastVisit: string | null;
  lastServiceName: string | null;
};

const EMPTY_STATS: CustomerStats = {
  totalSpent: 0,
  serviceCount: 0,
  lastVisit: null,
  lastServiceName: null,
};

/** When the customer came (or will come): the booked time, else when the order was placed. */
export const visitDate = (order: CustomerOrder) => order.time ?? order.createdAt;

export const activeLines = (order: CustomerOrder) =>
  order.services.filter((line) => line.status !== CANCELLED);

export const orderTotal = (order: CustomerOrder) =>
  activeLines(order).reduce((sum, line) => sum + Number(line.price), 0);

/** Orders arrive newest first, so the first one with an active line is the latest visit. */
export const buildCustomerStats = (orders: CustomerOrder[]): Map<string, CustomerStats> => {
  const stats = new Map<string, CustomerStats>();
  for (const order of orders) {
    const lines = activeLines(order);
    if (lines.length === 0) continue;
    const current = stats.get(order.userId) ?? { ...EMPTY_STATS };
    current.totalSpent += orderTotal(order);
    current.serviceCount += lines.length;
    if (!current.lastVisit) {
      current.lastVisit = visitDate(order);
      current.lastServiceName = lines[0].name;
    }
    stats.set(order.userId, current);
  }
  return stats;
};

export const statsOf = (stats: Map<string, CustomerStats>, userId: string) =>
  stats.get(userId) ?? EMPTY_STATS;

export const newCustomerSince = (now = Date.now()) =>
  new Date(now - NEW_CUSTOMER_DAYS * DAY_MS).toISOString();

export const isNewCustomer = (createdAt: string | Date | undefined, now = Date.now()) =>
  !!createdAt && new Date(createdAt).getTime() >= now - NEW_CUSTOMER_DAYS * DAY_MS;
